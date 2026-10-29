# Day 18 · NULL — 36% of Thessaly has no resident at all

**Idea**
Kontur only lists 400 m hexagons with at least one person; the rest of the land is simply missing — NULL. The map
hatches that missing land, and a bar strip shows how the NULL share climbs with altitude.

**Data**
- Kontur Population Greece 2023-11-01, 400 m H3 hexagons — HDX, CC BY 4.0. https://data.humdata.org/dataset/kontur-population-greece
- Copernicus GLO-90 DEM (ESA/Copernicus, AWS open data, free licence) via `m30_dem()`.
- OpenStreetMap peaks (natural=peak), Geofabrik Greece extract 2026-10-28, ODbL — 5 massif labels at their highest named peak.
- Eurostat GISCO NUTS 2021 EL61, mainland.

**How**
- NULL land = mainland region polygon minus the union of all Kontur hexagons touching it (sf, EGSA87 areas).
- Hatch = 45° hairlines every 650 m clipped to the NULL polygon (hand-made, no ggpattern) over a pale tint.
- Elevation bands: NULL polygon rasterised on the 90 m DEM grid; share of cells per band
  (`30daymap/data/day18_null_by_elevation.csv`). sf, terra, ggplot2, patchwork, shadowtext.

**Finding**
**35.6% of mainland Thessaly (4,900 of 13,774 km²) has no resident in any 400 m hexagon.**
85% of the NULL land lies above 200 m. NULL share: 15% below 200 m, 34% at 200–500 m, 46% at 500–1,000 m,
63% at 1,000–1,500 m, 84% above 1,500 m.

**Caveats**
Kontur is modelled (GHSL, HRSL, building footprints, scaled to official totals): tiny hamlets or seasonal huts may be
missed or smeared. Border hexagons count whole. "No resident" is not "no use" — fields, pasture and forest are
there. Total here 687,921 people (hexagons touching the border); Day 09 uses hexagon centres (678,559).

**Status**
done
