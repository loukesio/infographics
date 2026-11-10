"""JRC EU Crop Map 2022 (10 m, CC BY 4.0) → crop-group shares per H3 cell → data/crops_h3.parquet.
Read at 20 m (nearest) through a window of the EU COG; aggregated by rasterising the H3 cells onto the same grid."""
import pathlib, numpy as np, pandas as pd, geopandas as gpd, rasterio
from rasterio.warp import transform_bounds
from rasterio.windows import from_bounds
from rasterio.transform import Affine
from rasterio.features import rasterize
R = pathlib.Path(__file__).resolve().parents[1]
U = "/vsicurl/https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/EUCROPMAP/2022/EU_CropMap_22_v1_stratum_EU27-HR.tif"
cells = gpd.read_parquet(R / "data/thessaly_h3.parquet")[["h3", "geometry"]]
GROUPS = {"wheat": [211, 212], "barley_oats": [213, 214, 215, 218, 219], "maize": [216], "rice": [217],
          "industrial": [230, 222, 223, 221], "sunflower": [231, 232, 233], "pulses": [240], "fodder": [250], "bare_arable": [290]}
F = 2  # 20 m
with rasterio.Env(CPL_VSIL_CURL_ALLOWED_EXTENSIONS=".tif", GDAL_HTTP_MAX_RETRY="5", GDAL_HTTP_RETRY_DELAY="3", VSI_CACHE="TRUE"):
    s = rasterio.open(U)
    c3035 = cells.to_crs(s.crs); b = c3035.total_bounds
    w = from_bounds(*b, s.transform).round_offsets().round_lengths()
    H, W = int(w.height // F), int(w.width // F)
    a = s.read(1, window=w, out_shape=(H, W), resampling=rasterio.enums.Resampling.nearest)
    T = s.window_transform(w) * Affine.scale(w.width / W, w.height / H)
print("read", a.shape, np.unique(a)[:30])
CID = rasterize(((g, i + 1) for i, g in enumerate(c3035.geometry.values)), out_shape=a.shape, transform=T, dtype="int32")
n = np.bincount(CID.ravel(), minlength=len(cells) + 1)[1:]
out = pd.DataFrame({"h3": cells.h3})
for k, codes in GROUPS.items():
    m = np.isin(a, codes)
    out[f"crop_{k}_share"] = (np.bincount(CID[m], minlength=len(cells) + 1)[1:] / np.maximum(n, 1)).round(3)
arable = np.isin(a, sum(GROUPS.values(), []))
out["arable_share"] = (np.bincount(CID[arable], minlength=len(cells) + 1)[1:] / np.maximum(n, 1)).round(3)
out.to_parquet(R / "data/crops_h3.parquet")
A = cells.to_crs(2100).area.values / 1e6
print({c: round(float((out[c] * A).sum())) for c in out.columns if c != "h3"})
