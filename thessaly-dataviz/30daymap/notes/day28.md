# Day 28 · Feeling — 2 August 2021: the plain felt like 46 °C

**Idea**
How hot it felt, not how hot it was: ERA5 daily maximum apparent (feels-like) temperature on the worst day of the summer 2021 heatwave, over Thessaly. A strip below shows how often Larissa now passes 40 °C.

**Data**
- ERA5 reanalysis (Copernicus/ECMWF) via Open-Meteo historical weather API (`models=era5`, `daily=apparent_temperature_max,temperature_2m_max`), 88 native 0.25° cell centres 21.0–23.5 E × 38.75–40.5 N, 25 Jul–8 Aug 2021, one multi-location request, cached `30daymap/cache/heat2021/era5_apparent_grid.json`. https://archive-api.open-meteo.com/v1/archive — CC BY 4.0.
- Larissa daily ERA5-Land tmax 1960–2024 (Open-Meteo, cell 39.64 N 22.42 E) from `../Thessaly Infographic Installation/data/larissa_daily_era5land.csv`.

**How**
- Hottest day = highest mean feels-like max over the 32 cells in/around the region → 2 Aug 2021 (also Larissa's max day of summer 2021, 45.1 °C).
- Bilinear interpolation of the 0.25° grid to 500 m (a thin-plate spline was tried and dropped: it overshot to 46.9 °C, above any data value), masked to the region, 2 °C filled contours + light hillshade.
- Strip: days with tmax ≥ 40 °C per year, averaged per decade.

**Finding**
2 Aug 2021: hottest ERA5 cell 46.2 °C feels-like at 39.50 N 21.75 E (Trikala municipality, between Trikala and Karditsa); 55% of the region felt ≥ 40 °C; mean over the region 39.6 °C; 5% (high mountains) stayed below 34 °C. Larissa days ≥ 40 °C per year: 1960s 0.8, 1970s 0.8, 1980s 2.0, 1990s 0.7, 2000s 1.7, 2010s 0.9, 2020–24 3.4.

**Caveats**
- ERA5 cells are ~25 km: smooth, misses town heat islands; bilinear interpolation shows soft facets of the grid. Values are reanalysis, not station readings.
- Apparent temperature = Open-Meteo's formula, not the Greek met office index.
- Strip uses air temperature (ERA5-Land), not feels-like; 2020–24 is five years only.

**Status**
done
