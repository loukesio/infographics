# Day 02 · Lines — Three fifths of Thessaly drains into one river

**Idea**
Every river reach of mainland Thessaly, line width by modelled mean discharge. The Pineios system is blue (main stem dark,
traced from the mouth at Tempi upstream along the largest upstream area); rivers that end in Lake Karla, the Pagasetic
Gulf or beyond the border are grey. A bar under the map gives the share of the region's land in each group.

**Data**
- HydroRIVERS v1.0 Europe, HydroSHEDS (Lehner & Grill 2013; Linke et al. 2019), CC BY 4.0 —
  https://www.hydrosheds.org/products/hydrorivers, file https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_eu_shp.zip
  (cached in `30daymap/cache/osm_days/hydrorivers/`)
- River and lake names (Pineios, Enipeas, Titarisios, Lithaios, Lake Karla): OpenStreetMap, Geofabrik Greece extract
  2026-10-28, ODbL, © OpenStreetMap contributors
- Border: Eurostat GISCO NUTS 2021 (EL61), via m30_base.R

**How**
- Basin = HydroRIVERS `MAIN_RIV`; Pineios = the basin with most reaches inside Thessaly (id 20616961, mouth at Tempi).
- Main stem: walk upstream from the mouth, always taking the reach with the largest `UPLAND_SKM`.
- Basin area inside Thessaly = sum of `CATCH_SKM` of reaches whose midpoint lies inside the border.
- Tributary labels: OSM river lines buffered 1.5 km, matched to HydroRIVERS reaches; label angle from the local direction.
  Packages: sf, ggplot2, shadowtext.

**Finding**
- Mainland Thessaly 13,774 km²; Pineios basin inside it 8,348 km² = **60.6%** (other basins 35.5%, no mapped river 3.9%).
- Pineios at the mouth: 9,300 km² upstream area, 67.3 m³/s mean discharge (modelled).
- Pineios system: 445 reaches, **2,100 km** of river; main stem 206 km (HydroRIVERS geometry, 15 arc-second network).

**Caveats**
- HydroRIVERS keeps only reaches with ≥ 10 km² upstream area or ≥ 0.1 m³/s; irrigation canals and ditches of the plain
  are not in it, so the plain looks emptier than it is. Discharge is modelled natural flow (no abstraction for irrigation).
- Pineios basin area in HydroSHEDS (9,300 km²) may be smaller than published figures, which sometimes include the
  Karla basin (now drained by tunnel to the Pagasetic Gulf). Lake Karla is a separate basin here. Check against a
  published figure before quoting km² in text.
- Lengths come from a 15 arc-second (~500 m) grid network, so they are approximate.

**Status**
done
