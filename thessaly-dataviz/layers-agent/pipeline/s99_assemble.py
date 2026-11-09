"""Merge all layer tables into one GeoParquet + DuckDB database."""
import glob, pandas as pd, geopandas as gpd, duckdb, os
from common import DATA
g = gpd.read_parquet(DATA / "grid.parquet")
g["area_km2"] = g.cell_km2 * g.in_region
df = g.drop(columns="geometry")
for f in sorted(glob.glob(str(DATA / "l_*.parquet"))):
    df = df.merge(pd.read_parquet(f), on="h3", how="left"); print("+", os.path.basename(f))
gpd.GeoDataFrame(df, geometry=g.geometry, crs=4326).to_parquet(DATA / "thessaly_h3.parquet")
db = DATA / "thessaly_h3.duckdb"
if db.exists(): db.unlink()
con = duckdb.connect(str(db)); con.register("df", df); con.sql("CREATE TABLE cells AS SELECT * FROM df"); con.close()
print(df.shape, f"{os.path.getsize(db)/1e6:.1f} MB")
