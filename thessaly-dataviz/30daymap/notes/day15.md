# Day 15 · Inside out — Close the Vale of Tempe and Thessaly is a lake of 2,880 km² again

**Idea**
Herodotus (Histories 7.129) writes that Thessaly was once a lake ringed by mountains until the Pineios cut the Tempe gorge. Thought experiment on today's terrain: plug the gorge, let the water rise until it finds the next way out, and draw the basin as water and the mountains as the land. Towns get their depth "under the lake".

**Data**
- Copernicus GLO-90 DEM (ESA/Airbus, 2021), https://copernicus-dem-90m.s3.amazonaws.com/ — Copernicus DEM licence.
- OpenStreetMap Pineios line (waterway = river, name = Πηνειός), Geofabrik extract 2026-10-28, ODbL.
- Eurostat GISCO NUTS 2021 1:1M (coast = outlet, region border), © EuroGeographics.
- Herodotus, Histories 7.129 (paraphrased on the chart).

**How**
- Outlets = sea cells (outside the NUTS land polygon) and the DEM window edge. Plug = Pineios between 22.545 E and 22.72 E, buffered 500 m, set to 5,000 m.
- Binary search on the water level; `terra::patches()` groups cells below the level; spill level = lowest level at which the patch with Larissa reaches an outlet. Lake = that patch just below it.
- Result cached in `30daymap/cache/terrain/day15_spill.rds` (delete to recompute, ~5 min).

**Finding**
- With the gorge open, Larissa (85 m) already drains to the sea at 85 m: no lake.
- With the gorge plugged, the water spills at **121.6 m**, at 22.787 E 39.688 N, the low gap east of the Karla basin towards the Aegean coast.
- Lake: 2,880 km² (2,833 km² inside Thessaly = 21% of its land), deepest 112 m. Larissa 37 m under, Tyrnavos 28 m, Karditsa 10 m, Trikala 8 m; Farsala, Volos, Kalambaka, Elassona stay dry.

**Caveats**
- A thought experiment on today's ground, not a reconstruction: the plain has been filled with river sediment for millennia and the gorge has deepened since. Said on the chart.
- The spill level depends on the 90 m DSM: a road cut, a narrow channel or tree canopy at the gap could shift it by a few metres. A first try with a plug drawn along the gorge (not across it) leaked and gave 110.6 m; the final plug covers the whole river line through Tempe.
- "Deepest 112 m" is just outside the plug at the gorge entrance, where today's river bed is lowest.

**Status**
done
