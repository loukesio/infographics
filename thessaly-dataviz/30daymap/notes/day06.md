# Day 06 · Vintage — 37% of Thessaly is plain, 16% is mountain

**Idea**
An old-atlas relief plate of Thessaly: faded hypsometric tints, 200 m contours, sepia relief shading, rivers in faded blue, engraved coast ripples and a serif cartouche with the "scale of heights" that doubles as the chart (share of the land in each height band).

**Data**
- Copernicus GLO-90 DEM (ESA/Airbus, 2021), https://copernicus-dem-90m.s3.amazonaws.com/ — Copernicus DEM licence.
- OpenStreetMap, Geofabrik Greece extract 2026-10-28, https://download.geofabrik.de/europe/greece.html — rivers (waterway = river), lakes Karla, Plastiras, Smokovo, positions of the peaks used for the range names — ODbL.
- Eurostat GISCO NUTS 2021 1:1M (border, coast), © EuroGeographics.

**How**
- Land cells of mainland Thessaly classified into 7 bands (0–100, 100–200, 200–500, 500–1,000, 1,000–1,500, 1,500–2,000, > 2,000 m); shares from `terra::freq()`.
- Contours from a 270 m smoothed copy (`terra::as.contour`), hillshade from `m30_hillshade()` rescaled to 0–1, coast ripples = buffers of the coastline.
- Playfair Display (title, range names), Cormorant Garamond (text), Fira Sans (Greek «Θεσσαλία»).

**Finding**
- Below 200 m: 36.7% of the land (5,070 km²); above 1,000 m: 16.4%. Total 13,809 km² of land cells.
- Bands: 0–100 m 17%, 100–200 20%, 200–500 24%, 500–1,000 23%, 1,000–1,500 12%, 1,500–2,000 4%, > 2,000 0.5%.

**Caveats**
- Mainland only (Sporades left out). GLO-90 is a surface model (tree and roof tops).
- Land total differs slightly from Day 05 (13,809 vs 13,766 km²) because Day 05 rasterises the border, Day 06 masks by it.
- Coast ripples and cartouche are decoration, not data. Cormorant italic/bold are not installed as separate faces, so plain weights are used.

**Status**
done
