"""Step 2: Copernicus GLO-90 DEM -> elevation, slope, south-facing share per H3 cell."""
import numpy as np, geopandas as gpd, rasterio, pandas as pd
from rasterio.merge import merge
from rasterio.warp import reproject, Resampling, calculate_default_transform
from exactextract import exact_extract
from common import fetch, CACHE, DATA, CRS_GR

tiles = []
for lat in (38, 39, 40):
    for lon in (21, 22, 23, 24):
        tid = f"Copernicus_DSM_COG_30_N{lat:02d}_00_E{lon:03d}_00_DEM"
        try:
            tiles.append(fetch(f"https://copernicus-dem-90m.s3.amazonaws.com/{tid}/{tid}.tif"))
        except Exception as e:
            print("skip", tid, e)
srcs = [rasterio.open(t) for t in tiles]
mos, tr = merge(srcs, bounds=(20.9, 38.8, 24.4, 40.3))
src_crs = srcs[0].crs
# reproject to EGSA87 at 90 m for slope/aspect
dst_tr, w, h = calculate_default_transform(src_crs, f"EPSG:{CRS_GR}", mos.shape[2], mos.shape[1], 20.9, 38.8, 24.4, 40.3, resolution=90)
dem = np.full((h, w), np.nan, "float32")
reproject(mos[0].astype("float32"), dem, src_transform=tr, src_crs=src_crs, dst_transform=dst_tr, dst_crs=f"EPSG:{CRS_GR}", resampling=Resampling.bilinear, src_nodata=-32767, dst_nodata=np.nan)
dem[dem < -100] = np.nan
gy, gx = np.gradient(dem, 90, 90)          # rows go north->south
slope = np.degrees(np.arctan(np.hypot(gx, gy)))
aspect = (np.degrees(np.arctan2(-gx, gy)) + 360) % 360   # 0 = north, 180 = south (downslope direction)
south = ((aspect >= 135) & (aspect <= 225) & (slope >= 2)).astype("float32"); south[np.isnan(dem)] = np.nan
flat = (slope < 5).astype("float32"); flat[np.isnan(dem)] = np.nan
prof = dict(driver="GTiff", height=h, width=w, count=1, dtype="float32", crs=f"EPSG:{CRS_GR}", transform=dst_tr, nodata=np.nan, compress="deflate")
for name, arr in [("dem", dem), ("slope", slope), ("south", south), ("flat", flat)]:
    with rasterio.open(CACHE / f"{name}_90m.tif", "w", **prof) as d: d.write(arr, 1)

g = gpd.read_parquet(DATA / "grid.parquet").to_crs(CRS_GR)
out = pd.DataFrame({"h3": g.h3})
st = exact_extract(str(CACHE / "dem_90m.tif"), g, ["mean", "min", "max"], output="pandas")
out["elev_mean_m"], out["elev_min_m"], out["elev_max_m"] = st["mean"], st["min"], st["max"]
out["slope_mean_deg"] = exact_extract(str(CACHE / "slope_90m.tif"), g, ["mean"], output="pandas")["mean"]
out["slope_lt5_share"] = exact_extract(str(CACHE / "flat_90m.tif"), g, ["mean"], output="pandas")["mean"]
out["south_facing_share"] = exact_extract(str(CACHE / "south_90m.tif"), g, ["mean"], output="pandas")["mean"]
out.to_parquet(DATA / "l_dem.parquet")
w_ = g.cell_km2 * g.in_region
print(out.describe().T[["mean", "min", "max"]])
print("share of area with mean elev > 1000 m:", round((w_[out.elev_mean_m > 1000].sum() / w_.sum()) * 100, 1), "%  (day10 says ~1/6)")
