# Day 08 · Utopia — Karla came back at a fifth of its size

**Idea**
Lake Karla (ancient Boibeis) was drained in 1962; a smaller lake was re-created in the lowest part of the old bed. The map puts the old lake at its record size next to today's lake — "the lake that was / the lake they want back" — and shows that Storm Daniel briefly refilled almost the whole old bed in September 2023.

**Data**
- Old lake size: Municipality of Rigas Feraios, history page «Λίμνη Κάρλα» — surface 60,000–180,000 stremmata (60–180 km²), largest ~180 km² in winter 1920–21; drainage works from 1956, final drainage 1962. https://www.rigas-feraios.gr/επισκεπτες/ιστορία/λίμνη-κάρλα/
- Re-created lake design: 38 km², mean depth ~2 m — Kagalou & Latinopoulos (2026), Frontiers in Environmental Science, doi:10.3389/fenvs.2026.1903658
- Today's lake: OpenStreetMap relation 12301781 (Geofabrik extract 2026-10-28), ODbL
- 2023 flood: Copernicus EMS Rapid Mapping EMSR692, observed flooded area, union of 28 products (6–22 Sep 2023), © EU
- Terrain: Copernicus GLO-90 DEM

**How**
- Old lake outline: level in today's DEM whose connected basin (seeded in today's lake) holds 180 km², found with `uniroot()` → 49.6 m; polygonised and smoothed (`smoothr`).
- 2023 water: EMS flood raster (20 m, built by day 26) inside the Karla basin (connected land below 60 m).
- terra, sf, ggplot2, patchwork, shadowtext.

**Finding**
Old lake at its 1920–21 high: 180 km² (source). Today's lake (OSM): 35.3 km² = 20% of it (5.1× smaller); designed 38 km². Storm Daniel water in the basin: 174 km² (EMS, 6–22 Sep 2023). DEM level holding 180 km²: 49.6 m.

**Caveats**
- No citable historic shoreline elevation was found (Wikipedia gives an uncited 60–80 m; papers give only areas). The outline is derived from today's DEM at the level that holds the documented area — an approximation, not a surveyed shoreline. The drained bed has been farmed and has subsided since 1962; GLO-90 is a 90 m surface model with the reservoir as a flat 45 m surface. Said on the chart.
- The documented low-water size (60 km²) could not be drawn: today's DEM already holds 67 km² at the reservoir's 45 m surface. Only mentioned in the subtitle.
- 174 km² flood is EMS pixels in the basin, depends on the basin definition (< 60 m connected); efsyn.gr (18 Sep 2023, Landsat-8, NOA/meteo.gr) reported ~190 km² on 16 Sep 2023 — same order.

**Status**
done (needs Loukas: OK with a DEM-derived old shoreline? If he has a historic map / survey level of the 1950s lake, swap it in).
