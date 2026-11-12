"""Step 33: driving time to the nearest general hospital, normally and with flooded roads closed.

Network: Overture road segments split at their connectors (s32_network_fetch.py), undirected (one-way streets ignored),
speed by road class (assumed, below). Segment parts flagged as bridge or tunnel are never closed by water.
Scenarios: 'q100' closes every road part inside the official 100-year flood zone (ΥΠΕΝ ΣΔΚΠ EL08),
           'dan'  closes every road part inside the Storm Daniel extent (EMSR692; only where it was mapped).
A part is closed when at least 2 consecutive 20 m samples fall in the water mask (i.e. ~40 m of road under water).
Destinations: the 5 general hospitals of the Region and the nearest ones outside it (Lamia, Grevena, Katerini),
positions from Overture places (named entries, checked to fall in the hospital's town).
Origins: every H3 cell with buildings, at the mean position of its buildings, joined to the nearest road node
(the straight-line gap is added at 15 km/h).

Per H3 cell: hosp_min, hosp_min_q100, hosp_min_dan (minutes; NaN = no road connection at all, e.g. islands),
cut_q100, cut_dan (1 = had a road route normally, none in that scenario), hosp_name (nearest hospital normally)."""
import os; os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
import numpy as np, pandas as pd, geopandas as gpd, shapely, h3, pyproj
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import dijkstra
from scipy.spatial import cKDTree
from rasterio.features import rasterize
from rasterio.transform import from_origin
from common import CACHE, DATA, ROOT

KMH = {"motorway": 100, "trunk": 80, "primary": 70, "secondary": 60, "tertiary": 50, "unclassified": 40, "residential": 30,
       "living_street": 15, "unknown": 30, "service": 20, "track": 15}
HOSP = [  # (label, Overture name, expected town for the check)
    ("ΠΓΝ Λάρισας", "Πανεπιστημιακό Γενικό Νοσοκομείο Λάρισας", (39.61, 22.39)),
    ("ΓΝ Λάρισας", "Τμήμα Επειγόντων Περιστατικών Γενικό Νοσοκομείο Λάρισας/Emergency department", (39.64, 22.42)),
    ("ΓΝ Βόλου", "Achillopoulio General Hospital Of Volos", (39.36, 22.95)),
    ("ΓΝ Τρικάλων", "ΣΑΕΚ Γενικού Νοσοκομείου Τρικάλων", (39.55, 21.77)),
    ("ΓΝ Καρδίτσας", "Γενικο Νοσοκομειο Καρδιτσασ - Διαχειριση Υγειονομικου Υλικου", (39.36, 21.92)),
    ("ΓΝ Λαμίας", "Γενικό Νοσοκομείο Λαμίας-Επίσημο", (38.90, 22.43)),
    ("ΓΝ Γρεβενών", "Γενικό Νοσοκομείο Γρεβενών", (40.08, 21.43)),
    ("ΓΝ Κατερίνης", "Γενικό Νοσοκομείο Κατερίνης", (40.27, 22.50))]
F = pyproj.Transformer.from_crs(4326, 2100, always_xy=True)
fwd = lambda g: shapely.transform(g, lambda c: np.column_stack(F.transform(c[:, 0], c[:, 1])))

# --- network: one edge per stretch between consecutive connectors
n = pd.read_parquet(CACHE / "region_network.parquet")
geo = fwd(shapely.from_wkb(n.wkb.apply(bytes).values)); L = shapely.length(geo)
rows = []
for k, (conn, br) in enumerate(zip(n.conn.values, n.bridge.values)):
    cs = sorted(((c["at"], c["cid"]) for c in conn), key=lambda t: t[0])
    for (a0, c0), (a1, c1) in zip(cs[:-1], cs[1:]):
        if a1 > a0: rows.append((k, a0, a1, c0, c1))
E = pd.DataFrame(rows, columns=["seg", "a0", "a1", "c0", "c1"]); E["len"] = (E.a1 - E.a0) * L[E.seg.values]
E["kmh"] = n["class"].map(KMH).values[E.seg.values]; E["min"] = E.len / 1000 / E.kmh * 60
print("edges", len(E), "km", round(E.len.sum() / 1000), flush=True)

# --- flood masks (20 m) and sampling along each edge every 20 m
x0, y0, x1, y1 = shapely.total_bounds(geo); RES = 20
W, H = int((x1 - x0) / RES) + 1, int((y1 - y0) / RES) + 1; T = from_origin(x0, y1, RES, RES)
def mask(gs): return rasterize([(g, 1) for g in gs if g is not None and not g.is_empty], out_shape=(H, W), transform=T, dtype="uint8").astype(bool)
M = {"q100": mask(gpd.read_file(ROOT / "data/raw/official/el08_friv_0100_rev1.json").to_crs(2100).geometry),
     "dan": mask(gpd.read_file(DATA / "daniel_flood_union.geojson").to_crs(2100).geometry)}
