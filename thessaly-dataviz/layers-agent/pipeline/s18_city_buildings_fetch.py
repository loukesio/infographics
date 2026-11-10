"""Overture building footprints (with geometry) for the 4 main cities → cache/city_buildings.parquet."""
import pathlib
from overture import con, path
R = pathlib.Path(__file__).resolve().parents[1]
CITIES = {"larisa": (22.355, 39.595, 22.475, 39.675), "volos": (22.895, 39.335, 22.995, 39.405),
          "trikala": (21.725, 39.525, 21.805, 39.585), "karditsa": (21.885, 39.34, 21.955, 39.39)}
if __name__ == "__main__":
    c = con(); c.sql("SET geometry_always_xy = true")
    w = " OR ".join(f"(bbox.xmin > {a} AND bbox.xmax < {cc} AND bbox.ymin > {b} AND bbox.ymax < {d})" for a, b, cc, d in CITIES.values())
    c.sql(f"""COPY (SELECT id, class, height, num_floors, ST_AsWKB(geometry) wkb, bbox.xmin x0, bbox.ymin y0
      FROM read_parquet('{path("buildings","building")}', hive_partitioning=1)
      WHERE bbox.xmin > 21.7 AND bbox.xmax < 23.0 AND bbox.ymin > 39.3 AND bbox.ymax < 39.7 AND ({w})) TO '{R}/cache/city_buildings.parquet' (FORMAT parquet)""")
    print(c.sql(f"SELECT count(*) FROM '{R}/cache/city_buildings.parquet'").fetchall())
