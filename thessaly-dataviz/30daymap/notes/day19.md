# Day 19 · Smell — Sage rules the plain, mint and thyme the mountains

**Idea**
Thessaly's aromatic herbs — sage, thyme, mint, mountain tea, oregano, savory and lavender — as six small maps on a
tint of the land above 500 m, plus a strip comparing the height of every record with the height of the land.

**Data**
- GBIF occurrence API, one query per genus (`taxonKey` via /v1/species/match): Origanum 2926611, Thymus 2926960,
  Salvia 2926981, Sideritis 2926685, Satureja 2926882, Mentha 2927173, Lavandula 2927302; retrieved 29 Oct 2026,
  https://api.gbif.org/v1/occurrence/search?taxonKey=… ; cache `30daymap/cache/gbif/day19_*.rds`,
  compact `30daymap/data/day19_herbs.csv`.
- Datasets kept: Herbarium Berolinense Berlin 343 (CC0), Lund University herbarium 189 (CC BY-NC),
  iNaturalist 84 (CC BY-NC), other 82 (incl. ETH/Univ. Zurich herbaria, CC BY).
- Copernicus GLO-90 DEM; Eurostat GISCO NUTS 2021.

**How**
- 752 records inside Thessaly; Pl@ntNet automatic IDs and uncertainty > 10 km removed → 698.
- DEM sampled at each record; share above 500 m per genus vs. share of land above 500 m.
- `facet_wrap` small multiples, Okabe–Ito colours (colourblind-safe); jitter strip vs. violin of land elevation.

**Finding**
Sage (Salvia) most recorded: 242 records, 14 species, only 29% above 500 m. Thyme 178 (61% above 500 m),
mint 101 (65%), mountain tea 91 (60%), oregano 51 (45%), savory & lavender 35 (69%). All herbs: 50% above 500 m,
against 39% of the land. 82% of records are herbarium specimens.

**Caveats**
- Records show where botanists and app users looked; herbarium trips favoured Olympus, Pindos, Pelion.
- Salvia includes rosemary (S. rosmarinus, about 20 records, often planted) and weedy lowland sages (S. viridis, S. verbenaca).
- Satureja and Lavandula merged (few records).

**Status**
done
