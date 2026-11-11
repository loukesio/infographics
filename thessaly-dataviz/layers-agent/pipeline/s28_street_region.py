"""Region-level flood-zone raster for the street map at low zoom → web/assets/st/zones.png (same palette as the tiles);
also inlines the per-settlement road km (data/roads_summary.json, from s25) into web/index.html."""
import os, re, json, pathlib, numpy as np, geopandas as gpd
from rasterio.features import rasterize
from rasterio.transform import from_bounds
from PIL import Image
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3; TW, TH = 4200, 1800; T = from_bounds(W0, S0, E0, N0, TW, TH)
M = np.zeros((TH, TW), "uint8")
for bit, p in ((1, RAW / "official/el08_friv_0100_rev1.json"), (2, RAW / "official/el08_friv_1000_rev1.json"), (4, R / "data/daniel_flood_union.geojson")):
    g = gpd.read_file(p).to_crs(4326).geometry; M |= (bit * rasterize([(x, 1) for x in g if x is not None and not x.is_empty], out_shape=(TH, TW), transform=T, dtype="uint8")).astype("uint8")
PAL = np.zeros((8, 4), "uint8"); PAL[1] = PAL[3] = (150, 100, 235, 120); PAL[2] = (190, 170, 235, 80); PAL[4] = PAL[5] = (240, 96, 80, 135); PAL[6] = PAL[7] = (79, 163, 224, 130)
Image.fromarray(PAL[M], "RGBA").save(R / "web/assets/st/zones.png", optimize=True); print("zones.png", os.path.getsize(R / "web/assets/st/zones.png") // 1000, "kB")
km = {k: v["km"] for k, v in json.load(open(R / "data/roads_summary.json")).items()}
h = R / "web/index.html"; s = h.read_text(); s2 = re.sub(r"/\*RKM\*/.*?/\*RKM\*/", lambda m: "/*RKM*/" + json.dumps(km, separators=(",", ":")) + "/*RKM*/", s, count=1); assert s2 != s or "/*RKM*/{" in s
h.write_text(s2); print("RKM inlined", len(km))
