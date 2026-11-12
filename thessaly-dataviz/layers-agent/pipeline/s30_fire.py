"""Step 30: wildfire layer from the FSim dataset for Greece (Zenodo 10.5281/zenodo.17579289, CC BY 4.0, 100 m, EPSG:2100)
and EFFIS burnt areas 2021 onwards (the FSim fuels stop at 2018-2020, so newer burns are not in it).

Manual input: download FSim_Dataset_Greece_raw_files.rar from https://zenodo.org/records/17579289 and put
Burn_Prob.img and CFL.img in cache/fsim/. The EFFIS polygons are fetched here.

Per H3 cell:
  fire_bp_pct      annual burn probability, %, area-weighted over the land of the cell (non-burnable pixels count as 0)
  fire_cfl_m       conditional flame length, m, mean over the burnable pixels (how intense a fire is where it can burn)
  fire_burnable    share of the cell with a burnable fuel model
  fire_hazard      fire_bp_pct x fire_cfl_m (the usual 'integrated hazard' of FSim studies; relative ranking only)
  burned_2021_share share of the cell inside an EFFIS burnt-area polygon dated 2021-01-01 or later
Also writes web/assets/ov_fire.png (hazard classes + recent burns) for the draped overlay."""
import zipfile, io, numpy as np, pandas as pd, geopandas as gpd, rasterio, h3
from rasterio.windows import from_bounds
from rasterio.warp import reproject, Resampling
from rasterio.transform import from_bounds as tfb
from rasterio.features import rasterize
from pyproj import Transformer
from PIL import Image
from common import CACHE, DATA, ROOT, fetch

g = gpd.read_parquet(DATA / "grid.parquet")
to_gr = Transformer.from_crs(4326, 2100, always_xy=True); to_ll = Transformer.from_crs(2100, 4326, always_xy=True)
x, y = to_gr.transform(g.lon.values, g.lat.values)
B = (x.min() - 3000, y.min() - 3000, x.max() + 3000, y.max() + 3000)

def window(name):
    with rasterio.open(CACHE / "fsim" / f"{name}.img") as r:
        w = from_bounds(*B, r.transform).round_offsets().round_lengths()
        a = r.read(1, window=w); return np.where(a < -1e30, np.nan, a), r.window_transform(w)

bp, T = window("Burn_Prob"); cfl, T2 = window("CFL"); assert T == T2 and bp.shape == cfl.shape
rr, cc = np.indices(bp.shape); px = T.c + (cc + .5) * T.a; py = T.f + (rr + .5) * T.e
lo, la = to_ll.transform(px.ravel(), py.ravel())
cell = np.array([h3.latlng_to_cell(a_, o_, 8) for a_, o_ in zip(la, lo)])
p = pd.DataFrame({"h3": cell, "bp": bp.ravel(), "cfl": cfl.ravel()})
p["burnable"] = p.bp.notna()
a = p.groupby("h3").agg(n=("bp", "size"), nb=("burnable", "sum"), bpsum=("bp", "sum"), cfl=("cfl", "mean"))
d = g[["h3", "in_region"]].merge(a, left_on="h3", right_index=True, how="left")
land = (d.n * d.in_region.clip(lower=0.02)).clip(lower=1)          # pixels of the cell that are inside the region (not sea)
d["fire_burnable"] = (d.nb / land).clip(0, 1)
d["fire_bp_pct"] = (100 * d.bpsum / land).clip(upper=100 * np.nanmax(bp))
d["fire_cfl_m"] = d.cfl
d.loc[d.nb.fillna(0) == 0, ["fire_bp_pct", "fire_burnable"]] = 0
d["fire_hazard"] = d.fire_bp_pct * d.fire_cfl_m.fillna(0)

# EFFIS burnt areas, 2021 onwards (FSim already zeroes 2019-2020 burns)
z = fetch("https://maps.wild-fire.eu/effis?service=WFS&request=GetFeature&typename=ms:modis.ba.poly&version=1.1.0"
          "&outputformat=SHAPEZIP&BBOX=20.9,38.8,24.4,40.3", "effis_ba_thessaly.zip")
with zipfile.ZipFile(z) as zf: zf.extractall(CACHE / "effis_ba")
ba = gpd.read_file(CACHE / "effis_ba" / "modis.ba.poly.shp").set_crs(4326, allow_override=True)
ba["date"] = pd.to_datetime(ba.FIREDATE, errors="coerce"); ba = ba[ba.date >= "2021-01-01"]
print("EFFIS polygons since 2021 in bbox:", len(ba), "| latest", ba.date.max().date())
u = ba.to_crs(2100).geometry.buffer(0).union_all(); gg = g.to_crs(2100)
hit = gg[gg.intersects(u)]
sh = (hit.geometry.intersection(u).area / hit.geometry.area).rename("burned_2021_share")
d = d.merge(sh, left_index=True, right_index=True, how="left"); d["burned_2021_share"] = d.burned_2021_share.fillna(0).clip(0, 1)
out = d[["h3", "fire_bp_pct", "fire_cfl_m", "fire_burnable", "fire_hazard", "burned_2021_share"]]
out.to_parquet(DATA / "fire_h3.parquet")
inr = d.in_region > 0.5
print(out[inr].describe().T[["count", "mean", "50%", "max"]].round(3))
print("cells with >30% burned since 2021:", int((out.burned_2021_share > .3).sum()))

# draped overlay: hazard = BP% x CFL in 4 classes (cut at the 50/75/90/97th percentile of burnable land in the region), recent burns hatched grey
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3; TW, TH = 2800, 1200
with rasterio.open(CACHE / "fsim" / "Burn_Prob.img") as r1, rasterio.open(CACHE / "fsim" / "CFL.img") as r2:
    dst = np.full((2, TH, TW), np.nan, "float32"); TT = tfb(W0, S0, E0, N0, TW, TH)
    for k, r in enumerate((r1, r2)):
        src = r.read(1).astype("float32"); src[src < -1e30] = np.nan
        reproject(src, dst[k], src_transform=r.transform, src_crs=r.crs, dst_transform=TT, dst_crs="EPSG:4326",
                  resampling=Resampling.average, src_nodata=np.nan, dst_nodata=np.nan)
hz = 100 * dst[0] * dst[1]
reg = rasterize([(gpd.read_file(DATA / "border_el61.geojson").to_crs(4326).geometry.iloc[0], 1)], out_shape=(TH, TW), transform=TT).astype(bool)
q = np.nanpercentile(hz[reg & np.isfinite(hz)], [50, 75, 90, 97]); print("hazard class cuts (BP% x m):", q.round(2))
o = np.zeros((TH, TW, 4), "uint8")
for lim, col in zip(q, [(250, 204, 92, 120), (245, 150, 50, 170), (226, 82, 38, 205), (160, 20, 30, 235)]): o[hz >= lim] = col
o[~reg] = 0
bm = rasterize([(geom, 1) for geom in ba.geometry if geom is not None], out_shape=(TH, TW), transform=TT).astype(bool) & reg
yy, xx = np.indices((TH, TW)); o[bm] = (70, 70, 78, 150); o[bm & ((xx + yy) % 6 < 2)] = (20, 20, 24, 230)
Image.fromarray(o, "RGBA").save(ROOT / "web/assets/ov_fire.png", optimize=True)
(DATA / "fire_summary.json").write_text(pd.Series({"cuts": q.round(3).tolist(), "effis_latest": str(ba.date.max().date()), "effis_n": int(len(ba))}).to_json())
print("ov_fire.png written")
