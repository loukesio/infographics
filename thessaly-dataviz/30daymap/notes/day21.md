# Day 21 · OpenStreetMap — Volos, in 1,370 km of mapped road

**Idea**
A poster of Volos between Mount Pelion and the Pagasetic Gulf from OpenStreetMap alone: sea, parks and woods, faint
building footprints, and every road with line width by its rank in the hierarchy (motorway in rust). A strip under the
frame splits the mapped road length by class.

**Data**
OpenStreetMap, Geofabrik Greece extract 2026-10-28, © OpenStreetMap contributors, ODbL —
https://download.geofabrik.de/europe/greece.html (highway, natural = coastline, building, leisure = park/garden,
landuse = forest, natural = wood/scrub/water, place nodes for labels).

**How**
- 15 × 13 km frame around 39.372 N, 22.958 E; land/sea by polygonising the OSM coastline with the frame edge
  (a face is land if a road crosses it).
- Road km = length of highway ways clipped to the frame (dual carriageways counted twice, as mapped).
- Place labels at OSM place nodes; only the "Pagasetic Gulf" label is placed by hand.

**Finding**
- 1,372 km of road in the frame: motorway & trunk 11 km, primary & secondary 121, tertiary 91,
  residential & local 689 (50%), service & tracks 460. Plus 108 km of footways/paths (not counted).
- Only 1,538 building footprints are mapped in the frame (Volos buildings are thinly traced in OSM).

**Caveats**
- Road length depends on how mappers split carriageways and link roads; it is "road mapped", not official network length.

**Status**
done
