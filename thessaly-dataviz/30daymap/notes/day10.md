# Day 10 · Prompting only — A sixth of Thessaly stands above 1,000 m, a ring of mountains around a flat plain

**Idea**
Thessaly is a lowland bowl walled in by mountains. The plain stays grey on a hillshade, land above 1,000 m is
coloured in one sienna ramp (darker every 500 m), and the highest mapped summit of eight ranges is labelled.
Below the map: those eight summits ranked, and a histogram of how much of the region lies in each 100 m band.

**Data**
- Copernicus GLO-90 DEM (ESA / Airbus, 2021 release), AWS open data — https://registry.opendata.aws/copernicus-dem/ — free licence with attribution.
- OpenStreetMap `natural=peak` and `natural=mountain_range` nodes with their `name`, `name:en` and `ele` tags,
  Geofabrik Greece extract 2026-10-28 — https://download.geofabrik.de/europe/greece.html — © OpenStreetMap contributors, ODbL.
- Region border: Eurostat GISCO NUTS 2021 (EL61) — https://gisco-services.ec.europa.eu/distribution/v2/nuts/ ; GADM 4.1 via `m30_base.R`.

**How**
- Made by prompting only: the code was written and rendered by an AI agent from prompts, with no hand edits. The
  prompts are in `30daymap/data/day10_prompt.txt` (2 prompts).
- The shared `thessaly_osm.gpkg` has no heights (GDAL's default `osmconf.ini` ignores `ele`), so the peak and range
  nodes were re-read from the cached `greece.osm.pbf` with a copy of `osmconf.ini` that keeps `ele` and `natural`
  (`sf::gdal_utils` vectortranslate, cached in `30daymap/cache/day10/peaks.gpkg`; 1,956 of 1,966 peaks have `ele`).
- For each OSM mountain_range node around the plain, I took the highest OSM peak with `ele` within ~10 km and checked it by hand.
  Shares come from the 90 m DEM cells inside the mainland border. Hillshade from `m30_hillshade()`, stretched to its 2–98% range.
- Packages: terra, sf, tidyterra, ggplot2, ggtext, ggnewscale, shadowtext, patchwork.

**Finding**
- 16.4% of mainland Thessaly lies above 1,000 m (39.4% above 500 m); 36.8% lies below 200 m.
- Mytikas (OSM ele 2,917.7 m) stands 2,833 m above Larissa (DEM 85 m at the town centre).
- Labelled summits (OSM node id): Olympus, Mytikas 2,917.7 m (354099249) · Pindus, Brisimi 2,356 m (2799721082) ·
  Agrafa, Karava 2,184 m (26864682) · Ossa 1,977 m (`ele` of the mountain_range node 14320697148) ·
  Othrys, Gerakovouni 1,726 m (26865152) · Pelion, Pourianos Stavros 1,624 m (26864354) ·
  Chasia, Mytikas 1,572 m (7274331195) · Antichasia, Mamali 1,410 m (353186717).

**Caveats**
- Heights are OSM `ele` tags as mapped, not DEM values.
- Ossa has no peak node with a height near its summit, so its 1,977 m is the `ele` of the OSM range node "Όσσα".
- Mytikas lies about 1 km outside the GISCO Thessaly border, on the Pieria side. It is shown because it tops the ring.
  The highest peak inside the border is Skolio, 2,905 m.
- Which range each peak belongs to comes from the nearest OSM range node or the peak's own OSM name, not from an official list.
  Brisimi sits on the Trikala–Arta border in the southern Pindus (Tzoumerka side).
- Mavrovouni (Magnesia) is in OSM as a range node, but the only peak tagged nearby is 400 m, so it is not labelled.
- English labels transliterate the OSM Greek name where `name:en` is missing.

**Status**
done. Loukas could check whether he prefers "Kissavos" for Ossa (OSM tags only "Όσσα"/"Ossa", so the map uses Ossa).
