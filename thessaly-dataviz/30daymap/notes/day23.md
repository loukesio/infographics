# Day 23 · Taste — 27 protected foods and drinks carry a Thessaly address

**Idea**
Thessaly's larder as the EU sees it: every geographical indication (PDO / PGI) whose official area covers part of
the region. A count map (how many protected names reach each municipality), a strip of the larder by kind, and one
small "food label" map per product with its Latin and Greek name, type and category.

**Data**
- EU eAmbrosia register, read 2026-10-29 through its API: list `https://webgate.ec.europa.eu/eambrosia-api/api/geographical-indications?size=1000&page=0..3`
  (3,935 GIs, 286 Greek), details `.../api/v2/geographical-indications/<id>`, specification files `.../api/v1/attachments/<id>`.
  EU register data, free reuse (Commission reuse policy).
- Product areas typed into `30daymap/data/day23_gi_thessaly.csv` (one row per GI, with the area text, the municipalities,
  whole/part, and a source URL per row).
- For 7 GIs eAmbrosia has no file. Sources used instead: OJ C 222/2010, C 307/2010 and C 322/2010 (Firiki Piliou, Arnaki and
  Katsikaki Elassonas); Reg. (EU) 2024/2017 (Kashkavali Pindou); AADE technical files TF 13A and 14A (Tsipouro of Thessaly
  and of Tyrnavos); the EU Ouzo technical file; the 2025 ministry single document for the Tyrnavos wine (its eAmbrosia file
  is a broken conversion). EUR-Lex, minagric.gr and aade.gr block scripts, so these were read from web-search excerpts.
- GADM 4.1 municipalities; villages named in the specifications placed with OSM place nodes (Geofabrik 2026-10-28, ODbL).

**How**
- Downloaded the specification of all 237 Greek GIs that have a file, extracted the text (pdftools), and searched it,
  accents removed, for Thessaly place names. The 27 hits were read by hand. All other hits were only passing mentions,
  e.g. "University of Thessaly" or rainfall at Larissa.
- Two specifications are in a broken Greek font encoding (Rapsani) or have no text layer. Rapsani was decoded by hand
  from the garbled text: Rapsani, Pyrgetos and Ampelakia.
- Village-level areas are drawn as their municipality in a lighter red ("only some villages"). Former provinces that
  cannot be mapped (Volos province for the olives, the 74 Agrafa villages) are drawn as the regional unit, light.
- ggplot2 + patchwork + ggtext; Cormorant Garamond for the label names, Fira Sans for the Greek.

**Finding**
- **27 GIs** touch Thessaly: 12 wines (3 PDO, 9 PGI), 7 cheeses (6 PDO, 1 PGI), 3 spirits (PGI), 2 meats, 2 apples,
  1 table olive (all PDO).
- Every municipality is covered by at least 8. Limni Plastira, Volos and Zagora-Mouresi are covered by 12 each, the most.
- 6 of the 27 reach far beyond the region: Feta, Kasseri, Manouri, Batzos, Galotyri and Ouzo.

**Caveats**
- "Touches" means at least part of the specified area lies in Thessaly. Ouzo covers all of Greece and Cyprus, and the
  Thessalia wine PGI covers the whole region, so every municipality starts from a high base.
- Kallikratis municipalities are bigger than the villages in the specifications. Altitude limits are not drawn.
- The areas of 7 GIs come from excerpts, not from the full official text (see Data). They are worth checking by hand:
  Tyrnavos wine, Tsipouro of Tyrnavos ("historical Tyrnavos area"), Kashkavali Pindou, Firiki Piliou, Arnaki and
  Katsikaki Elassonas, Tsipouro of Thessaly.
- Katiki Domokou (Fthiotida) has a scanned specification with no text layer. It is not counted.
- GADM places Gomfoi in Pyli, but the Graviera Agrafon specification puts it in Karditsa prefecture. That shows the
  GADM borders are approximate.

**Status**
done. Needs Loukas only to spot-check the 7 areas that come from excerpts (list above).