ns = np.maximum(2, np.ceil(E.len.values / RES).astype(int)); eid = np.repeat(np.arange(len(E)), ns)
off = np.arange(len(eid)) - np.repeat(np.cumsum(ns) - ns, ns)
frac = E.a0.values[eid] + (E.a1.values - E.a0.values)[eid] * (off + .5) / ns[eid]
pts = shapely.line_interpolate_point(geo[E.seg.values[eid]], frac, normalized=True)
px, py = shapely.get_x(pts), shapely.get_y(pts); c = ((px - x0) / RES).astype(int); r = ((y1 - py) / RES).astype(int)
onbridge = np.zeros(len(eid), bool); segbr = n.bridge.values[E.seg.values[eid]]
for i in np.where([len(b) > 0 for b in n.bridge.values[E.seg.values]])[0]:
    s = np.where(eid == i)[0]
    for a, b in n.bridge.values[E.seg.values[i]]: onbridge[s] |= (frac[s] >= a) & (frac[s] <= b)
closed = {}
for k, m in M.items():
    wet = m[r.clip(0, H - 1), c.clip(0, W - 1)] & ~onbridge
    run = wet & np.r_[False, wet[1:] & (eid[1:] == eid[:-1])]          # two consecutive wet samples on the same edge
    closed[k] = np.bincount(eid[run], minlength=len(E)) > 0
    print(k, "closed edges", int(closed[k].sum()), "km", round(E.len.values[closed[k]].sum() / 1000), flush=True)

# --- graph
ids = pd.Index(pd.unique(np.r_[E.c0.values, E.c1.values])); i0 = ids.get_indexer(E.c0); i1 = ids.get_indexer(E.c1); NN = len(ids)
nodexy = np.zeros((NN, 2)); first = shapely.line_interpolate_point(geo[E.seg.values], E.a0.values, normalized=True)
last = shapely.line_interpolate_point(geo[E.seg.values], E.a1.values, normalized=True)
nodexy[i0] = np.column_stack([shapely.get_x(first), shapely.get_y(first)]); nodexy[i1] = np.column_stack([shapely.get_x(last), shapely.get_y(last)])
def graph(keep): return coo_matrix((E["min"].values[keep] + 1e-6, (i0[keep], i1[keep])), shape=(NN, NN)).tocsr()
tree = cKDTree(nodexy)
po = pd.read_parquet(CACHE / "region_pois.parquet"); hn = []
for lab, nm, (la, lo) in HOSP:
    p = po[po.name == nm].iloc[0]; assert abs(p.lat - la) < .06 and abs(p.lon - lo) < .06, (lab, p.lat, p.lon)
    hx, hy = F.transform(p.lon, p.lat); hn.append(tree.query([hx, hy])[1])
hn = np.array(hn)

# --- origins: cells with buildings, at their buildings' mean position
b = pd.read_parquet(CACHE / "region_buildings.parquet"); bc = shapely.centroid(shapely.from_wkb(b.wkb.apply(bytes).values))
bx, by = shapely.get_x(bc), shapely.get_y(bc)
cell = [h3.latlng_to_cell(y, x, 8) for x, y in zip(bx, by)]
B = pd.DataFrame({"h3": cell, "x": bx, "y": by}).groupby("h3")[["x", "y"]].mean()
ox, oy = F.transform(B.x.values, B.y.values); dgap, onode = tree.query(np.column_stack([ox, oy]))
gap_min = dgap / 1000 / 15 * 60
out = pd.DataFrame({"h3": B.index})
allopen = np.ones(len(E), bool)
for tag, keep in [("", allopen), ("_q100", ~closed["q100"]), ("_dan", ~closed["dan"])]:
    D, _, src = dijkstra(graph(keep), directed=False, indices=hn, min_only=True, return_predecessors=True)
    t = D[onode] + gap_min; t[~np.isfinite(D[onode])] = np.nan
    out["hosp_min" + tag] = t
    if tag == "": out["hosp_name"] = [HOSP[list(hn).index(s)][0] if s >= 0 else None for s in src[onode]]
out["cut_q100"] = (out.hosp_min.notna() & out.hosp_min_q100.isna()).astype(int)
out["cut_dan"] = (out.hosp_min.notna() & out.hosp_min_dan.isna()).astype(int)
out.to_parquet(DATA / "access_h3.parquet")
g = pd.read_parquet(DATA / "thessaly_h3.parquet", columns=["h3", "in_region", "population"]).merge(out, on="h3", how="left")
g = g[g.in_region > 0.5]
print(out.describe().T[["count", "mean", "50%", "max"]].round(1))
print("people >30 min:", int(g.population[g.hosp_min > 30].sum()), "| >60 min:", int(g.population[g.hosp_min > 60].sum()),
      "| no road link:", int(g.population[g.hosp_min.isna() & g.h3.isin(out.h3)].sum()))
for s in ("q100", "dan"):
    print(s, "cut off people:", int(g.population[g[f"cut_{s}"] == 1].sum()),
          "| +15 min or more:", int(g.population[(g[f"hosp_min_{s}"] - g.hosp_min) >= 15].sum()))
