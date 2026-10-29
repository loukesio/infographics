# Day 07 · A 10 minute map — Fewer than a third of Larissa's streets keep to the compass

**Idea**
Every street within 3 km of Larissa's centre, cut into straight pieces and coloured by how far it turns from the compass:
blue = runs N–S or E–W (±10°), rust = turned to the diagonal (NE–SW / NW–SE ±15°), grey = in between. A street
orientation rose (after Geoff Boeing's OSMnx city roses) shows length per 5° of compass.

**Data**
OpenStreetMap, Geofabrik Greece extract 2026-10-28, © OpenStreetMap contributors, ODbL —
https://download.geofabrik.de/europe/greece.html. Highway = motorway … residential, living_street, pedestrian
(no service roads, tracks, footways). Centre point from `m30_towns`.

**How**
- Lines clipped to a 3 km circle, split into vertex-to-vertex segments, bearing folded to 0–180° and weighted by length.
- Turn from compass = min(bearing mod 90, 90 − bearing mod 90).
- ggplot2 + coord_polar for the rose, patchwork insets.

**Finding**
- 449 km of street. Dominant bearings 178° and 88° (a compass-true grid).
- 30.7% of length within 10° of N–S/E–W (random would be 22%), 43.4% in between, 25.9% within 15° of a diagonal.

**Caveats**
- Bearings in EGSA87 grid; grid vs true north differ by < 1° here.
- Curved streets are split into many short pieces; each counts by its length.

**Status**
done
