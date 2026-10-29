# Day 04 · Clusters — Three places hold 44% of Thessaly's threatened-species records

**Idea**
Instead of the hex grid of t13, let the records find their own hotspots: DBSCAN groups records of globally
threatened species that lie close together, and each cluster glows on the map, named after the place it sits on.

**Data**
- `data/gbif_thessaly_threatened.csv` (from `scripts/00_fetch_gbif_thessaly.R`), GBIF occurrence API,
  https://api.gbif.org/v1/occurrence/search, `iucnRedListCategory` = CR/EN/VU, retrieved 10 Oct 2026; licences per
  record (CC0 / CC BY / CC BY-NC). Same filter as t13 (uncertainty ≤ 10 km, EBCC atlas squares removed): 1,563 records.
- Cluster names: nearest OpenStreetMap place (Geofabrik 28 Oct 2026), checked against the dominant species.
  Table: `30daymap/data/day04_clusters.csv`.

**How**
- `dbscan::dbscan()` on EGSA87 metres, **eps = 3 km, minPts = 20**.
- Cluster shape = convex hull + 1.5 km buffer, `ggfx::with_outer_glow`; noise records as small grey dots.
- Ranked bar strip of the 10 clusters + "not in a cluster"; `patchwork`.

**Finding**
10 clusters hold 958 of 1,563 records (61%). The top three — Lake Karla 363, Meteora 184, Mount Pelion 147 = 694
records (44.4%) — cover 206 km², 1.5% of the region. Then Volos shore 65, Argyropouli 52, Namata 39,
Dolichi/Olympus foothills 38, Theopetra 27, Vlachava 22, Alonnisos 21.

**Caveats**
- Records show where people looked (iNaturalist users, birders, museum collections), not only where species live.
- Global IUCN categories as served by GBIF, not the Greek Red Data Book.
- Results depend on eps/minPts; with eps 2–4 km and minPts 15–25 the three biggest clusters stay the same
  (Lake Karla 354–381, Meteora 179–211, Pelion 95–161).
- "Argyropouli" and "Namata" are named after the nearest village; the records there are endemic fish
  (Gobio feraeensis) and pochard, i.e. a stream / wetland near that village.

**Status**
done
