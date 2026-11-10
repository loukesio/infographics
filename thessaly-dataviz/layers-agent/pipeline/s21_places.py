"""Extra settlements (towns/villages with the most buildings at flood risk) for the building-level view.
Selection: data/places_selected.csv (top by 2*Daniel-flooded + Q100 buildings within ~1 km, de-duplicated) + Palamas, Keramidi.
Outputs: data/places.json, cache/place_buildings.parquet, web/assets/bld_<key>.json (flags as in s19; heights filled by s20)."""
import os, sys, json, pathlib, numpy as np, pandas as pd, geopandas as gpd, shapely
from rasterio.features import rasterize
from rasterio.transform import from_origin
from overture import con, path
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"
S = pd.read_csv(R / "data/places_selected.csv")[["nm", "lon", "lat", "cls"]]
S = pd.concat([S, pd.DataFrame([["Παλαμάς", 22.083, 39.467, "town"], ["Κεραμίδι", 22.085, 39.56, "village"]], columns=S.columns)], ignore_index=True)
S["nm"] = S.nm.str.replace("o", "ο")  # a Latin 'o' in one OSM name
P = {}
for k, r in enumerate(S.itertuples()):
    dx, dy = (0.02, 0.015) if r.cls == "town" else (0.014, 0.0105)
    P[f"p{k:02d}"] = [r.nm, round(r.lon - dx, 4), round(r.lat - dy, 4), round(r.lon + dx, 4), round(r.lat + dy, 4)]
json.dump(P, open(R / "data/places.json", "w"), ensure_ascii=False, indent=0)
cache = R / "cache/place_buildings.parquet"
if not cache.exists():
    c = con(); c.sql("SET geometry_always_xy = true")
    w = " OR ".join(f"(bbox.xmin > {a} AND bbox.xmax < {cc} AND bbox.ymin > {b} AND bbox.ymax < {d})" for _, a, b, cc, d in P.values())
    c.sql(f"""COPY (SELECT id, height, ST_AsWKB(geometry) wkb FROM read_parquet('{path("buildings","building")}', hive_partitioning=1)
      WHERE bbox.xmin > 21.4 AND bbox.xmax < 23.0 AND bbox.ymin > 39.2 AND bbox.ymax < 40.1 AND ({w})) TO '{cache}' (FORMAT parquet)""")
b = pd.read_parquet(cache); print(len(b), "buildings", flush=True)
g = gpd.GeoDataFrame(b.drop(columns="wkb"), geometry=shapely.from_wkb(b.wkb.apply(bytes)), crs=4326); g = g[g.geom_type.isin(["Polygon", "MultiPolygon"])]
Z = {k: gpd.read_file(p).to_crs(2100) for k, p in {"q100": RAW / "official/el08_friv_0100_rev1.json", "q1000": RAW / "official/el08_friv_1000_rev1.json", "dan": R / "data/daniel_flood_union.geojson"}.items()}
summary = {}
for key, (name, x0, y0, x1, y1) in P.items():
    c = g.cx[x0:x1, y0:y1].copy()
    if not len(c): continue
    cm = c.to_crs(2100); cen = cm.centroid
    X0, Y0, X1, Y1 = cm.total_bounds; RES = 5.0; W, H = int((X1 - X0) / RES) + 3, int((Y1 - Y0) / RES) + 3; T = from_origin(X0 - RES, Y1 + RES, RES, RES)
    col = ((cen.x.values - (X0 - RES)) / RES).astype(int); row = ((Y1 + RES - cen.y.values) / RES).astype(int)
    box = shapely.box(X0 - 50, Y0 - 50, X1 + 50, Y1 + 50); flag = np.zeros(len(c), int)
    for bit, k in ((1, "q100"), (2, "q1000"), (4, "dan")):
        z = Z[k]; z = z.iloc[z.sindex.query(box, predicate="intersects")]
        shp = []
        for geom in z.geometry.values:           # clip first: the zone polygons are huge and rasterising them whole is slow
            try: q = shapely.clip_by_rect(geom, X0 - 50, Y0 - 50, X1 + 50, Y1 + 50)
            except Exception: q = shapely.intersection(shapely.make_valid(geom), box)
            if q is not None and not q.is_empty: shp.append(q)
        if shp: flag |= bit * rasterize(((x, 1) for x in shp), out_shape=(H, W), transform=T, dtype="uint8")[row, col].astype(int)
    simp = cm.geometry.simplify(0.7).to_crs(4326); out = []
    for geom, f, h, a in zip(simp.values, flag, c.height.values, cm.area.values):
        p = geom if geom.geom_type == "Polygon" else max(geom.geoms, key=lambda q: q.area)
        xy = np.asarray(p.exterior.coords)[:-1]
        if len(xy) < 3: continue
        out.append([int(f), 0 if pd.isna(h) else int(round(h)), int(round(a))] + np.round((xy - [x0, y0]) * 1e5).astype(int).ravel().tolist())
    (R / f"web/assets/bld_{key}.json").write_text(json.dumps({"o": [x0, y0], "bbox": [x0, y0, x1, y1], "b": out}, separators=(",", ":")))
    fl = np.array([o[0] for o in out]); summary[key] = {"name": name, "n": len(out), "q100": int((fl & 1 > 0).sum()), "daniel": int((fl & 4 > 0).sum()), "daniel_out_q1000": int(((fl & 4 > 0) & (fl & 2 == 0)).sum())}
    print(key, summary[key], flush=True)
json.dump(summary, open(R / "data/places_summary.json", "w"), ensure_ascii=False, indent=1)
