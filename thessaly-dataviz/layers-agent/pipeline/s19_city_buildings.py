"""City building footprints with flood flags → web/assets/bld_<city>.json (loaded on demand when zoomed into a city).
flag bits: 1 = inside official Q100 zone, 2 = inside Q1000, 4 = inside Storm Daniel flood extent (EMSR692). Centroid test on a 5 m raster."""
import os, json, pathlib, numpy as np, pandas as pd, geopandas as gpd, shapely
from rasterio.features import rasterize
from rasterio.transform import from_origin
from s18_city_buildings_fetch import CITIES
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"
b = pd.read_parquet(R / "cache/city_buildings.parquet")
g = gpd.GeoDataFrame(b.drop(columns="wkb"), geometry=shapely.from_wkb(b.wkb.apply(bytes)), crs=4326)
g = g[g.geom_type.isin(["Polygon", "MultiPolygon"])]
Z = {k: gpd.read_file(p).to_crs(2100) for k, p in {"q100": RAW / "official/el08_friv_0100_rev1.json", "q1000": RAW / "official/el08_friv_1000_rev1.json", "dan": R / "data/daniel_flood_union.geojson"}.items()}
summary = {}
for name, (x0, y0, x1, y1) in CITIES.items():
    c = g.cx[x0:x1, y0:y1].copy(); cm = c.to_crs(2100); cen = cm.centroid
    X0, Y0, X1, Y1 = cm.total_bounds; RES = 5.0; W, H = int((X1 - X0) / RES) + 3, int((Y1 - Y0) / RES) + 3; T = from_origin(X0 - RES, Y1 + RES, RES, RES)
    col = ((cen.x.values - (X0 - RES)) / RES).astype(int); row = ((Y1 + RES - cen.y.values) / RES).astype(int)
    box = shapely.box(X0 - 50, Y0 - 50, X1 + 50, Y1 + 50); flag = np.zeros(len(c), int)
    for bit, k in ((1, "q100"), (2, "q1000"), (4, "dan")):
        z = Z[k]; z = z.iloc[z.sindex.query(box, predicate="intersects")]; print(name, k, len(z), flush=True)
        if len(z): flag |= bit * rasterize(((x, 1) for x in z.geometry.values if x is not None and not x.is_empty), out_shape=(H, W), transform=T, dtype="uint8")[row, col].astype(int)
    simp = cm.geometry.simplify(0.7).to_crs(4326)
    out = []
    for geom, f, h, a in zip(simp.values, flag, c.height.values, cm.area.values):
        p = geom if geom.geom_type == "Polygon" else max(geom.geoms, key=lambda q: q.area)
        xy = np.asarray(p.exterior.coords)[:-1]
        if len(xy) < 3: continue
        q = np.round((xy - [x0, y0]) * 1e5).astype(int).ravel().tolist()
        out.append([int(f), 0 if pd.isna(h) else int(round(h)), int(round(a))] + q)
    (R / f"web/assets/bld_{name}.json").write_text(json.dumps({"o": [x0, y0], "bbox": [x0, y0, x1, y1], "b": out}, separators=(",", ":")))
    fl = np.array([o[0] for o in out]); summary[name] = {"n": len(out), "q100": int((fl & 1 > 0).sum()), "q1000": int((fl & 2 > 0).sum()), "daniel": int((fl & 4 > 0).sum()),
        "daniel_out_q1000": int(((fl & 4 > 0) & (fl & 2 == 0)).sum()), "mb": round(os.path.getsize(R / f"web/assets/bld_{name}.json") / 1e6, 2)}
print(json.dumps(summary, indent=1)); (R / "data/city_buildings_summary.json").write_text(json.dumps(summary, ensure_ascii=False, indent=1))
