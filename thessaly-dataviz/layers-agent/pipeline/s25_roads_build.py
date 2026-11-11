"""Roads and key facilities per place, flagged by flood exposure → web/assets/roads_<key>.json.
Roads: Overture transportation segments (OSM). Each road is cut wherever its flood status changes (sampled every 20 m on 5 m masks).
flag bits: 1 = inside official Q100 zone, 2 = inside Q1000, 4 = inside Storm Daniel extent (EMSR692).
Facilities: Overture Places (schools, hospitals/clinics, town halls, fire/police, care homes) filtered by category + name; incomplete by nature."""
import os, re, json, math, pathlib, numpy as np, pandas as pd, geopandas as gpd, shapely
from rasterio.features import rasterize
from rasterio.transform import from_origin
from s24_roads_fetch import AREAS
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"
RANK = {"motorway": 0, "trunk": 0, "primary": 0, "secondary": 1, "tertiary": 1, "residential": 2, "unclassified": 2, "living_street": 2, "pedestrian": 2, "unknown": 2, "service": 3, "track": 3}
rd = pd.read_parquet(R / "cache/place_roads.parquet"); rd = rd[rd["class"].isin(RANK)]
rg = gpd.GeoDataFrame(rd.drop(columns="wkb"), geometry=shapely.from_wkb(rd.wkb.apply(bytes)), crs=4326); rg = rg[rg.geom_type == "LineString"]
po = pd.read_parquet(R / "cache/place_pois.parquet"); po = po[(po.confidence >= 0.6) & po.name.notna()].copy()
KIND = [("hospital", r"hospital$", r"Νοσοκομ|Hospital|Κλινική|Clinic|Κέντρο Υγείας|ΚΕΝΤΡΟ ΥΓΕΙΑΣ"),
        ("school", r"school$|preschool", r"Σχολ|ΣΧΟΛ|Γυμνάσι|ΓΥΜΝΑΣΙ|Λύκει|ΛΥΚΕΙ|Νηπιαγωγ|ΝΗΠΙΑΓΩΓ|ΕΠΑΛ|Παιδικ|School|Kindergarten"),
        ("townhall", r"^town_hall$", r"."), ("fire", r"^fire_station$", r"."), ("police", r"^police_station$", r"."), ("care", r"^retirement_home$|^nursing$", r".")]
BADCAT = r"language|driving|music|art_|cooking|dance|flight|traffic|cosmetology|ski_|animal|specialty|medical_school|vocational"
def kind(c, n):
    c = c if isinstance(c, str) else ""
    if re.search(BADCAT, c) or re.search(r"Ιατρείο|ιατρείο|Dr |Φροντιστήρι|ΦΡΟΝΤΙΣΤΗΡΙ|Derma|Οδοντ", n): return None
    for k, cre, nre in KIND:
        if re.search(cre, c) and re.search(nre, n): return k
    return None
