# Day 22 · Projections — Thessaly is 14,050 km². Web Mercator makes it 23,700, a far-side globe 3,310

**Idea**
The same outline of the Region of Thessaly (with the Sporades) drawn in nine projections at one common scale, each labelled with its EPSG/PROJ code and the area you would measure flat on that map. A dashed ghost shows the true shape; a dot strip puts all nine areas on one axis against the true area.

**Data**
- Eurostat GISCO NUTS 2021 1:1M, EL61, https://gisco-services.ec.europa.eu/distribution/v2/nuts/ — © EuroGeographics.
- Natural Earth 1:110m countries (globe locator), public domain, via rnaturalearth.
- Projection definitions: EPSG registry / PROJ.

**How**
- True area: geodesic area on the WGS84 ellipsoid, `terra::expanse()` on lon/lat (GeographicLib). (`lwgeom` is not installed, so `sf::st_area` on lon/lat was not used.)
- Map area: planar `st_area()` of the outline in each CRS. Shapes shifted to their centroid and drawn in metres on one scale.
- Projections: EGSA87 EPSG:2100, UTM 34N EPSG:32634, UTM 31N EPSG:32631 (wrong zone), Web Mercator EPSG:3857, World Equidistant Cylindrical EPSG:4087, Mollweide ESRI:54009, LAEA on Larissa, orthographic from 0° N 50° W, orthographic on Larissa (+ globe inset, not to scale).

**Finding**
- True area 14,055 km².
- Within 0.2%: EGSA87 14,053; UTM 34N 14,048; LAEA 14,055; orthographic on Larissa 14,054; Mollweide 14,073 (+0.1%).
- Off: UTM 31N 15,016 (+6.8%), equidistant cylindrical 18,247 (+29.8%), Web Mercator 23,659 (+68.3%), orthographic from 50° W 3,310 (−76.4%).

**Caveats**
- Areas are of the generalised 1:1M outline; the official area of Thessaly is about 14,036 km².
- PROJ's Mollweide uses a sphere with the WGS84 semi-major axis, hence +0.1% although equal-area.
- The "far-side globe" is an extreme on purpose: Thessaly near the edge of an orthographic view from over the Atlantic.

**Status**
done
