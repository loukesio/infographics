# Day 29 · Raster — 58% of Thessaly's plain is fields

**Idea**
The ESA WorldCover 10 m land-cover raster of mainland Thessaly as a print poster: the yellow patchwork of the plain, ringed by the forests of Pindus, Olympus, Ossa, Pelion and Othrys, with towns in built-up red. A strip compares the plain with the hills and mountains.

**Data**
ESA WorldCover 10 m 2021 v200, tiles N39E021 + N36E021, CC BY 4.0 (© ESA WorldCover project 2022 / contains modified Copernicus Sentinel data 2021). https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ — cached in `30daymap/cache/worldcover/`. Plain = below 200 m in Copernicus GLO-90. Border: Eurostat GISCO 2021.

**How**
- Shares from all 10 m pixels: `terra::crosstab()` of classes × plain/hills zones (`30daymap/data/day29_plain_counts.csv`).
- For drawing only: modal aggregation 4×4 (40 m) → EPSG:2100 nearest neighbour; at 10×10 in, 300 dpi one printed pixel ≈ 60 m, so nothing finer would be visible. Drawn as one RGB image with `annotation_raster()`.
- WorldCover legend colours toned for paper (cropland ochre, tree cover deep green, built-up rust).

**Finding**
Plain (< 200 m) = 5,063 km², 37% of mainland Thessaly. Cropland covers 58.1% of the plain (tree cover 18.4%, grassland 14.7%, built-up 4.5%, water 1.3%) vs 7.1% of the hills and mountains (tree cover 66%).

**Caveats**
- Modal aggregation for the picture slightly favours each block's dominant class (thin roads, small villages fade); the numbers are from the full 10 m data.
- "Tree cover" includes orchards and olive groves (in the plain, part of the 18% is orchards). "Plain" by a 200 m threshold is a simple definition.

**Status**
done
