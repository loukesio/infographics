"""Routable road network for Thessaly from Overture (OSM-derived): segments with their connectors (topology) and bridge/tunnel flags.
-> cache/region_network.parquet (id, class, wkb, connectors [id, at], bridge = list of [from, to] fractions flagged is_bridge or is_tunnel)."""
import pathlib
from overture import con, path, BB
R = pathlib.Path(__file__).resolve().parents[1]
c = con(); c.sql("SET geometry_always_xy = true")
CLS = "('motorway','trunk','primary','secondary','tertiary','residential','unclassified','living_street','unknown','service','track')"
c.sql(f"""COPY (SELECT id, class, ST_AsWKB(geometry) wkb,
    list_transform(connectors, lambda x: struct_pack(cid := x.connector_id, at := x.at)) AS conn,
    list_transform(list_filter(coalesce(road_flags, []), lambda f: list_contains(f.values, 'is_bridge') OR list_contains(f.values, 'is_tunnel')),
                   lambda f: coalesce(f.between, [0.0, 1.0])) AS bridge
  FROM read_parquet('{path("transportation","segment")}', hive_partitioning=1)
  WHERE {BB} AND subtype = 'road' AND class IN {CLS}) TO '{R}/cache/region_network.parquet' (FORMAT parquet)""")
print(c.sql(f"SELECT count(*), sum(len(bridge) > 0) FROM '{R}/cache/region_network.parquet'").fetchall())
