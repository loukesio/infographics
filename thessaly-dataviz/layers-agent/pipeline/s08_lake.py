"""Step 8: 'Close the Vale of Tempe' scenario (day 15): DEM cells below the spill level 121.6 m that are connected to
Larissa once the gorge is plugged. Share of each H3 cell inside that hypothetical lake + its depth."""
import numpy as np, rasterio, geopandas as gpd, pandas as pd
from scipy import ndimage
from pyproj import Transformer
from exactextract import exact_extract
from common import CACHE, DATA, CRS_GR
SPILL = 121.6
with rasterio.open(CACHE / "dem_90m.tif") as r:
    dem = r.read(1); prof = r.profile; T = r.transform
tf = Transformer.from_crs(4326, CRS_GR, always_xy=True)
# plug: Tempe gorge box (22.545-22.72 E along the Pineios, 39.84-39.93 N) raised to 5,000 m
x0, y0 = tf.transform(22.545, 39.84); x1, y1 = tf.transform(22.72, 39.93)
c0, r1 = ~T * (x0, y0); c1, r0 = ~T * (x1, y1)
d = dem.copy(); d[int(r0):int(r1)+1, int(c0):int(c1)+1] = 5000
below = (d < SPILL) & ~np.isnan(d)
lab, _ = ndimage.label(below)
lx, ly = tf.transform(22.4194, 39.6390)          # Larissa centre
cl, rl = ~T * (lx, ly); L = lab[int(rl), int(cl)]
lake = (lab == L) & (L > 0)
depth = np.where(lake, SPILL - dem, np.nan).astype("float32")
share = lake.astype("float32"); share[np.isnan(dem)] = np.nan
prof.update(dtype="float32", nodata=np.nan)
for n, a in [("lake_share", share), ("lake_depth", depth)]:
    with rasterio.open(CACHE / f"{n}_90m.tif", "w", **prof) as o: o.write(a, 1)
print(f"lake area {lake.sum()*90*90/1e6:,.0f} km2 (day15: 2,880 km2)")
g = gpd.read_parquet(DATA / "grid.parquet").to_crs(CRS_GR)
out = pd.DataFrame({"h3": g.h3})
out["tempe_lake_share"] = exact_extract(str(CACHE / "lake_share_90m.tif"), g, ["mean"], output="pandas")["mean"]
out["tempe_lake_depth_m"] = exact_extract(str(CACHE / "lake_depth_90m.tif"), g, ["mean"], output="pandas")["mean"]
out.to_parquet(DATA / "l_lake.parquet")
