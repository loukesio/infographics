"""Overture roads (transportation/segment) and points of interest (places) for the 4 cities + 20 settlements → cache/place_roads.parquet, cache/place_pois.parquet."""
import json, pathlib
from overture import con, path
R = pathlib.Path(__file__).resolve().parents[1]
AREAS = {"larisa": (22.355, 39.595, 22.475, 39.675), "volos": (22.895, 39.335, 22.995, 39.405), "trikala": (21.725, 39.525, 21.805, 39.585), "karditsa": (21.885, 39.34, 21.955, 39.39)}
AREAS.update({k: tuple(v[1:]) for k, v in json.load(open(R / "data/places.json")).items()})
if __name__ == "__main__":
    c = con(); c.sql("SET geometry_always_xy = true")
    w = " OR ".join(f"(bbox.xmax > {a} AND bbox.xmin < {cc} AND bbox.ymax > {b} AND bbox.ymin < {d})" for a, b, cc, d in AREAS.values())
    env = "bbox.xmin > 21.4 AND bbox.xmax < 23.1 AND bbox.ymin > 39.2 AND bbox.ymax < 40.1"
    c.sql(f"""COPY (SELECT id, class, subtype, names.primary AS name, ST_AsWKB(geometry) wkb FROM read_parquet('{path("transportation","segment")}', hive_partitioning=1)
      WHERE {env} AND subtype = 'road' AND ({w})) TO '{R}/cache/place_roads.parquet' (FORMAT parquet)""")
    print(c.sql(f"SELECT class, count(*) FROM '{R}/cache/place_roads.parquet' GROUP BY ALL ORDER BY 2 DESC").fetchall(), flush=True)
    c.sql(f"""COPY (SELECT id, names.primary AS name, taxonomy.primary AS cat, basic_category bc, confidence, ST_X(geometry) lon, ST_Y(geometry) lat FROM read_parquet('{path("places","place")}', hive_partitioning=1)
      WHERE {env} AND ({w})) TO '{R}/cache/place_pois.parquet' (FORMAT parquet)""")
    print(c.sql(f"SELECT bc, count(*) FROM '{R}/cache/place_pois.parquet' GROUP BY ALL ORDER BY 2 DESC LIMIT 60").fetchall())
