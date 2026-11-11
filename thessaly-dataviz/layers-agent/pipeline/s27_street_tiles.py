"""Street-map tiles for the whole region → web/assets/st/r_<i>_<j>.json (roads, street labels, facilities, flood-zone raster),
web/assets/st/b_<i>_<j>.json (building footprints), web/assets/st/region.json (main roads for low zoom), web/assets/st/manifest.json.
Roads/buildings: Overture (OSM). Each road is cut wherever its flood status changes (20 m samples on a 5 m mask).
flag bits: 1 = official Q100 zone, 2 = official Q1000 zone, 4 = Storm Daniel extent (EMSR692)."""
import os, re, io, json, math, base64, pathlib, sys, numpy as np, pandas as pd, geopandas as gpd, shapely, pyproj
from rasterio.features import rasterize
from rasterio.transform import from_origin
from PIL import Image
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"; OUT = R / "web/assets/st"; OUT.mkdir(exist_ok=True)
X00, Y00, TX, TY = 20.9, 38.8, 0.4, 0.3
RANK = {"motorway": 0, "trunk": 0, "primary": 0, "secondary": 1, "tertiary": 1, "residential": 2, "unclassified": 2, "living_street": 2, "pedestrian": 2, "unknown": 2, "service": 3, "track": 3}
F = pyproj.Transformer.from_crs(4326, 2100, always_xy=True); B = pyproj.Transformer.from_crs(2100, 4326, always_xy=True)
fwd = lambda g: shapely.transform(g, lambda c: np.column_stack(F.transform(c[:, 0], c[:, 1])))
bwd = lambda g: shapely.transform(g, lambda c: np.column_stack(B.transform(c[:, 0], c[:, 1])))

pe = gpd.read_file(RAW / "official/adm_pol_perif_enotites.json").to_crs(2100)
region = shapely.unary_union(pe[pe.lektiko.str.contains("ΛΑΡΙΣ|ΜΑΓΝΗΣ|ΣΠΟΡΑΔ|ΚΑΡΔΙΤΣ|ΤΡΙΚΑΛ")].geometry.values).buffer(1500).simplify(200)
shapely.prepare(region)
rd = pd.read_parquet(R / "cache/region_roads.parquet"); rd = rd[rd["class"].isin(RANK)]
rgeo = fwd(shapely.from_wkb(rd.wkb.apply(bytes).values)); ok = (shapely.get_type_id(rgeo) == 1) & shapely.intersects(region, rgeo)
rgeo, rcls, rname = rgeo[ok], rd["class"].values[ok], rd.name.values[ok]; rtree = shapely.STRtree(rgeo); print("roads", len(rgeo), flush=True)
bw = pd.read_parquet(R / "cache/region_buildings.parquet").wkb.apply(bytes).values
bgeo = fwd(shapely.from_wkb(bw)); bcen = shapely.centroid(bgeo); ok = shapely.contains(region, bcen); bgeo, bcen = bgeo[ok], bcen[ok]
bx, by = shapely.get_x(bcen), shapely.get_y(bcen); print("buildings", len(bgeo), flush=True)
po = pd.read_parquet(R / "cache/region_pois.parquet"); po = po[po.name.notna()].copy()
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
px, py = F.transform(po.lon.values, po.lat.values)
Z = {k: gpd.read_file(p).to_crs(2100) for k, p in {"q100": RAW / "official/el08_friv_0100_rev1.json", "q1000": RAW / "official/el08_friv_1000_rev1.json", "dan": R / "data/daniel_flood_union.geojson"}.items()}
import rasterio
from scipy.ndimage import median_filter
from rasterio.warp import reproject, Resampling
# Height above nearest drainage: the 90 m model (s10), which agrees with Storm Daniel better than a 30 m run (s29: CSI 0.42 vs 0.46), resampled bilinearly to 30 m for sampling
with rasterio.open(R / "cache/hand_90m.tif") as r_:
    HT = rasterio.transform.from_origin(r_.bounds.left, r_.bounds.top, 30, 30); HND = np.full((r_.height * 3, r_.width * 3), np.nan, "float32")
    reproject(rasterio.band(r_, 1), HND, dst_transform=HT, dst_crs=r_.crs, resampling=Resampling.bilinear, dst_nodata=np.nan)
