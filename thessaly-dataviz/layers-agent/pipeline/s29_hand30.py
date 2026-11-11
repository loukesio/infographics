import numpy as _np
if not hasattr(_np, "in1d"): _np.in1d = _np.isin
"""Experiment, not used by the page: the 30 m run agrees with Daniel slightly worse than the 90 m model (CSI 0.42 vs 0.46 at best level), so the street map samples the 90 m model.
HAND (height above nearest drainage) at 30 m from Copernicus GLO-30, same method as s10 (channels = catchment >= 40 km²)
→ cache/hand_30m.tif, and calibration against Storm Daniel (EMSR692, inside mapped AOIs) → data/hand30_calibration.json."""
import os, glob, json, numpy as np, rasterio, geopandas as gpd, pandas as pd
from rasterio.warp import reproject, Resampling
from rasterio.features import rasterize
from pysheds.grid import Grid
from common import CACHE, DATA, CRS_GR
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
RES = 30.0; ACC_CELLS = int(40e6 / RES ** 2)
with rasterio.open(CACHE / "dem_90m.tif") as r: b = r.bounds; d90 = r.read(1); t90 = r.transform
W, H = int((b.right - b.left) / RES), int((b.top - b.bottom) / RES); T = rasterio.transform.from_origin(b.left, b.top, RES, RES)
a = np.zeros((H, W), "float32"); sea = np.zeros((H, W), "float32")
with rasterio.open(CACHE / "dem_mosaic_wgs84.tif") as r: reproject(rasterio.band(r, 1), a, dst_transform=T, dst_crs="EPSG:2100", resampling=Resampling.bilinear)
reproject(np.isnan(d90).astype("float32"), sea, src_transform=t90, src_crs="EPSG:2100", dst_transform=T, dst_crs="EPSG:2100", resampling=Resampling.nearest)
a[sea > .5] = -50
prof = dict(driver="GTiff", height=H, width=W, count=1, dtype="float32", crs="EPSG:2100", transform=T, nodata=-9999, compress="deflate", tiled=True)
tmp = CACHE / "dem_30m_2100.tif"
with rasterio.open(tmp, "w", **prof) as o: o.write(a, 1)
print("dem", a.shape, flush=True)
g = Grid.from_raster(str(tmp)); dem = g.read_raster(str(tmp))
pit = g.fill_pits(dem); print("pits", flush=True); flood = g.fill_depressions(pit); print("depr", flush=True); infl = g.resolve_flats(flood); print("flats", flush=True); del pit, flood
fdir = g.flowdir(infl); del infl; acc = g.accumulation(fdir); print("acc", flush=True)
hand = g.compute_hand(fdir, dem, acc >= ACC_CELLS)
h = np.asarray(hand, dtype="float32"); h[a <= -49] = np.nan; h[h < 0] = 0
with rasterio.open(CACHE / "hand_30m.tif", "w", **{**prof, "nodata": np.nan}) as o: o.write(h, 1)
shp = h.shape; px = RES * RES / 1e6
reg = gpd.read_file(DATA / "border_el61.geojson").to_crs(CRS_GR); inreg = rasterize([(x, 1) for x in reg.geometry], out_shape=shp, transform=T).astype(bool)
fl = gpd.read_file(DATA / "daniel_flood_union.geojson").to_crs(CRS_GR); obs0 = rasterize([(x, 1) for x in fl.geometry], out_shape=shp, transform=T).astype(bool)
aoi = pd.concat([gpd.read_file(f).to_crs(CRS_GR) for f in glob.glob(str(CACHE / "emsr692/**/*areaOfInterestA*.shp"), recursive=True)])
M = inreg & ~np.isnan(h) & rasterize([(x, 1) for x in aoi.geometry], out_shape=shp, transform=T).astype(bool); obs = M & obs0; cal = []
for lv in [0.5, 1, 2, 3, 4, 5, 6, 8, 10]:
    sim = M & (h <= lv); hit = (sim & obs).sum(); fa = (sim & ~obs).sum(); miss = (~sim & obs).sum()
    cal.append(dict(level=lv, sim_km2=round(float(sim.sum() * px)), obs_km2=round(float(obs.sum() * px)), hit_rate=round(float(hit / obs.sum()), 3), false_alarm=round(float(fa / max(sim.sum(), 1)), 3), csi=round(float(hit / (hit + fa + miss)), 3)))
print(pd.DataFrame(cal).to_string(index=False)); json.dump(cal, open(DATA / "hand30_calibration.json", "w"), indent=1)
