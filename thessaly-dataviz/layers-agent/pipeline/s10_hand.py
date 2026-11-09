import numpy as _np
if not hasattr(_np, "in1d"): _np.in1d = _np.isin
"""Step 10: HAND (Height Above Nearest Drainage) from Copernicus GLO-90 (EGSA87, 90 m) with pysheds.
Channels = flow accumulation >= ACC_CELLS (≈ catchment >= 40 km²). Output: cache/hand_90m.tif."""
import numpy as np, rasterio
from pysheds.grid import Grid
from common import CACHE
ACC_CELLS = 5000          # 5000 × 0.0081 km² ≈ 40 km² upstream area
src = CACHE / "dem_90m.tif"; tmp = CACHE / "dem_90m_filled.tif"
with rasterio.open(src) as r:
    a = r.read(1); prof = r.profile
a = np.where(np.isnan(a), -50, a).astype("float32")      # sea / outside → low outlet
prof.update(nodata=-9999)
with rasterio.open(tmp, "w", **prof) as o: o.write(a, 1)
g = Grid.from_raster(str(tmp)); dem = g.read_raster(str(tmp))
pit = g.fill_pits(dem); flood = g.fill_depressions(pit); infl = g.resolve_flats(flood)
fdir = g.flowdir(infl); acc = g.accumulation(fdir)
hand = g.compute_hand(fdir, dem, acc >= ACC_CELLS)
h = np.asarray(hand, dtype="float32"); h[a <= -49] = np.nan; h[h < 0] = 0
with rasterio.open(CACHE / "hand_90m.tif", "w", **{**prof, "nodata": np.nan}) as o: o.write(h, 1)
chan = (np.asarray(acc) >= ACC_CELLS) & (a > -49)
print("channel pixels", int(chan.sum()), "HAND<3m km2", round(float(np.nansum(h < 3) * 0.0081)), "HAND<10m km2", round(float(np.nansum(h < 10) * 0.0081)))
