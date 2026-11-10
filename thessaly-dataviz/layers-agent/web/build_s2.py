"""'Today' layer: Sentinel-2 L2A (Copernicus, via Element84 Earth Search on AWS, CC BY-SA 3.0 IGO / Copernicus licence),
one clear date over Thessaly. Outputs: true-colour texture, a water mask (NDWI > 0.1) texture, and per-hex water share."""
import json, sys, numpy as np, rasterio, urllib.request
from rasterio.warp import reproject, Resampling
from rasterio.transform import from_bounds
from PIL import Image
import pathlib
R = pathlib.Path(__file__).resolve().parents[1]; OUT = R / "web" / "assets"
DATE = sys.argv[1] if len(sys.argv) > 1 else "2026-10-19"
W0, S0, E0, N0, TW, TH = 20.9, 38.8, 24.4, 40.3, 2800, 1200
tr = from_bounds(W0, S0, E0, N0, TW, TH)
q = {"collections": ["sentinel-2-l2a"], "bbox": [21.0, 38.9, 24.3, 40.2], "datetime": f"{DATE}T00:00:00Z/{DATE}T23:59:59Z", "limit": 50}
req = urllib.request.Request("https://earth-search.aws.element84.com/v1/search", data=json.dumps(q).encode(), headers={"Content-Type": "application/json"})
items = json.load(urllib.request.urlopen(req, timeout=60))["features"]
items = sorted(items, key=lambda f: f["properties"]["eo:cloud_cover"])
print(len(items), [(f["id"], f["properties"]["eo:cloud_cover"]) for f in items])
rgb = np.zeros((3, TH, TW), "float32"); green = np.full((TH, TW), np.nan, "float32"); nir = np.full((TH, TW), np.nan, "float32"); scl = np.zeros((TH, TW), "uint8")
def warp(href, out, band=1, rs=Resampling.average, ov=2, nodata=0):
    with rasterio.Env(GDAL_DISABLE_READDIR_ON_OPEN="EMPTY_DIR", AWS_NO_SIGN_REQUEST="YES"):
        with rasterio.open(href, overview_level=ov) as s:
            tmp = np.full(out.shape, np.nan, "float32")
            reproject(rasterio.band(s, band), tmp, dst_transform=tr, dst_crs="EPSG:4326", resampling=rs, src_nodata=nodata, dst_nodata=np.nan)
    return tmp
for f in items:
    a = f["assets"]; seen = ~np.isnan(green)
    vis = [warp(a["visual"]["href"], rgb[0], b) for b in (1, 2, 3)]
    g = warp(a["green"]["href"], green, ov=2); n = warp(a["nir"]["href"], nir, ov=2)
    m = ~np.isnan(g) & ~seen
    for k in range(3): rgb[k][m] = vis[k][m]
    green[m] = g[m]; nir[m] = n[m]
    print(f["id"], "new px", int(m.sum()))
ndwi = (green - nir) / (green + nir + 1e-6)
water = (ndwi > 0.1) & ~np.isnan(ndwi)
# keep inland water only: drop the sea using the DEM mosaic (sea = elevation <= 0.5 m)
dem = np.full((TH, TW), np.nan, "float32")
with rasterio.open(R / "cache" / "dem_mosaic_wgs84.tif") as s_:
    reproject(rasterio.band(s_, 1), dem, dst_transform=tr, dst_crs="EPSG:4326", resampling=Resampling.bilinear, dst_nodata=np.nan)
land = ~np.isnan(dem) & (dem > 0.5)
from scipy import ndimage
land = ndimage.binary_erosion(land, iterations=2)          # trim coastal mixed pixels
water &= land
# true colour, gentle stretch, slightly darkened to sit in the night theme
img = np.nan_to_num(rgb, nan=0)
img = np.clip((img / 255.0) ** 0.9 * 255 * 1.15, 0, 255).astype("uint8").transpose(1, 2, 0)
Image.fromarray(img, "RGB").save(OUT / "s2_today.jpg", quality=86)
o = np.zeros((TH, TW, 4), "uint8"); o[water] = (90, 200, 255, 230)
Image.fromarray(o, "RGBA").save(OUT / "s2_water.png", optimize=True)
# per-hex water share (texture pixels → H3)
import h3
cells = json.loads((R / "web/data.json").read_text())["h3"]; cidx = {c: i for i, c in enumerate(cells)}
lat = N0 - (np.arange(TH) + .5) * (N0 - S0) / TH; lon = W0 + (np.arange(TW) + .5) * (E0 - W0) / TW
pix = np.full((TH, TW), -1, np.int32)
for r in range(TH):
    for c in range(TW): pix[r, c] = cidx.get(h3.latlng_to_cell(lat[r], lon[c], 8), -1)
ok = (pix >= 0) & ~np.isnan(ndwi)
den = np.bincount(pix[ok], minlength=len(cells)); num = np.bincount(pix[ok & water], minlength=len(cells))
share = np.where(den > 0, num / np.maximum(den, 1), 0)
pxkm2 = ((E0 - W0) / TW * 111.32 * np.cos(np.radians(lat)))[:, None] * ((N0 - S0) / TH * 110.54)
json.dump({"date": DATE, "source": "Copernicus Sentinel-2 L2A (ESA), via Earth Search AWS", "scenes": [f["id"] for f in items],
           "ndwi_threshold": 0.1, "idx": np.nonzero(share > 0.05)[0].tolist(), "share": (share[share > 0.05] * 100).round().astype(int).tolist(),
           "water_km2_in_thessaly": round(float((water * pxkm2)[pix >= 0].sum()))}, open(OUT / "s2_water.json", "w"), separators=(",", ":"))
# Karla check: water area within the Karla box
kb = (lat[:, None] > 39.38) & (lat[:, None] < 39.62) & (lon[None, :] > 22.7) & (lon[None, :] < 22.95)
print("water in Thessaly km2", round(float((water * pxkm2)[pix >= 0].sum())), "Karla box water km2", round(float((water * pxkm2)[kb].sum()), 1))
