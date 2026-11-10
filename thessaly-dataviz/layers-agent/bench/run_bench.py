"""Benchmark.
import os; os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
A) Can the H3 grid + tools reproduce the published 30-day-map findings (computed independently in R, on rasters)?
B) Combination questions: tool answer vs. an independent 90 m raster/polygon computation (measures grid aggregation error)."""
import sys, pathlib, json, numpy as np, rasterio, geopandas as gpd
from rasterio.features import rasterize
ROOT = pathlib.Path(__file__).resolve().parents[1]; sys.path.insert(0, str(ROOT / "agent"))
import tools as T
res = []
def rec(part, q, tool_val, ref, tol_pct, note=""):
    err = abs(tool_val - ref) / abs(ref) * 100 if ref else abs(tool_val)
    res.append(dict(part=part, question=q, tool=round(tool_val, 2), reference=round(ref, 2), err_pct=round(err, 1), tol_pct=tol_pct, ok=err <= tol_pct, note=note))

def pct(where): return T.area_stats(where)["rows"][0]["pct_of_thessaly"]
def km2(col, where=""): return T.zonal_stats([col], where)["rows"][0][f"{col}_km2"]
mainland = "regional_unit <> 'Magnisia, Sporades' OR lon < 23.3"   # crude Sporades exclusion (day 06/29 use mainland)
tot_main = T.area_stats(mainland)["rows"][0]["area_km2"]
# ---- A
rec("A", "Share of Thessaly above 1,000 m (day 10: 'a sixth'; day 06 bands: 16.5%)", pct("elev_mean_m >= 1000"), 16.5, 10, "cell mean elevation vs pixel bands")
rec("A", "Plain (<200 m) area, km2 (day 29: 5,063)", T.area_stats(f"elev_mean_m < 200 AND ({mainland})")["rows"][0]["area_km2"], 5063, 5)
z = T.zonal_stats(["lc_crop_share"], f"elev_mean_m < 200 AND ({mainland})")["rows"][0]
rec("A", "Cropland share of the plain, % (day 29: 58.1)", z["lc_crop_share_wmean"] * 100, 58.1, 5)
z = T.zonal_stats(["lc_tree_share", "lc_crop_share"])["rows"][0]
rec("A", "Tree cover share, % (day 25: 'half')", z["lc_tree_share_wmean"] * 100, 50, 10)
rec("A", "Population with zero residents, % of area (day 18: 36)", pct("population = 0"), 36, 5)
rec("A", "Daniel flooded area in Thessaly, km2 (day 26: 926)", km2("daniel_flood_share"), 926, 5)
rec("A", "Hypothetical Tempe lake, km2 (day 15: 2,880)", km2("tempe_lake_share"), 2880, 5)
rec("A", "Solar parks, km2 (day 12: 22)", T.zonal_stats(["solar_km2"])["rows"][0]["solar_km2_sum"], 22, 15, "different OSM tag selection")
z = T.zonal_stats(["road_km_major", "road_km_minor", "road_km_track"])["rows"][0]
rec("A", "Road km major+minor+track (day 24: 42,400)", z["road_km_major_sum"] + z["road_km_minor_sum"] + z["road_km_track_sum"], 42400, 15, "class sets differ")

# ---- B: independent 90 m raster truth
with rasterio.open(ROOT / "cache" / "dem_90m.tif") as r:
    dem = r.read(1); tr = r.transform; crs = r.crs
px = 90 * 90 / 1e6
reg = gpd.read_file(ROOT / "data" / "border_el61.geojson").to_crs(crs)
inreg = rasterize([(g, 1) for g in reg.geometry], out_shape=dem.shape, transform=tr, fill=0).astype(bool)
fl = gpd.read_file(ROOT / "data" / "daniel_flood_union.geojson").to_crs(crs)
flood = rasterize([(g, 1) for g in fl.geometry], out_shape=dem.shape, transform=tr, fill=0, all_touched=False).astype(bool)
with rasterio.open(ROOT / "cache" / "lake_share_90m.tif") as r: lake = r.read(1) == 1
with rasterio.open(ROOT / "cache" / "slope_90m.tif") as r: slope = r.read(1)
import json as _j, pandas as pd
nat = pd.concat([gpd.read_file(ROOT / "cache" / f"natura_{i}.geojson") for i in (0, 1)]).to_crs(crs)
natr = rasterize([(g, 1) for g in nat.geometry], out_shape=dem.shape, transform=tr, fill=0).astype(bool)
sol = gpd.read_file(ROOT / "data" / "solar_plants.geojson").to_crs(crs).clip(reg)   # file covers the whole bbox

t = (flood & inreg & (dem < 100)).sum() * px
v = km2("daniel_flood_share", "elev_mean_m < 100")
rec("B", "Daniel-flooded land below 100 m, km2", v, t, 15, "tool thresholds on cell mean elevation; truth on 90 m pixels")
t = (flood & lake & inreg).sum() * px; tl = (lake & inreg).sum() * px
v = km2("daniel_flood_share", "tempe_lake_share > 0.5")
rec("B", "Daniel-flooded land inside the hypothetical Tempe lake, km2", v, t, 15)
t = (inreg & ~natr & (slope < 5) & ~flood).sum() * px
v = T.zonal_stats(["slope_lt5_share"], "natura_any_share < 0.5 AND daniel_flood_share < 0.5")["rows"][0]["slope_lt5_share_km2"]
rec("B", "Flat (<5 deg) land outside Natura and outside Daniel flood, km2", v, t, 15, "PV screening core")
inter = gpd.overlay(sol, nat[["geometry"]], how="intersection")
t = inter.geometry.area.sum() / 1e6
v = T.zonal_stats(["solar_km2"], "natura_any_share > 0.5")["rows"][0]["solar_km2_sum"]
rec("B", "Solar-park area inside Natura 2000, km2", v, t, 30, "small numbers: grid error large")
df = pd.DataFrame(res); print(df.to_string(index=False))
df.to_csv(ROOT / "bench" / "results.csv", index=False)
print(f"\nPASS {df.ok.sum()}/{len(df)}")
