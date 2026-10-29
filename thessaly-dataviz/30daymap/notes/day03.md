# Day 03 · Polygons — Half of mapped Thessaly is fields

**Idea**
A mosaic of every land-use / land-cover polygon OpenStreetMap volunteers have drawn in mainland Thessaly, in six muted
earthy classes. Ranked bars give each class's share of the mapped area; a callout says how much is not mapped at all.

**Data**
OpenStreetMap, Geofabrik Greece extract 2026-10-28, © OpenStreetMap contributors, ODbL —
https://download.geofabrik.de/europe/greece.html (layer multipolygons in `30daymap/cache/thessaly_osm.gpkg`).
Border: Eurostat GISCO NUTS 2021 (EL61), mainland. Shares saved to `30daymap/data/day03_landuse_shares.csv`.

**How**
- Classes from `landuse` / `natural` tags (list in the script header); bare rock & scree merged into scrub & heath.
- Overlaps resolved on a 25 m grid (terra::rasterize), most specific class wins:
  Built-up > Orchards > Fields > Grass > Scrub > Forest.
- Polygons drawn with geom_sf, a white mask hides parts outside the border; bars as a patchwork inset.

**Finding**
- Mapped land use: 7,404 km² = 53.8% of mainland Thessaly (13,774 km²); 46% has no land-use polygon.
- Of the mapped area: fields 49.9% (3,692 km²), forest 34.0% (2,519), scrub/heath/rock 9.8% (726),
  built-up 5.1% (376), orchards & vineyards 1.1% (79), grass & meadow 0.2% (13).

**Caveats**
- Shares are of what OSM volunteers have drawn, not of the land: mapping effort is uneven (the plain and the Pindus
  forests are well covered, Agrafa and Othrys less). Not comparable to CORINE Land Cover.
- Orchards look small because many orchards are mapped as farmland or not at all.

**Status**
done