po["kind"] = [kind(c, n) for c, n in zip(po.cat, po.name)]; po = po[po.kind.notna()]
Z = {k: gpd.read_file(p).to_crs(2100) for k, p in {"q100": RAW / "official/el08_friv_0100_rev1.json", "q1000": RAW / "official/el08_friv_1000_rev1.json", "dan": R / "data/daniel_flood_union.geojson"}.items()}
summary = {}
for key, (x0, y0, x1, y1) in AREAS.items():
    box4326 = shapely.box(x0, y0, x1, y1)
    r = rg[rg.intersects(box4326)].copy(); r["geometry"] = r.geometry.intersection(box4326); r = r[~r.geometry.is_empty].explode(index_parts=False); r = r[r.geom_type == "LineString"]
    rm = r.to_crs(2100)
    X0, Y0, X1, Y1 = gpd.GeoSeries([box4326], crs=4326).to_crs(2100).total_bounds; RES = 5.0
    W, H = int((X1 - X0) / RES) + 3, int((Y1 - Y0) / RES) + 3; T = from_origin(X0 - RES, Y1 + RES, RES, RES); box = shapely.box(X0 - 50, Y0 - 50, X1 + 50, Y1 + 50)
    M = np.zeros((H, W), "uint8")
    for bit, k in ((1, "q100"), (2, "q1000"), (4, "dan")):
        z = Z[k]; z = z.iloc[z.sindex.query(box, predicate="intersects")]; shp = []
        for geom in z.geometry.values:
            try: q = shapely.clip_by_rect(geom, X0 - 50, Y0 - 50, X1 + 50, Y1 + 50)
            except Exception: q = shapely.intersection(shapely.make_valid(geom), box)
            if q is not None and not q.is_empty: shp.append(q)
        if shp: M |= (bit * rasterize(((x, 1) for x in shp), out_shape=(H, W), transform=T, dtype="uint8")).astype("uint8")
    samp = lambda xs, ys: M[np.clip(((Y1 + RES - ys) / RES).astype(int), 0, H - 1), np.clip(((xs - (X0 - RES)) / RES).astype(int), 0, W - 1)]
    tr = gpd.GeoSeries(rm.geometry.values, crs=2100)
    names, nidx, roads, km, lab = [], {}, [], {}, []
    to4326 = lambda g: gpd.GeoSeries([g], crs=2100).to_crs(4326).iloc[0]
    dens = shapely.segmentize(rm.geometry.values, 20.0)
    back = gpd.GeoSeries(dens, crs=2100).to_crs(4326).values
    for gm, g4, cls, nm in zip(dens, back, rm["class"].values, rm.name.values):
        xy = np.asarray(gm.coords); ll = np.asarray(g4.coords)
        if len(xy) < 2: continue
        mid = (xy[:-1] + xy[1:]) / 2; f = samp(mid[:, 0], mid[:, 1]); seg = np.hypot(*(xy[1:] - xy[:-1]).T)
        ni = -1
        if isinstance(nm, str) and nm.strip():
            ni = nidx.setdefault(nm.strip(), len(names)); names.append(nm.strip()) if ni == len(names) else None
        s = 0
        for e in range(1, len(f) + 1):
            if e == len(f) or f[e] != f[s]:
                pts = ll[s:e + 1]; L = float(seg[s:e].sum()); fl = int(f[s]); km[fl] = km.get(fl, 0) + L / 1000
                keep = [0] + [i for i in range(1, len(pts) - 1) if i % 3 == 0] + [len(pts) - 1]   # thin the 20 m vertices
                q = np.round((pts[keep] - [x0, y0]) * 1e5).astype(int).ravel().tolist()
                roads.append([RANK[cls], fl, ni] + q); s = e
        if ni >= 0 and RANK[cls] <= 2 and gm.length > 90:
            p = gm.interpolate(0.5, normalized=True); a = gm.interpolate(0.45, normalized=True); b = gm.interpolate(0.55, normalized=True)
            ang = math.degrees(math.atan2(b.y - a.y, b.x - a.x)); ang = ang - 180 if ang > 90 else ang + 180 if ang < -90 else ang
            lab.append((RANK[cls], -gm.length, ni, p.x, p.y, round(ang)))
    lab.sort(); used, labels = [], []
    for rk, nl, ni, x, y, ang in lab:      # one label per street name per ~350 m, most important first
        if any(n == ni and math.hypot(x - ux, y - uy) < 350 for n, ux, uy in used) or any(math.hypot(x - ux, y - uy) < 45 for n, ux, uy in used): continue
        used.append((ni, x, y)); p = to4326(shapely.Point(x, y)); labels.append([ni, round((p.x - x0) * 1e5), round((p.y - y0) * 1e5), ang, rk])
        if len(labels) >= 420: break
    pp = po[(po.lon > x0) & (po.lon < x1) & (po.lat > y0) & (po.lat < y1)].sort_values("confidence", ascending=False); pois, seen = [], []
    if len(pp):
        pm = gpd.GeoSeries(gpd.points_from_xy(pp.lon, pp.lat), crs=4326).to_crs(2100); fl = samp(pm.x.values, pm.y.values)
        for (_, q), x, y, f in zip(pp.iterrows(), pm.x.values, pm.y.values, fl):
            if any(k == q.kind and math.hypot(x - ux, y - uy) < 70 for k, ux, uy in seen): continue
            seen.append((q.kind, x, y)); pois.append([q.kind, q["name"][:60], round((q.lon - x0) * 1e5), round((q.lat - y0) * 1e5), int(f)])
    cat = lambda f: "dan_out" if (f & 4 and not f & 2) else "dan" if f & 4 else "q100" if f & 1 else "q1000" if f & 2 else "ok"
    kms = {}
    for f, v in km.items(): kms[cat(f)] = round(kms.get(cat(f), 0) + v, 1)
    out = {"o": [x0, y0], "names": names, "r": roads, "labels": labels, "pois": pois, "km": kms}
    (R / f"web/assets/roads_{key}.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
    summary[key] = {"km": kms, "roads": len(roads), "labels": len(labels), "pois": len(pois), "pois_at_risk": sum(1 for p in pois if p[4] & 5), "kb": round(os.path.getsize(R / f"web/assets/roads_{key}.json") / 1e3)}
    print(key, summary[key], flush=True)
json.dump(summary, open(R / "data/roads_summary.json", "w"), ensure_ascii=False, indent=1)
