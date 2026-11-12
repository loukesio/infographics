"""Step 31: ground motion from the Copernicus European Ground Motion Service (EGMS), Ortho (Level 3), vertical component,
release 2020-2025 (production date 22/09/2026). 100 m grid, EPSG:3035, displacement time series every 6 days, Dec 2020 - Nov 2025.

Manual input: in the EGMS Explorer (egms.land.copernicus.eu, EU Login) search the archive with Level = ORTHO, release 2020-2025,
over Thessaly, and download the 6 'U' tiles E52N18, E52N19, E53N18, E53N19, E54N18, E54N19 into cache/egms/ (zips as downloaded).

Why not the ready 'mean_velocity': the series contains the 3 March 2021 Thessaly earthquake (Mw 6.3, Damasi-Tyrnavos), a sudden
drop of up to ~40 cm. A straight line through 2020-2025 turns that step into a fake '-29 mm/yr' bowl. So here:
  gm_vel_mm      trend 1 May 2021 - Nov 2025 (after the earthquake), mm/yr, mean over the measured part of the cell (negative = sinking)
  gm_vel_p10_mm  10th percentile of that trend in the cell (the fastest-sinking tenth)
  gm_eq2021_mm   step across the earthquake: mean of the 3 dates after 3 Mar 2021 minus mean of the 3 dates before, mm
  gm_cover       share of the cell with a measurement (InSAR gaps: ploughed fields, forest, water)
Also writes web/assets/ov_ground.png (post-2021 sinking) ."""
import glob, zipfile, numpy as np, pandas as pd, geopandas as gpd, h3
from rasterio.transform import from_origin, from_bounds as tfb
from rasterio.warp import reproject, Resampling
from rasterio.features import rasterize
from pyproj import Transformer
from PIL import Image
from common import CACHE, DATA, ROOT

zips = sorted(glob.glob(str(CACHE / "egms" / "EGMS_L3_*_U_2020_2025_*.zip"))); assert len(zips) == 6, zips
g = gpd.read_parquet(DATA / "grid.parquet")
to3035 = Transformer.from_crs(4326, 3035, always_xy=True); to4326 = Transformer.from_crs(3035, 4326, always_xy=True)
gx, gy = to3035.transform(g.lon.values, g.lat.values); BX = (gx.min() - 3000, gx.max() + 3000); BY = (gy.min() - 3000, gy.max() + 3000)
parts = []
for zp in zips:
    z = zipfile.ZipFile(zp); name = [n for n in z.namelist() if n.endswith(".csv")][0]
    with z.open(name) as f: hdr = f.readline().decode().strip().split(",")
    dates = [c for c in hdr if c.isdigit()]; t = pd.to_datetime(dates).values
    yrs = ((t - t[0]) / np.timedelta64(1, "D") / 365.25).astype("float64")
    post = t >= np.datetime64("2021-05-01"); tp = yrs[post] - yrs[post].mean()
    before = np.where(t < np.datetime64("2021-03-03"))[0][-3:]; after = np.where(t > np.datetime64("2021-03-04"))[0][:3]
    with z.open(name) as f:
        for ch in pd.read_csv(f, chunksize=200000, usecols=["easting", "northing"] + dates, dtype="float32"):
            ch = ch[ch.easting.between(*BX) & ch.northing.between(*BY)]
            if not len(ch): continue
            Y = ch[dates].to_numpy("float64")
            Yp = Y[:, post]; slope = ((Yp - Yp.mean(1, keepdims=True)) * tp).sum(1) / (tp ** 2).sum()
            step = Y[:, after].mean(1) - Y[:, before].mean(1)
            parts.append(pd.DataFrame({"e": ch.easting.values, "n": ch.northing.values, "v": slope, "eq": step}))
    print(name, "points so far", sum(len(p) for p in parts), flush=True)
P = pd.concat(parts, ignore_index=True)
lo, la = to4326.transform(P.e.values, P.n.values)
P["h3"] = [h3.latlng_to_cell(a, b, 8) for a, b in zip(la, lo)]
agg = P.groupby("h3").agg(nv=("v", "size"), gm_vel_mm=("v", "mean"), gm_vel_p10_mm=("v", lambda s: s.quantile(.1)), gm_eq2021_mm=("eq", "mean"))
d = g[["h3", "cell_km2"]].merge(agg, left_on="h3", right_index=True, how="left")
d["gm_cover"] = (d.nv * 0.01 / d.cell_km2).clip(0, 1).fillna(0)       # each point is one 100 m x 100 m = 0.01 km2 cell
out = d[["h3", "gm_vel_mm", "gm_vel_p10_mm", "gm_eq2021_mm", "gm_cover"]]; out.to_parquet(DATA / "ground_h3.parquet")
print(out[g.in_region > 0.5].describe().T[["count", "mean", "min", "50%", "max"]].round(2))

# draped overlay of the post-2021 trend (sinking only)
x0, y1 = P.e.min() - 50, P.n.max() + 50; W = int((P.e.max() - x0) / 100) + 2; H = int((y1 - P.n.min()) / 100) + 2
A = np.full((H, W), np.nan, "float32"); A[((y1 - P.n) / 100).astype(int), ((P.e - x0) / 100).astype(int)] = P.v
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3; TW, TH = 2800, 1200; TT = tfb(W0, S0, E0, N0, TW, TH)
dst = np.full((TH, TW), np.nan, "float32")
reproject(A, dst, src_transform=from_origin(x0, y1, 100, 100), src_crs="EPSG:3035", dst_transform=TT, dst_crs="EPSG:4326",
          resampling=Resampling.average, src_nodata=np.nan, dst_nodata=np.nan)
reg = rasterize([(gpd.read_file(DATA / "border_el61.geojson").to_crs(4326).geometry.iloc[0], 1)], out_shape=(TH, TW), transform=TT).astype(bool)
o = np.zeros((TH, TW, 4), "uint8")
for lim, col in [(-2, (150, 205, 235, 120)), (-5, (80, 150, 225, 180)), (-10, (60, 80, 210, 220)), (-20, (120, 40, 190, 245))]:
    o[dst <= lim] = col
o[~reg] = 0
Image.fromarray(o, "RGBA").save(ROOT / "web/assets/ov_ground.png", optimize=True)
print("overlay pixels <= -5 mm/yr:", int(((dst <= -5) & reg).sum()), "| ov_ground.png written")
