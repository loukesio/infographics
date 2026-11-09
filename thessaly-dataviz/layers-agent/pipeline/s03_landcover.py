"""Step 3: ESA WorldCover 10 m (2021, v200) -> land-cover shares per H3 cell."""
import geopandas as gpd, pandas as pd, numpy as np, rasterio
from shapely.geometry import box
from exactextract import exact_extract
from common import fetch, DATA

CLS = {10: "tree", 20: "shrub", 30: "grass", 40: "crop", 50: "built", 60: "bare", 70: "snow", 80: "water", 90: "wetland", 95: "mangrove", 100: "moss"}
g = gpd.read_parquet(DATA / "grid.parquet")[["h3", "geometry"]]
acc = pd.DataFrame(0.0, index=g.h3, columns=list(CLS.values()))
for t in ["N36E021", "N39E021", "N39E024", "N36E024"]:
    f = fetch(f"https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_{t}_Map.tif")
    with rasterio.open(f) as r: bb = box(*r.bounds)
    sub = g[g.intersects(bb)]
    if sub.empty: continue
    res = exact_extract(str(f), sub, ["unique", "frac", "count"], include_cols=["h3"], output="pandas")
    for h, u, fr, n in zip(res.h3, res.unique, res.frac, res["count"]):
        for c, x in zip(u, fr):
            if int(c) in CLS: acc.at[h, CLS[int(c)]] += x * n
    print(t, len(sub))
tot = acc.sum(axis=1)
sh = acc.div(tot.replace(0, np.nan), axis=0)
sh = sh[["tree", "shrub", "grass", "crop", "built", "bare", "water", "wetland"]].add_prefix("lc_").add_suffix("_share").reset_index()
sh.to_parquet(DATA / "l_landcover.parquet")
gg = gpd.read_parquet(DATA / "grid.parquet").merge(sh, on="h3")
w = gg.cell_km2 * gg.in_region
for c in ["lc_tree_share", "lc_crop_share", "lc_grass_share", "lc_built_share"]:
    print(c, round((gg[c] * w).sum() / w.sum() * 100, 1), "%")
print("(day25 says trees ~half, fields ~quarter)")
