"""Step 4: Kontur Population (2023-11-01, H3 res 8, GHSL+Facebook+OSM based) and GHSL SMOD degree of urbanisation."""
import gzip, shutil, geopandas as gpd, pandas as pd, h3
from common import fetch, CACHE, DATA, H3_RES

gz = fetch("https://geodata-eu-central-1-kontur-public.s3.amazonaws.com/kontur_datasets/kontur_population_GR_20231101.gpkg.gz")
gp = CACHE / "kontur_GR_20231101.gpkg"
if not gp.exists():
    with gzip.open(gz) as a, open(gp, "wb") as b: shutil.copyfileobj(a, b)
k = gpd.read_file(gp, ignore_geometry=True)
print(k.columns.tolist(), len(k))
k["h3"] = k["h3"].astype(str)
assert h3.get_resolution(k.h3.iloc[0]) == H3_RES, h3.get_resolution(k.h3.iloc[0])
g = pd.read_parquet(DATA / "grid.parquet", columns=["h3", "cell_km2", "in_region"])
p = g.merge(k[["h3", "population"]], on="h3", how="left").fillna({"population": 0})
p["population"] = p.population * 1.0   # Kontur cells are whole; edge cells keep full count
p["pop_density_km2"] = p.population / p.cell_km2
p[["h3", "population", "pop_density_km2"]].to_parquet(DATA / "l_population.parquet")
tot = p.population.sum(); s = p.sort_values("population", ascending=False)
c = s.population.cumsum(); n_half = (c < tot / 2).sum() + 1
area = (s.cell_km2 * s.in_region).iloc[:n_half].sum(); A = (g.cell_km2 * g.in_region).sum()
print(f"total pop {tot:,.0f}; half lives in {n_half} cells = {area:.0f} km2 = {area/A*100:.2f}% of land (day13: 0.6%)")
w = g.cell_km2 * g.in_region
print(f"area with zero residents: {w[p.population.values == 0].sum()/A*100:.1f}% (day18: 36%)")
