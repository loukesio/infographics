# Day 12 · Power — 1,644 solar parks, 22 km² of panels

**Idea**
A night map of Thessaly's power: every solar site traced in OpenStreetMap as an amber dot (area to scale), the glowing
400 kV and 150 kV grid, substations, wind turbines and the three big hydro plants. Bars rank the regional units by
mapped solar area.

**Data**
- OpenStreetMap, Geofabrik Greece extract 2026-10-28, © OpenStreetMap contributors, ODbL.
  https://download.geofabrik.de/europe/greece.html (local `30daymap/cache/thessaly_osm.gpkg`; power subset cached in
  `30daymap/cache/day12/power.rds`). Tags: power=plant|generator (+ plant:source / generator:source),
  power=line|minor_line|cable (+ voltage), power=substation, generator:source=wind.
- Copernicus GLO-90 DEM (hillshade) · Eurostat GISCO NUTS 2021 EL61 (mainland) · GADM 4.1 (regional units).

**How**
- Solar plants are closed ways in the `lines` layer (GDAL's OSM config does not treat power=* as area) → cast to
  polygons; plus multipolygons. Solar site = solar plant + solar generator polygons that touch no plant.
- Area = area of the union (EGSA87). Grid lengths clipped to the border. Units by nearest GADM unit.
- ggplot2, sf, terra, ggfx (outer glow), patchwork, shadowtext. Unit table: `30daymap/data/day12_solar_by_unit.csv`.

**Finding**
**1,644 solar sites mapped (1,431 plants + 213 stand-alone arrays) on 21.6 km² (2,160 ha)**; median 0.9 ha, largest
71 ha (near Trikala). Larissa unit: 928 sites, 1,312 ha (61% of the area). Grid: 395 km of 400 kV, 774 km of 150 kV
inside the region; 35 substations; 30 wind turbines. Hydro (OSM capacity tags): Plastiras 129.9 MW, Glystra 90 MW,
Smokovo 10.37 MW.

**Caveats**
OSM completeness varies: field parks in Greece are well traced from imagery, rooftop PV is mostly absent, newest
parks lag. 1,416 of 1,431 solar plants have no capacity tag, so no MW total is claimed. 20 kV distribution is nearly
unmapped. "Glystra" is the plant name as tagged in OSM (Mesochora–Glystra scheme on the Acheloos) — Loukas may want to
check it. Sporades excluded.

**Status**
done
