# Day 13 · Interactions — Half of Thessaly's people live on 0.6 % of its land

**Idea**
An interactive Leaflet map of Thessaly with five layers you can switch on and off: people (Kontur hexagons),
municipalities, OSM rivers, GBIF threatened-species records and the nine towns. Every shape has a popup with its
numbers. A framed screenshot of the live map is the social-media image; the title is a number computed from the data.

**Data**
- Kontur Population Greece 2023-11-01, 400 m H3 cells, CC BY 4.0 — https://data.humdata.org/dataset/kontur-population-greece
  (`data/kontur/kontur_population_GR_20231101.gpkg`).
- OpenStreetMap `waterway=river`, Geofabrik Greece extract 2026-10-28 — https://download.geofabrik.de/europe/greece.html — ODbL.
- GBIF occurrences of IUCN CR/EN/VU species in Thessaly, fetched 2026-10-10 (`data/gbif_thessaly_threatened.csv`,
  from `scripts/00_fetch_gbif_thessaly.R`, https://api.gbif.org/v1/occurrence/search) — CC0/CC BY per dataset.
- GADM 4.1 municipalities (25), Eurostat GISCO NUTS 2021 border. Base tiles: Esri World Gray Canvas / World Shaded
  Relief (free with attribution, no key).

**How**
- Kontur cells whose centre lies in Thessaly; cells summed to H3 resolution 6 (~36 km²) with `h3jsr` for the map;
  population per municipality by cell centroids.
- Finding: densest 400 m cells sorted and summed until they hold 50 % of the people; their area / region area.
- `leaflet` + `htmlwidgets::saveWidget(selfcontained = TRUE)` → `out/day13_interactions.html` (1.6 MB).
- Screenshot with `webshot2` (headless Chrome), framed with `m30_labs()` in ggplot2 (`annotation_raster`).

**Finding**
- 689,172 people (Kontur) on 14,053 km²; half of them live in 95 cells = 80 km² = **0.6 %** of the land.
- Layer counts: 417 populated hexagons, 25 municipalities, 1,410 km of OSM rivers (697 segments),
  1,563 GBIF records of 106 threatened species (fine coordinates only), 9 towns.

**Caveats**
- Kontur is a modelled grid (GHSL + buildings), not the census; the 0.6 % depends on the 400 m cell size
  (bigger cells would give a bigger share).
- OSM `river` includes some seasonal streams. GBIF shows where people looked, not only where species live;
  records with > 10 km uncertainty and the EBCC bird atlas are dropped (as in t13).
- CARTO tiles showed "API key required" when the HTML is opened from disk, so Esri tiles are used. The HTML needs
  internet for the base tiles; all data layers are inside the file.

**Status**
done