LEVELS = np.array([1, 2, 3, 4, 5, 6, 8, 10.])
def hcls(xs, ys):                   # water-level class: index of the first level in LEVELS that floods the point; 8 = never (above +10 m)
    xs, ys = np.asarray(xs, float), np.asarray(ys, float); c = ((xs - HT.c) / 30).astype(int); r = ((HT.f - ys) / 30).astype(int); ok = (c >= 0) & (c < HND.shape[1]) & (r >= 0) & (r < HND.shape[0])
    v = np.full(xs.shape, np.nan, "float32"); v[ok] = HND[r[ok], c[ok]]; return np.searchsorted(LEVELS, v, side="left").astype(int)
KMH = np.zeros(9); BH = np.zeros(9, int); PH = np.zeros(9, int)
PAL = np.zeros((8, 4), "uint8"); PAL[1] = PAL[3] = (150, 100, 235, 120); PAL[2] = (190, 170, 235, 80); PAL[4] = PAL[5] = (240, 96, 80, 135); PAL[6] = PAL[7] = (79, 163, 224, 130)
cat = lambda f: "dan_out" if (f & 4 and not f & 2) else "dan" if f & 4 else "q100" if f & 1 else "q1000" if f & 2 else "ok"
def enc(c, x0, y0):
    q = np.round((c - [x0, y0]) * 1e5).astype(int); d = np.diff(q, axis=0); d = d[(d != 0).any(axis=1)]
    return q[0].tolist() + d.ravel().tolist()
