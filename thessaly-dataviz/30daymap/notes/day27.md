# Day 27 · New tool — From the river to the gods: 2,815 m in 29 km

**Idea**
A 3D oblique view of Olympus, the Vale of Tempe and Ossa, made with a tool new to this project: **mapgl**
(Kyle Walker's R interface to MapLibre GL JS) with real terrain in the browser, no token. The title measures
the climb from the Pineios in the gorge to the top of Olympus.

**Data**
- 3D terrain + hillshade: Mapzen/AWS Terrarium elevation tiles — https://registry.opendata.aws/terrain-tiles/ (open data, attribution).
- Numbers: Copernicus GLO-90 DEM via `m30_dem()` — https://registry.opendata.aws/copernicus-dem/ — free licence.
- Peaks + heights: OpenStreetMap `natural=peak` / `natural=mountain_range` with `ele`, Geofabrik Greece extract
  2026-10-28 — https://download.geofabrik.de/europe/greece.html — ODbL. Pineios: OSM `waterway=river`, name Πηνειός.
- Sea: box minus Eurostat GISCO NUTS 2021 land. Label glyphs: OpenFreeMap fonts.

**How**
- GDAL's default `osmconf.ini` drops `ele`, so peaks were re-extracted from `greece.osm.pbf` with a copy that keeps it
  (`30daymap/cache/day27/peaks.gpkg`).
- River level: GLO-90 sampled every 90 m along the OSM Pineios inside the gorge box (22.53–22.60 E, 39.86–39.92 N);
  summit: GLO-90 maximum within 500 m of the OSM Mytikas node; distance = straight line between the two points.
- mapgl `maplibre()` with an own minimal style (DEM sources, terrain, hillshade in the style, because mapgl's
  `add_raster_dem_source()` passes only a TileJSON url, no `tiles`/`encoding`), exaggeration 1.4×, pitch 62°, bearing 50°.
- Screenshot with Chrome's own headless CLI on the Metal GPU (`--use-angle=metal`); chromote/webshot2 (SwiftShader)
  left whole terrain tiles flat. Framed with magick + ggplot2 (`m30_labs`). Live 3D page: `out/day27_new_tool.html`.

**Finding**
- Pineios in Tempe: 10–33 m (GLO-90). Mytikas: 2,825 m in GLO-90, 2,917.7 m in OSM.
- Relief **2,815 m over 29.0 km** (DEM to DEM); 2,908 m if the OSM summit height is used.
- Ossa: 1,977 m (`ele` of the OSM `mountain_range` node Όσσα, which sits on the summit; no peak node has a height there).

**Caveats**
- 90 m DEM smooths the summit (−93 m vs the surveyed height). The 3D view uses a different DEM (Terrarium) than the numbers.
- Vertical exaggeration 1.4× (in the caption). Labels are MapLibre symbols, so their font is Noto Sans (OpenFreeMap glyphs).
- The screenshot needs a Mac with a GPU and internet (tiles); rerunning on another machine may need the chromote path.

**Status**
done
