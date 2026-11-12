"""Step 35: summer land surface temperature (LST) from Landsat 8/9 Collection 2 Level-2 (ST_B10), via Microsoft Planetary Computer.

Scenes: July-August 2023, 2024, 2025, WRS paths 183-185 rows 32-33, scene cloud cover < 15 %; clouds, cloud shadow, dilated
cloud and snow masked per pixel with QA_PIXEL. Every scene is read on a 90 m grid (EPSG:2100) and the per-pixel median over all
clear acquisitions is kept. Landsat passes at ~10:30 local time, so this is a late-morning SURFACE temperature, not air temperature.

Per H3 cell: lst_c (median summer LST, deg C, mean over the cell), lst_n (clear acquisitions behind the median, min over the cell).
Also writes web/assets/ov_lst.png (built-up areas only, where it matters for people) and data/lst_summary.json."""
import json, requests, numpy as np, pandas as pd, geopandas as gpd, h3, rasterio
from concurrent.futures import ThreadPoolExecutor
from rasterio.vrt import WarpedVRT
from rasterio.enums import Resampling
from rasterio.transform import from_origin, from_bounds as tfb
from rasterio.warp import reproject
from rasterio.features import rasterize
from pyproj import Transformer
from PIL import Image
from common import CACHE, DATA, ROOT

S = requests.Session()
def token(): return S.get("https://planetarycomputer.microsoft.com/api/sas/v1/token/landsat-c2-l2", timeout=60).json()["token"]
items = []
for yr in (2023, 2024, 2025):
    q = {"collections": ["landsat-c2-l2"], "bbox": [21.0, 38.9, 23.9, 40.2], "datetime": f"{yr}-07-01/{yr}-08-31", "limit": 200,
         "query": {"eo:cloud_cover": {"lt": 15}, "platform": {"in": ["landsat-8", "landsat-9"]}}}
    items += S.post("https://planetarycomputer.microsoft.com/api/stac/v1/search", json=q, timeout=120).json()["features"]
items = [i for i in items if i["properties"]["landsat:wrs_path"] in ("183", "184", "185") and i["properties"]["landsat:wrs_row"] in ("032", "033")]
print("scenes", len(items), flush=True)
tok = token()
g = gpd.read_parquet(DATA / "grid.parquet"); tf = Transformer.from_crs(4326, 2100, always_xy=True)
gx, gy = tf.transform(g.lon.values, g.lat.values); RES = 90
X0, Y1 = gx.min() - 2000, gy.max() + 2000; W = int((gx.max() + 2000 - X0) / RES); H = int((Y1 - (gy.min() - 2000)) / RES)
T = from_origin(X0, Y1, RES, RES)
def read(it):
    out = []
    for key in ("lwir11", "qa_pixel"):
        u = it["assets"][key]["href"] + "?" + tok
        for k in range(3):
            try:
                with rasterio.open(u) as src, WarpedVRT(src, crs="EPSG:2100", transform=T, width=W, height=H,
                                                        resampling=Resampling.nearest if key == "qa_pixel" else Resampling.average) as v:
                    out.append(v.read(1)); break
            except Exception as e:
                if k == 2: print("fail", it["id"], key, e, flush=True); return None
    st, qa = out
    bad = (st == 0) | ((qa & ((1 << 1) | (1 << 3) | (1 << 4) | (1 << 5))) > 0) | (qa == 1)
    lst = st.astype("float32") * 0.00341802 + 149.0 - 273.15; lst[bad] = np.nan
    return lst
MM = np.lib.format.open_memmap(CACHE / "lst_stack.npy", mode="w+", dtype="int16", shape=(len(items), H, W)); kk = 0
with ThreadPoolExecutor(6) as ex:
    for k, a in enumerate(ex.map(read, items)):
        if a is not None: MM[kk] = np.where(np.isfinite(a), np.round(a * 10), -32768).astype("int16"); kk += 1
        if k % 10 == 0: print("read", k + 1, "of", len(items), flush=True)
MM.flush(); M = np.full((H, W), np.nan, "float32"); n = np.zeros((H, W), "int16")
for r0 in range(0, H, 100):
    blk = MM[:kk, r0:r0 + 100].astype("float32"); blk[blk == -32768] = np.nan; blk /= 10
    n[r0:r0 + 100] = np.isfinite(blk).sum(0)
    with np.errstate(all="ignore"): M[r0:r0 + 100] = np.nanmedian(blk, 0)
del MM; stack = range(kk)
M[n < 3] = np.nan
print("median LST over region pixels: p5/p50/p95", np.nanpercentile(M, [5, 50, 95]).round(1), "| clear acquisitions median", int(np.median(n[n > 0])))

# per H3 cell
rr, cc = np.nonzero(np.isfinite(M)); X = X0 + (cc + .5) * RES; Y = Y1 - (rr + .5) * RES
lo, la = Transformer.from_crs(2100, 4326, always_xy=True).transform(X, Y)
p = pd.DataFrame({"h3": [h3.latlng_to_cell(y, x, 8) for x, y in zip(lo, la)], "t": M[rr, cc], "n": n[rr, cc]})
agg = p.groupby("h3").agg(lst_c=("t", "mean"), lst_n=("n", "min"))
out = g[["h3"]].merge(agg, left_on="h3", right_index=True, how="left"); out.to_parquet(DATA / "lst_h3.parquet")
d = pd.read_parquet(DATA / "thessaly_h3.parquet").drop(columns="geometry").merge(out, on="h3"); d = d[d.in_region > 0.5]
lc = ["lc_tree_share", "lc_grass_share", "lc_crop_share", "lc_built_share"]; d["dom"] = d[lc].idxmax(axis=1)
by = d.groupby("dom").lst_c.median().round(1).to_dict(); print("median LST by dominant cover:", by)
(DATA / "lst_summary.json").write_text(json.dumps({"scenes": len(stack), "by_cover": by, "years": "Jul-Aug 2023-2025"}, ensure_ascii=False))

# overlay: built-up pixels only (WorldCover built share via the H3 table is too coarse; use LST where the cell is >= 30 % built)
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3; TW, TH = 2800, 1200; TT = tfb(W0, S0, E0, N0, TW, TH)
dst = np.full((TH, TW), np.nan, "float32")
reproject(M, dst, src_transform=T, src_crs="EPSG:2100", dst_transform=TT, dst_crs="EPSG:4326", resampling=Resampling.average, src_nodata=np.nan, dst_nodata=np.nan)
cells = d[d.lc_built_share >= 0.3].h3
polys = [__import__("shapely").geometry.Polygon([(b, a) for a, b in h3.cell_to_boundary(c)]) for c in cells]
bm = rasterize([(pg, 1) for pg in polys], out_shape=(TH, TW), transform=TT).astype(bool)
o = np.zeros((TH, TW, 4), "uint8")
for lim, col in [(34, (255, 230, 150, 150)), (38, (250, 180, 90, 185)), (42, (235, 110, 60, 215)), (46, (200, 40, 40, 235)), (50, (130, 0, 40, 245))]:
    o[(dst >= lim) & bm] = col
Image.fromarray(o, "RGBA").save(ROOT / "web/assets/ov_lst.png", optimize=True); print("ov_lst.png written")
