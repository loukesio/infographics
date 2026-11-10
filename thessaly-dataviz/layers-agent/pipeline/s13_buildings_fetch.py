"""Overture buildings in the Thessaly bbox → cache/buildings.parquet (centroid + footprint area)."""
import pathlib
from overture import con, path, BB
R = pathlib.Path(__file__).resolve().parents[1]; (R / "cache").mkdir(exist_ok=True)
c = con(); c.sql("SET geometry_always_xy = true")
c.sql(f"""COPY (SELECT id, class, height, ST_X(ST_Centroid(geometry)) lon, ST_Y(ST_Centroid(geometry)) lat,
  ST_Area_Spheroid(geometry) area_m2 FROM read_parquet('{path("buildings","building")}', hive_partitioning=1)
  WHERE {BB}) TO '{R}/cache/buildings.parquet' (FORMAT parquet)""")
print(c.sql(f"SELECT count(*), sum(area_m2)/1e6 FROM '{R}/cache/buildings.parquet'").fetchall())
