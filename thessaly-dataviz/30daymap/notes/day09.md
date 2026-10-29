# Day 09 · Urban-rural — Half of Thessaly lives on 1% of its land

**Idea**
Every populated 400 m hexagon of mainland Thessaly, coloured by the EU Degree of Urbanisation of the 1 km cell under it
(city / town or suburb / rural). A paired ribbon bar puts the share of people next to the share of land.

**Data**
- GHSL GHS-SMOD R2023A, epoch 2020, 1 km Mollweide — European Commission JRC, CC BY 4.0.
  https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_SMOD_GLOBE_R2023A/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000/V2-0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip
  (cached in `30daymap/cache/day09/`)
- Kontur Population Greece 2023-11-01, 400 m H3 hexagons — HDX, CC BY 4.0. https://data.humdata.org/dataset/kontur-population-greece
- Eurostat GISCO NUTS 2021 EL61 (mainland) for the border.

**How**
- Each Kontur hexagon takes the SMOD class of the 1 km cell under its centre; people summed per class.
- Land = count of 1 km SMOD cells (equal-area, centre inside the region), water class excluded.
- Classes grouped the EU way: City = 30, Towns & suburbs = 21–23, Rural = 11–13.
- sf, terra, ggplot2, patchwork, shadowtext. Shares saved in `30daymap/data/day09_urban_rural_shares.csv`.

**Finding**
Cities + towns & suburbs: **54.5% of the people on 1.09% of the land** (155 of 14,227 km²).
City 30.7% of people on 0.3% of land; towns & suburbs 23.8% on 0.8%; rural 45.5% on 98.9%. Total 678,559 people.

**Caveats**
SMOD is modelled for 2020 (from GHS-POP), Kontur is 2023; grids do not line up exactly. 67 people in SMOD water cells
counted as rural. Only Larissa and Volos reach "urban centre" (class 30). Sporades excluded.

**Status**
done
