"""Region-wide Overture extracts for the street-map tiles: roads with names, facilities (places), building footprints.
→ cache/region_roads.parquet, cache/region_pois.parquet, cache/region_buildings.parquet"""
import pathlib, sys
from overture import con, path, BB
R = pathlib.Path(__file__).resolve().parents[1]
c = con(); c.sql("SET geometry_always_xy = true")
CLS = "('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street','pedestrian','unknown','service','track')"
what = sys.argv[1:] or ["roads", "pois", "buildings"]
if "roads" in what:
    c.sql(f"""COPY (SELECT class, names.primary AS name, ST_AsWKB(geometry) wkb FROM read_parquet('{path("transportation","segment")}', hive_partitioning=1)
      WHERE {BB} AND subtype = 'road' AND class IN {CLS}) TO '{R}/cache/region_roads.parquet' (FORMAT parquet)""")
    print("roads", c.sql(f"SELECT count(*) FROM '{R}/cache/region_roads.parquet'").fetchall(), flush=True)
if "pois" in what:
    c.sql(f"""COPY (SELECT names.primary AS name, taxonomy.primary AS cat, confidence, ST_X(geometry) lon, ST_Y(geometry) lat FROM read_parquet('{path("places","place")}', hive_partitioning=1)
      WHERE {BB} AND confidence >= 0.6 AND (taxonomy.primary LIKE '%school%' OR taxonomy.primary LIKE '%hospital%' OR taxonomy.primary IN ('town_hall','fire_station','police_station','retirement_home','nursing')))
      TO '{R}/cache/region_pois.parquet' (FORMAT parquet)""")
    print("pois", c.sql(f"SELECT count(*) FROM '{R}/cache/region_pois.parquet'").fetchall(), flush=True)
if "buildings" in what:
    c.sql(f"""COPY (SELECT ST_AsWKB(geometry) wkb FROM read_parquet('{path("buildings","building")}', hive_partitioning=1)
      WHERE {BB}) TO '{R}/cache/region_buildings.parquet' (FORMAT parquet)""")
    print("buildings", c.sql(f"SELECT count(*) FROM '{R}/cache/region_buildings.parquet'").fetchall(), flush=True)
