"""Draped textures for the official layers: ΥΠΕΝ flood zones Q100/Q1000 (EL08), RES-framework exclusions (arch. Zone A, roadless)."""
import os, glob, pathlib, numpy as np, geopandas as gpd
from rasterio.features import rasterize
from rasterio.transform import from_bounds
from PIL import Image
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"; OUT = R / "web/assets"
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3; TW, TH = 2800, 1200
T = from_bounds(W0, S0, E0, N0, TW, TH)
def mask(geoms): return rasterize([(g, 1) for g in geoms if g is not None and not g.is_empty], out_shape=(TH, TW), transform=T).astype(bool)
def edge(m):
    p = np.pad(m, 1, mode="edge"); return m & ~(p[2:, 1:-1] & p[:-2, 1:-1] & p[1:-1, 2:] & p[1:-1, :-2])

# official flood zones: Q1000 light, Q100 strong
q1000 = mask(gpd.read_file(RAW / "official/el08_friv_1000_rev1.json").to_crs(4326).geometry)
q100 = mask(gpd.read_file(RAW / "official/el08_friv_0100_rev1.json").to_crs(4326).geometry)
o = np.zeros((TH, TW, 4), "uint8")
o[q1000] = (122, 92, 214, 110); o[q100] = (92, 52, 196, 190); o[edge(q100), 3] = 240
Image.fromarray(o, "RGBA").save(OUT / "ov_official.png", optimize=True)

# RES-framework exclusions we can map: archaeological Zone A (+1 km viewshed ring), roadless areas
arch = gpd.read_file(RAW / "arch/ZONES_POLYGONS_CHECK.shp", encoding="utf-8")
arch = arch[arch.GEOMETRYNA.str.contains("Ζώνη Α", na=False)].to_crs(2100)
ring = mask(arch.buffer(1000).to_crs(4326).geometry); a = mask(arch.to_crs(4326).geometry)
road = gpd.read_file(glob.glob(str(RAW / "roadless/Roadless_Areas_WGS84/*.kml"))[0]).to_crs(4326)
rl = mask(road.geometry)
o = np.zeros((TH, TW, 4), "uint8")
o[rl] = (196, 120, 60, 120); o[edge(rl), 3] = 230
o[ring & ~a] = (230, 70, 70, 70); o[a] = (210, 40, 40, 220)
Image.fromarray(o, "RGBA").save(OUT / "ov_excl.png", optimize=True)
print("ok", q100.sum(), q1000.sum(), rl.sum(), a.sum())
