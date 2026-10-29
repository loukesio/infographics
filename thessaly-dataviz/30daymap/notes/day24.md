# Day 24 · Network — 42,400 km of road, 53% of it dirt track

**Idea**
Every OSM road of mainland Thessaly drawn as a hierarchy — motorway in red, then ever finer greys down to farm
tracks — with the railway in blue and the dotted route from the village furthest (by road) from any motorway exit.
A bar key gives the kilometres per class.

**Data**
- OpenStreetMap, Geofabrik Greece extract 2026-10-28, © OpenStreetMap contributors, ODbL.
  https://download.geofabrik.de/europe/greece.html (local `30daymap/cache/thessaly_osm.gpkg`, subset in
  `30daymap/cache/day24/roads.rds`): highway=*, railway=rail, railway=station, highway=motorway_junction, place=village.
- Eurostat GISCO NUTS 2021 EL61, mainland.

**How**
- km per class = OSM way length clipped to the region (EGSA87) → `30daymap/data/day24_road_km_by_class.csv`.
- Road graph (igraph): all non-track roads (no service roads, tracks, paths), split at every OSM vertex, joined where
  coordinates coincide; largest connected piece kept (749k nodes).
- Dijkstra from the 93 motorway exits inside the region to all 561 OSM villages (snapped to the nearest node; snap
  distance added) → `30daymap/data/day24_village_exit_km.csv`.
- ggplot2, sf, igraph, patchwork, shadowtext.

**Finding**
**42,368 km of mapped road, 22,414 km (53%) tracks.** Motorway 596 km, main roads 950, secondary 2,035, tertiary 4,356,
local & streets 12,017. Median village: **17 km** by road to a motorway exit; furthest **Αργύρι (Argithea, Karditsa)
96 km**, then Γριμπιανά 90 and Μυρόφυλλο 85; 32 villages are more than 50 km away.

**Caveats**
OSM tagging and track mapping are uneven. Dual carriageways are two OSM ways, so motorway (and some main-road) km
count both directions. Routing ignores one-ways and turn rules; exits just outside the border (A1 in Phthiotis, A2
Egnatia beyond the border) are not counted, so a few southern/north-western villages may be a bit closer in reality.
Only place=village nodes (not hamlets).

**Status**
done
