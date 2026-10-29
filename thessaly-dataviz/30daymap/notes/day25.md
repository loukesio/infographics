# Day 25 · Is this a map? — Half of Thessaly is trees, a quarter is fields

**Idea**
A chart that is also a map: the outline of Thessaly and its four regional units is real, but inside each unit the land is re-cut into a Voronoi treemap with one cell per land-cover class. Each cell's area is the real area of that class in that unit. Built with Loukas's own package ggvmap (`vmap_region()`), as the coordinator asked (replaces the waffle idea).

**Data**
ESA WorldCover 10 m 2021 v200, tiles N39E021 + N36E021, CC BY 4.0 (© ESA WorldCover project 2022 / contains modified Copernicus Sentinel data 2021). https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_N39E021_Map.tif — pixel counts per unit saved in `30daymap/data/day25_worldcover_units.csv`. Units: GADM 4.1 municipalities dissolved (`m30_units()`, mainland).

**How**
- `terra::crosstab()` of the 10 m class raster × rasterised regional units (all ~208 million pixels counted).
- One `ggvmap::vmap_region()` fit per unit (unit polygon simplified to 150 m, seed 25); all four converged (convergence 0.18–0.50% of area, 31–102 iterations). No errors from vmap_region.
- Drawn with `vm_as_df()` + `geom_polygon(subgroup = ring, rule = "evenodd")`; labels at each cell's deepest interior point; ranked bars of Thessaly totals as the key.

**Finding**
Mainland Thessaly: tree cover 48.3%, cropland 25.8%, grassland 19.0%, shrubland 3.6%, built-up 2.1%, water 0.8%, bare 0.4%. Cropland per unit: Larissa 35%, Karditsa 35%, Magnesia 14%, Trikala 13%.

**Caveats**
- Pixels counted in EPSG:4326 (area varies < 2% across Thessaly's latitudes; shares only).
- WorldCover "tree cover" = canopy ≥ 10%: includes oak scrub, olive groves, orchards — this is why it is 48%. Said in the caption.
- Wetland (0.03%) merged into water. Cell positions inside a unit are arbitrary; only areas carry data.
- For ggvmap (Loukas's package): `vmap_region()` worked first time on GADM units; `vm_centroids(inside = TRUE)` put a label in the Pagasetic gulf hole of Magnesia's tree-cover cell, so a pole-of-inaccessibility label point was computed in the script instead — possible package improvement.

**Status**
done
