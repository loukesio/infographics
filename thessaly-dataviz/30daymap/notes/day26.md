# Day 26 · Water — Daniel flooded 926 km² of Thessaly

**Idea**
Every patch of land that the EU's Copernicus emergency service saw under water at least once after Storm Daniel, over the relief of the plain with the Pineios and Lake Karla. A strip shows how slowly the water went down in the four big mapped areas.

**Data**
Copernicus EMS Rapid Mapping, activation EMSR692 "Flood in Greece" (event 5 Sep 2023): 28 vector products (DEL_PRODUCT + DEL_MONIT01–05) for 7 AOIs, layer `observedEventA`, notation "Flooded area"; images 6–22 Sep 2023. https://rapidmapping.emergency.copernicus.eu/EMSR692 (API: .../backend/dashboard-api/public-activations/?code=EMSR692). © European Union, Copernicus EMS, free use with attribution. OSM (Karla, Pineios), Copernicus GLO-90, Eurostat GISCO 2021.

**How**
- Script downloads the activation JSON and all zip packages (S3 redirect), cached in `30daymap/cache/emsr692/`.
- Union of all "Flooded area" polygons by rasterising at 20 m (vector `st_union` of 15,000 polygons was too slow); area = pixel count × 400 m².
- Receding strip: flooded km² per product date for AOIs with ≥ 4 dates.

**Finding**
926 km² flooded at least once 6–22 Sep 2023 (913 km² inside mainland Thessaly). EMS's own activation statistic "max_extent" = 933 km² (agrees). Press figure 730 km² (single Sentinel-1 image). = 26× today's Lake Karla (35 km²). "Flood trace" areas (mud/wet soil, not counted) add ~613 km² more. Receding: Karditsa AOI 204 km² (10 Sep) → 15 km² (18 Sep); Stefanovikio (Karla) 126 → 84 km² (19 Sep), slowest.

**Caveats**
- Union over 17 days and different sensors: no single moment had 926 km² under water.
- AOIs cover the plain and Pelion, not every corner of the region; cloud gaps on some dates.
- AOI dates differ, so the strip compares each AOI with itself.

**Status**
done
