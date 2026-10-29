# Day 16 · Collaborative map — 1,244 people built this map, 7 of them did half the work

**Idea**
Thessaly's nature map as citizen science: every research-grade iNaturalist observation, binned into 5 km hexagons
coloured by how many different people observed there. Two small panels show the growth in observers per year and
how few people make most of the records.

**Data**
- iNaturalist Research-grade Observations via GBIF (datasetKey 50c9509d-22c7-4a22-a47d-8c48425ef4a7,
  https://www.gbif.org/dataset/50c9509d-22c7-4a22-a47d-8c48425ef4a7), GBIF occurrence API, retrieved 29 Oct 2026,
  bbox 21.1–24.4 E / 38.9–40.25 N then clipped to NUTS-2 EL61. Records CC0 / CC BY / CC BY-NC.
  Cache: `30daymap/cache/gbif/day16_inat.rds` (+ one file per year in `day16_inat/`); compact: `30daymap/data/day16_inat_hex5km.csv`, `day16_inat_years.csv`.
- Border: Eurostat GISCO NUTS 2021. No OSM data used.

**How**
- GBIF search API paged per year (deep offsets > ~20,000 take minutes per page, so the download is split by year
  and resumable); 48,130 in bbox → 23,508 inside Thessaly → 20,958 with uncertainty ≤ 10 km.
- 5 km hexagons (`st_make_grid`), distinct `recordedBy` per hexagon, six purple classes.
- Bars of observers per year; cumulative share of observations by observer rank (log x); `patchwork`, `shadowtext`.

**Finding**
20,958 observations of 3,031 species by 1,244 observers. 7 observers made half of all observations; the top 10
made 55%; 39% of observers made a single observation. Observers per year rose from 18 (2015) to 304 (2025);
279 so far in 2026. 46% of the 5 km hexagons have no observation; the busiest hexagon (Kalambaka/Meteora) has 349 observers.

**Caveats**
- Only research-grade records reach GBIF; casual observations are missing.
- recordedBy is a display name: one person with two accounts counts twice, a shared family account once.
- Obscured records of sensitive species (coordinates blurred by iNaturalist) mostly fall out with the 10 km filter (2,550 dropped).
- 2026 is a partial year (to 29 Oct).

**Status**
done
