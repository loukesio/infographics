# Day 05 · Sight — Olympus sees 32% of Thessaly, Meteora only 6%

**Idea**
Two viewsheds over mainland Thessaly: what a person standing on Mytikas (Olympus' summit) and on the rock of Great Meteoron could see on a perfectly clear day. Blue = seen from Olympus, red = seen from Meteora, purple = both. A bar strip gives the share of the land and the farthest visible ground.

**Data**
- Copernicus GLO-90 DEM (ESA/Airbus, 2021 release), https://copernicus-dem-90m.s3.amazonaws.com/ — licence: Copernicus DEM free licence (attribution).
- Copernicus GLO-30 DEM tiles N39 E021, N40 E022, https://copernicus-dem-30m.s3.amazonaws.com/ (observer heights only), same licence.
- OpenStreetMap, Geofabrik Greece extract 2026-10-28 (peak node "Μύτικας", polygon "Μονή Μεγάλου Μετεώρου"), ODbL.
- Eurostat GISCO NUTS 2021 (EL61), © EuroGeographics.

**How**
- `terra::viewshed()` on the 90 m DEM (region + 20 km), target 0 m, curvature + refraction `curvcoef = 6/7`.
- Mytikas eye = official 2,918 m + 1.7 m; Great Meteoron eye = GLO-30 top of the monastery polygon (541 m) + 1.7 m.
- Shares = visible land cells (DEM > 0) inside mainland Thessaly / all land cells (13,766 km²).
- ggplot2, tidyterra, shadowtext, ggtext.

**Finding**
- Visible from Mytikas: 32.4% (4,470 km²), farthest ground 134 km away.
- Visible from Great Meteoron: 5.6% (760 km²), farthest 122 km.
- From both: 4.0% (540 km²); from at least one: 34.0%.

**Caveats**
- Bare terrain only, no haze, trees or buildings: a best case.
- **Very sensitive to the summit height.** The DEMs cut the Mytikas needle (GLO-30 top 2,792 m, GLO-90 cell 2,768 m) and make neighbouring Skolio (DEM 2,899 m) look higher. With the DEM height as eye the share drops to 4.9%. The official 2,918 m was used; this is stated on the chart.
- The prompt's Meteoron coordinate (39.7217 N 21.6261 E) lies in the valley (330 m); the OSM monastery polygon (39.7267 N 21.6255 E) was used. The often quoted 613 m of the rock would see slightly more than the DEM's 541 m.
- Mytikas sits ~70 m outside the 1:1M region border; the view is computed over the whole DEM window.

**Status**
done