man = {"o": [X00, Y00], "d": [TX, TY], "r": [], "b": []}; REG = []; KM = {}; RES = 5.0
for i in range(9):
    for j in range(5):
        x0, y0 = round(X00 + i * TX, 4), round(Y00 + j * TY, 4); x1, y1 = x0 + TX, y0 + TY
        boxm = fwd(shapely.box(x0, y0, x1, y1)); idx = rtree.query(boxm, predicate="intersects")
        if not len(idx): continue
        X0, Y0, X1, Y1 = boxm.bounds; W, H = int((X1 - X0) / RES) + 3, int((Y1 - Y0) / RES) + 3; T = from_origin(X0 - RES, Y1 + RES, RES, RES); M = np.zeros((H, W), "uint8")
        for bit, k in ((1, "q100"), (2, "q1000"), (4, "dan")):
            z = Z[k]; z = z.iloc[z.sindex.query(boxm, predicate="intersects")]; shp = []
            for geom in z.geometry.values:
                try: q = shapely.clip_by_rect(geom, X0 - 50, Y0 - 50, X1 + 50, Y1 + 50)
                except Exception: q = shapely.intersection(shapely.make_valid(geom), shapely.box(X0 - 50, Y0 - 50, X1 + 50, Y1 + 50))
                if q is not None and not q.is_empty: shp.append(q)
            if shp: M |= (bit * rasterize(((x, 1) for x in shp), out_shape=(H, W), transform=T, dtype="uint8")).astype("uint8")
        samp = lambda xs, ys: M[np.clip(((Y1 + RES - ys) / RES).astype(int), 0, H - 1), np.clip(((xs - (X0 - RES)) / RES).astype(int), 0, W - 1)]
        g = shapely.intersection(rgeo[idx], boxm); parts, rep = shapely.get_parts(g, return_index=True); keep = shapely.get_type_id(parts) == 1; parts, rep = parts[keep], idx[rep[keep]]
        dens = shapely.segmentize(parts, 20.0); names, nidx, pieces, meta, lab = [], {}, [], [], []
        for gm, cls, nm in zip(dens, rcls[rep], rname[rep]):
            xy = shapely.get_coordinates(gm)
            if len(xy) < 2: continue
            mid = (xy[:-1] + xy[1:]) / 2; f = samp(mid[:, 0], mid[:, 1]); seg = np.hypot(*(xy[1:] - xy[:-1]).T); ni = -1; rk = RANK[cls]
            hc = hcls(mid[:, 0], mid[:, 1]); hc = median_filter(hc, 5, mode="nearest") if len(hc) >= 5 else hc; key = f.astype(int) * 16 + hc
            if isinstance(nm, str) and nm.strip():
                nm = nm.strip(); ni = nidx.get(nm, -1)
                if ni < 0: ni = nidx[nm] = len(names); names.append(nm)
            cut = np.flatnonzero(key[1:] != key[:-1]) + 1; st = np.r_[0, cut]; en = np.r_[cut, len(f)]
            for s, e in zip(st, en):
                fl = int(f[s]); KM[cat(fl)] = KM.get(cat(fl), 0) + float(seg[s:e].sum()) / 1000; KMH[int(hc[s])] += float(seg[s:e].sum()) / 1000; pieces.append(shapely.linestrings(xy[s:e + 1])); meta.append((rk, fl, ni, int(hc[s])))
            L = shapely.length(gm)
            if ni >= 0 and rk <= 2 and L > 90:
                p, a, b = (shapely.line_interpolate_point(gm, t, normalized=True) for t in (.5, .45, .55)); ang = math.degrees(math.atan2(b.y - a.y, b.x - a.x)); ang = ang - 180 if ang > 90 else ang + 180 if ang < -90 else ang
                lab.append((rk, -L, ni, p.x, p.y, round(ang)))
        pieces = np.array(pieces, dtype=object); fine = bwd(shapely.simplify(pieces, 2.5)); roads = [[rk, fl, ni, hc] + enc(shapely.get_coordinates(gg), x0, y0) for gg, (rk, fl, ni, hc) in zip(fine, meta)]
        main = [q for q, m in enumerate(meta) if m[0] <= 1]
        if main:
            for gg, q in zip(bwd(shapely.simplify(pieces[main], 12.0)), main): REG.append([meta[q][0], meta[q][1], meta[q][3]] + enc(shapely.get_coordinates(gg), X00, Y00))
        lab.sort(); cell, labels = {}, []       # one label per street name per ~350 m, none closer than 45 m to another; most important first
        for rk, nl, ni, x, y, ang in lab:
            cx, cy = int(x // 350), int(y // 350); near = [u for a in (-1, 0, 1) for b in (-1, 0, 1) for u in cell.get((cx + a, cy + b), ())]
            if any((n == ni and math.hypot(x - ux, y - uy) < 350) or math.hypot(x - ux, y - uy) < 45 for n, ux, uy in near): continue
            cell.setdefault((cx, cy), []).append((ni, x, y)); lo, la = B.transform(x, y); labels.append([ni, round((lo - x0) * 1e5), round((la - y0) * 1e5), ang, rk])
            if len(labels) >= 2500: break
        pm = (po.lon.values > x0) & (po.lon.values < x1) & (po.lat.values > y0) & (po.lat.values < y1) & shapely.contains_xy(region, px, py); pois, seen = [], []
        for q in np.flatnonzero(pm)[np.argsort(-po.confidence.values[pm])]:
            r_ = po.iloc[q]
            if any(k == r_.kind and math.hypot(px[q] - ux, py[q] - uy) < 70 for k, ux, uy in seen): continue
            seen.append((r_.kind, px[q], py[q])); pois.append([r_.kind, r_["name"][:60], round((r_.lon - x0) * 1e5), round((r_.lat - y0) * 1e5), int(samp(px[q:q + 1], py[q:q + 1])[0]), int(hcls(px[q:q + 1], py[q:q + 1])[0])]); PH[pois[-1][5]] += 1
        out = {"o": [x0, y0], "names": names, "r": roads, "labels": labels, "pois": pois}
        Ms = M[::4, ::4]; hh, ww = Ms.shape; ex, ey = X0 - RES, Y1 + RES
        cx_, cy_ = B.transform([ex, ex, ex + ww * 20, ex + ww * 20], [ey - hh * 20, ey, ey, ey - hh * 20])     # bottom-left, top-left, top-right, bottom-right
        out["q"] = [[round(a, 6), round(b, 6)] for a, b in zip(cx_, cy_)]
        gx, gy = np.meshgrid(ex + (np.arange(ww) + .5) * 20, ey - (np.arange(hh) + .5) * 20); hcl = hcls(gx.ravel(), gy.ravel()).reshape(hh, ww).astype("uint8")
        if (hcl < 8).any(): buf = io.BytesIO(); Image.fromarray(hcl * 28, "L").save(buf, "PNG", optimize=True); out["hand"] = base64.b64encode(buf.getvalue()).decode()
        if Ms.any():
            buf = io.BytesIO(); Image.fromarray(PAL[Ms], "RGBA").save(buf, "PNG", optimize=True)
            out["zone"] = {"png": base64.b64encode(buf.getvalue()).decode(), "q": out["q"]}
        (OUT / f"r_{i}_{j}.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":"))); man["r"].append([i, j])
        bm = (bx >= X0) & (bx < X1) & (by >= Y0) & (by < Y1); nb = 0
        if bm.any():
            lon, lat = B.transform(bx[bm], by[bm]); bm2 = np.flatnonzero(bm)[(lon >= x0) & (lon < x1) & (lat >= y0) & (lat < y1)]     # assign by lon/lat centroid so each building lands in exactly one tile
            if len(bm2):
                polys = bgeo[bm2]; big = shapely.get_type_id(polys) == 6; polys = np.where(big, [max(shapely.get_parts(p), key=shapely.area) if t else p for p, t in zip(polys, big)], polys)
                ring = bwd(shapely.simplify(shapely.get_exterior_ring(polys), 0.8)); fl = samp(bx[bm2], by[bm2]); bh = hcls(bx[bm2], by[bm2]); BH += np.bincount(bh, minlength=9); bl = []
                for gg, f_, h_ in zip(ring, fl, bh):
                    c = shapely.get_coordinates(gg)
                    if len(c) >= 4: bl.append([int(f_), int(h_)] + enc(c[:-1], x0, y0))
                nb = len(bl); (OUT / f"b_{i}_{j}.json").write_text(json.dumps({"o": [x0, y0], "b": bl}, separators=(",", ":"))); man["b"].append([i, j])
        print(i, j, "roads", len(roads), "labels", len(labels), "pois", len(pois), "bld", nb, "kb", os.path.getsize(OUT / f"r_{i}_{j}.json") // 1000, (os.path.getsize(OUT / f"b_{i}_{j}.json") // 1000 if nb else 0), flush=True)
(OUT / "region.json").write_text(json.dumps({"o": [X00, Y00], "r": REG}, separators=(",", ":")))
man["km"] = {k: round(v) for k, v in KM.items()}
cal = {c["level"]: c for c in json.load(open(R / "web/assets/hand.json"))["calibration"]}
man["sim"] = {"levels": LEVELS.tolist(), "km": np.cumsum(KMH[:8]).round().astype(int).tolist(), "bld": np.cumsum(BH[:8]).tolist(), "pois": np.cumsum(PH[:8]).tolist(), "km_total": round(float(KMH.sum())), "bld_total": int(BH.sum()), "pois_total": int(PH.sum()),
              "cal": [{"hit": cal[l]["hit_rate"], "fa": cal[l]["false_alarm"], "km2": cal[l]["sim_km2"]} for l in LEVELS.tolist()]}
(OUT / "manifest.json").write_text(json.dumps(man, separators=(",", ":")))
print("region roads", len(REG), os.path.getsize(OUT / "region.json") // 1000, "kB; km", man["km"], "tiles", len(man["r"]), len(man["b"]))
