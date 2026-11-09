"""Assets for demo v2: terrarium heightmap, textures (base, land cover, overlays), vector overlays with z, Daniel timeline per H3 cell."""
import json, glob, zipfile, pathlib, numpy as np, pandas as pd, geopandas as gpd, rasterio, shapely
from rasterio.warp import reproject, Resampling
from rasterio.features import rasterize
from rasterio.transform import from_bounds
from PIL import Image
R = pathlib.Path(__file__).resolve().parents[1]; C = R / "cache"; OUT = R / "web" / "assets"; OUT.mkdir(exist_ok=True)
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3
HW, HH = 1401, 601            # heightmap grid
TW, TH = 2800, 1200           # texture grid
def grid(w, h): return from_bounds(W0, S0, E0, N0, w, h)
def warp(src_path, w, h, rs=Resampling.bilinear, nodata=np.nan, dtype="float32"):
    with rasterio.open(src_path) as s:
        a = np.full((h, w), nodata, dtype)
        reproject(rasterio.band(s, 1), a, dst_transform=grid(w, h), dst_crs="EPSG:4326", resampling=rs, dst_nodata=nodata)
    return a
reg = gpd.read_file(R / "data/border_el61.geojson")
greece_mask_src = None

# ---- heightmap (terrarium) ----
dem = warp(C / "dem_90m.tif", HW, HH)
dem = np.where(np.isnan(dem), -40, np.maximum(dem, -40))
v = dem + 32768.0
rgb = np.dstack([np.floor(v / 256), np.floor(v % 256), np.floor((v - np.floor(v)) * 256)]).astype("uint8")
Image.fromarray(rgb, "RGB").save(OUT / "dem.png", optimize=True)

# ---- base texture: night hillshade ----
demT = warp(C / "dem_90m.tif", TW, TH); land = ~np.isnan(demT); d = np.nan_to_num(demT, nan=0)
lat = np.linspace(N0, S0, TH)[:, None]; dx = (E0 - W0) / TW * 111320 * np.cos(np.radians(lat)); dy = (N0 - S0) / TH * 110540
gy, gx = np.gradient(d); gx = gx / dx; gy = -gy / dy
def shade(az, alt):
    az, alt = np.radians(az), np.radians(alt); slope = np.arctan(np.hypot(gx, gy)); aspect = np.arctan2(-gx, gy)
    return np.clip(np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect), 0, 1)
hs = 0.55 * shade(315, 40) + 0.25 * shade(225, 45) + 0.2 * shade(0, 60)
inreg = rasterize([(g, 1) for g in reg.geometry], out_shape=(TH, TW), transform=grid(TW, TH)).astype(bool)
elevn = np.clip(d / 2400, 0, 1) ** 0.6
lo, hi = np.array([20, 34, 52]), np.array([120, 136, 156])
base = lo + (hi - lo) * (0.25 * elevn[..., None] + 0.75 * hs[..., None])
base = np.where(inreg[..., None], base, base * 0.55)        # outside Thessaly darker
sea = np.array([11, 19, 31]); base = np.where(land[..., None], base, sea)
Image.fromarray(base.astype("uint8"), "RGB").save(OUT / "base.jpg", quality=88)
np.save(C / "tex_shade.npy", base.astype("uint8"))

# ---- land cover (WorldCover, decimated nearest) ----
lc = np.zeros((TH, TW), "uint8")
for t in ["N36E021", "N39E021", "N39E024", "N36E024"]:
    f = C / f"ESA_WorldCover_10m_2021_v200_{t}_Map.tif"
    a = warp(f, TW, TH, rs=Resampling.mode, nodata=0, dtype="uint8"); lc = np.where(lc == 0, a, lc)
PAL = {10: (46, 125, 72), 20: (140, 150, 70), 30: (176, 190, 110), 40: (232, 196, 92), 50: (226, 92, 76), 60: (170, 160, 150), 80: (64, 140, 210), 90: (80, 180, 190)}
lcrgba = np.zeros((TH, TW, 4), "uint8")
for k, c in PAL.items(): m = lc == k; lcrgba[m, :3] = c; lcrgba[m, 3] = 255
lcrgba[~land, 3] = 0
Image.fromarray(lcrgba, "RGBA").save(OUT / "ov_landcover.png", optimize=True)

def poly_overlay(geoms, color, name, alpha=150, edge=230):
    m = rasterize([(g, 1) for g in geoms if g is not None and not g.is_empty], out_shape=(TH, TW), transform=grid(TW, TH)).astype(bool)
    er = m & ~np.pad(m, 1, mode="edge")[2:, 1:-1] | m & ~np.pad(m, 1, mode="edge")[:-2, 1:-1] | m & ~np.pad(m, 1, mode="edge")[1:-1, 2:] | m & ~np.pad(m, 1, mode="edge")[1:-1, :-2]
    o = np.zeros((TH, TW, 4), "uint8"); o[m, :3] = color; o[m, 3] = alpha; o[er, 3] = edge
    Image.fromarray(o, "RGBA").save(OUT / f"ov_{name}.png", optimize=True)
