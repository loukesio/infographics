# Day 14 · A Borgesian map — The map of Larissa is still half in tatters

**Idea**
Borges' map that "coincided point for point" with the empire, applied to Larissa: every building footprint in OSM in an
8 × 7 km frame, in black ink. Where OSM marks residential land but no building has been traced, 100 m squares are
shaded — the parts of the map still in tatters.

**Data**
OpenStreetMap, Geofabrik Greece extract 2026-10-28, © OpenStreetMap contributors, ODbL —
https://download.geofabrik.de/europe/greece.html (building = *, landuse = residential, streets and river for context).
Quote: Jorge Luis Borges, "Del rigor en la ciencia" (1946), English tr. Andrew Hurley, Collected Fictions (1998).

**How**
- Buildings and residential polygons clipped to the frame; 100 m grid; a cell is "tatter" if its centre is in
  residential land use and it touches no building polygon.
- Title in Cormorant Garamond (vintage), quote via a registered font alias (gridtext cannot read spaced family names).

**Finding**
- 8,321 building footprints, 2.13 km² of roofs (3.8% of the 56 km² frame).
- 596 of 1,204 residential 100 m cells (49.5%) have no mapped building.

**Caveats**
- Blank = not traced yet, not empty. Residential land use itself is incompletely mapped, so the real gap is larger.
- Quote wording is from the Hurley translation as I know it; check it against the book before posting.

**Status**
needs Loukas: check the quote wording against Hurley's translation.
