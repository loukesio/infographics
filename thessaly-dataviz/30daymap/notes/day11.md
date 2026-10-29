# Day 11 · Sound — Thessaly on tape: 355 recordings, half of them grasshoppers

**Idea**
Map every animal sound recorded in Thessaly and shared on GBIF, each spot drawn as concentric "sound rings" (more
rings = more recordings). Surprise: the soundscape on record is mostly bush-crickets and bats, not birds.

**Data**
- GBIF occurrence API, `mediaType=Sound`, bbox 21.1–24.4 E / 38.9–40.25 N, clipped to NUTS-2 EL61,
  retrieved 29 Oct 2026: https://api.gbif.org/v1/occurrence/search?mediaType=Sound — 1,314 in bbox, 357 inside
  Thessaly, 355 with uncertainty ≤ 10 km. Cache `30daymap/cache/gbif/day11_sound.rds`, compact `30daymap/data/day11_sound.csv`.
- Datasets: xeno-canto Orthoptera 146, xeno-canto Chiroptera 71, iNaturalist 66, xeno-canto birds 38,
  ZFMK DORSA (Bonn Orthoptera sound archive) 32, xeno-canto soundscapes 1, other 1.
  Licences: xeno-canto CC BY-NC 4.0, DORSA CC BY 4.0, iNaturalist CC BY-NC.
- Border: Eurostat GISCO NUTS 2021.

**How**
- Paged GBIF search API (`jsonlite`), cached; recordings snapped to a 1 km grid per group.
- Rings: 1 + floor(log2 n) circles per spot (1, 2–3, 4–7 … recordings), colour by animal group.
- Two bar strips (by group, top 12 species); `patchwork`, `shadowtext`.

**Finding**
355 recordings of 73 species by 46 recordists, 1980–2026. Grasshoppers & bush-crickets 180 (51%), birds 82 (23%),
bats 71 (20%), frogs 9, other 13. Most-recorded species: common pipistrelle (62). One recordist, K.-G. Heller,
made 139 (all Orthoptera).

**Caveats**
- Shows where recordists went (a few expert trips), not where animals sing most.
- xeno-canto birds are only partly in GBIF, so birds are under-represented vs. xeno-canto itself (its API needs a key, not used).
- Old DORSA recordings (1980s) can have approximate coordinates.

**Status**
done