nat = pd.concat([gpd.read_file(C / f"natura_{i}.geojson") for i in (0, 1)]).to_crs(4326)
poly_overlay(nat.geometry, (92, 194, 142), "natura", 95, 220)
import os; os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
fl = gpd.read_file(R / "data/daniel_flood_union.geojson").to_crs(4326)
poly_overlay(fl.geometry, (79, 163, 224), "flood", 165, 235)
# lake by depth
lk = warp(C / "lake_depth_90m.tif", TW, TH)
o = np.zeros((TH, TW, 4), "uint8"); m = ~np.isnan(lk) & (lk > 0)
t = np.clip(lk / 60, 0, 1); o[m, 0] = (120 + 90 * t[m]); o[m, 1] = (100 + 60 * t[m]); o[m, 2] = 240; o[m, 3] = (90 + 120 * t[m])
Image.fromarray(o, "RGBA").save(OUT / "ov_lake.png", optimize=True)

# ---- vectors with z (raw metres, sampled from heightmap grid) ----
Hgt = dem
def z_at(lon, lat):
    c = np.clip(((np.asarray(lon) - W0) / (E0 - W0) * (HW - 1)).round().astype(int), 0, HW - 1)
    r = np.clip(((N0 - np.asarray(lat)) / (N0 - S0) * (HH - 1)).round().astype(int), 0, HH - 1)
    return np.maximum(Hgt[r, c], 0)
def lines(geoms, tol):
    out = []
    for g in geoms:
        g = g.simplify(tol)
        for part in (g.geoms if hasattr(g, "geoms") else [g]):
            if part.geom_type != "LineString" or len(part.coords) < 2: continue
            xy = np.array(part.coords)[:, :2]; z = z_at(xy[:, 0], xy[:, 1])
            out.append([[round(x, 4), round(y, 4), int(zz)] for (x, y), zz in zip(xy, z)])
    return out
regw = reg.geometry.iloc[0].buffer(0.05)
rv = pd.read_parquet(C / "ov_rivers.parquet"); rv["geometry"] = shapely.from_wkb(rv.wkb)
rv = gpd.GeoDataFrame(rv, geometry="geometry", crs=4326); rv = rv[rv.intersects(regw)]
main = rv[rv.nm.isin(["Πηνειός", "Ενιπέας", "Τιταρήσιος", "Πάμισος", "Καλέντζης", "Ληθαίος", "Πορταϊκος", "Σοφαδίτης", "Ξεριάς", "Φαρσαλιώτης", "Κουσμπασανιώτης"])]
rivers = lines(main.geometry.clip(regw), 0.0008)
pw = pd.read_parquet(C / "ov_power.parquet"); pw["geometry"] = shapely.from_wkb(pw.wkb)
pw = gpd.GeoDataFrame(pw, geometry="geometry", crs=4326)
pl = lines(pw[pw["class"] == "power_line"].geometry.clip(regw), 0.001)
subs = pw[pw["class"] == "substation"].copy(); subs["geometry"] = subs.geometry.centroid; subs = subs[subs.within(regw)]
sp = [[round(p.x, 4), round(p.y, 4), int(z)] for p, z in zip(subs.geometry, z_at(subs.geometry.x, subs.geometry.y))]
sol = gpd.read_file(R / "data/solar_plants.geojson"); sol["geometry"] = sol.to_crs(2100).centroid.to_crs(4326)
so = [[round(p.x, 4), round(p.y, 4), int(z)] for p, z in zip(sol.geometry, z_at(sol.geometry.x, sol.geometry.y))]
loc = pd.read_parquet(C / "ov_localities.parquet"); loc = loc[loc["class"].isin(["city", "town"])]
loc = gpd.GeoDataFrame(loc, geometry=gpd.points_from_xy(loc.lon, loc.lat), crs=4326)
loc = loc[loc.within(reg.geometry.iloc[0].buffer(0.005))].sort_values("population", ascending=False)
towns = [{"n": r.nm, "p": None if pd.isna(r.population) else int(r.population), "c": r["class"], "x": round(r.lon, 4), "y": round(r.lat, 4), "z": int(z_at(r.lon, r.lat))} for _, r in loc.iterrows()]
# highest DEM point as Olympus label
i = np.nanargmax(Hgt); rr, cc = divmod(i, HW)
peak = {"n": "Όλυμπος", "x": round(W0 + cc / (HW - 1) * (E0 - W0), 4), "y": round(N0 - rr / (HH - 1) * (N0 - S0), 4), "z": int(Hgt[rr, cc])}
vec = {"rivers": rivers, "lines": pl, "subs": sp, "solar": so, "towns": towns, "peak": peak}
(OUT / "vectors.json").write_text(json.dumps(vec, ensure_ascii=False, separators=(",", ":")))
print("towns", len(towns), [t["n"] for t in towns[:12]], "rivers", len(rivers), "lines", len(pl), "subs", len(sp), "solar", len(so), "peak", peak)
