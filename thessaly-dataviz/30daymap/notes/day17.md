# Day 17 · Light & dark — Shortest day, one hour before sunset: 32% of Thessaly already lies in shadow

**Idea**
Thessaly's relief lit by the real sun of the winter solstice, 21 December 2025 at 16:09 Greek time, one hour before sunset at Larissa. Warm light where slopes face the low south-west sun, ink where they face away or sit behind a ridge. A strip shows the sun's height through that day.

**Data**
- Copernicus GLO-90 DEM (ESA/Airbus, 2021), https://copernicus-dem-90m.s3.amazonaws.com/ — Copernicus DEM licence.
- Sun position: NOAA Solar Calculator formulas (Meeus), https://gml.noaa.gov/grad/solcalc/calcdetails.html, implemented in the script (no package needed; suncalc is not installed).
- Eurostat GISCO NUTS 2021 (EL61), © EuroGeographics.

**How**
- NOAA formulas at Larissa (39.639 N, 22.419 E): sunrise 07:48, sunset 17:09 EET (upper limb, −0.833°). Moment 16:09 EET = 14:09 UTC: apparent altitude 8.75°, azimuth 229.6°; noon maximum 27.0° at 12:28.
- Self-shadow: cosine of the incidence angle ≤ 0 (slope/aspect from `terra::terrain`).
- Cast shadow: own ray march, 30 km towards the sun in 90 m steps on the DEM matrix, curvature with refraction k = 1/7; shadow if any terrain rises above the sun ray. (Not `terra::shade`, which only gives self-shading.)
- ggplot2 dark theme (`theme_m30(dark = TRUE)`), shadowtext.

**Finding**
- 32.5% of mainland Thessaly's land is in shadow (4,470 of 13,766 km²): 16.1% slopes facing away, 16.4% more in cast shadow behind ridges.

**Caveats**
- One sun position for the whole region (computed at Larissa); across Thessaly the sun differs by less than 1°.
- Bare terrain; clouds, haze, trees and buildings ignored. Nearest-cell ray march on a 90 m grid.
- The solstice is the shortest day, not the earliest sunset (that is in early December); the title says "shortest day".

**Status**
done
