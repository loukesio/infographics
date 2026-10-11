# Thessaly & data-journalism dataviz project — handoff for Claude Code

Owner: **Loukas Theodosiou** (data scientist, Göttingen; from Larissa, Thessaly, Greece). He makes data-journalism
graphics in **R / ggplot2**, and is the author of the R package **ggvmap** (Voronoi treemaps, github.com/loukesio/ggvmap).
This file is everything you need to run, check and extend the project. Read it fully before changing anything.

---

## 1. How Loukas wants to work (important)

- **Plain language, short answers.** No long multi-paragraph replies. Simple beats complex.
- **Never invent data.** Every number in a chart must come from a source you can name. If data cannot be found or
  looks wrong, say so and stop, instead of filling the gap. (Example: a Wikipedia infobox gave Pyli's
  population as a round "20,000" placeholder; that chart was dropped.)
- **Never draft with placeholders.** Ask for missing details first, then build the finished thing.
- **Look matters a lot.** He called the first generic charts "ugly". What he liked:
  - white background (`plot.background = "white"`), lots of air, a title that states the finding
  - fonts: **Oswald** (titles), **Fira Sans / Fira Sans Condensed** (text), Playfair Display (drought title)
  - styles he asked for: **spren9er** (fan / hierarchical edge bundling, github.com/spren9er/tidytuesday),
    **Jake Kaupp**, **Cédric Scherer**, competition winners (Information is Beautiful Awards, Sigma Awards),
    the **Bundestag ribbon-bar chart** (Ansgar Wolsing), **Jake Lawlor's radar "Flavors of 3 Playlists"**,
    **Scientific American "Escalating Drought"** small multiples, **Benjamin Nowak "The Price of Land"** decile map,
    **"Made in France"** export Sankey.
  - his own package **ggvmap** whenever a part-to-whole story fits.
- **Fonts and Greek:** Oswald, Playfair Display and IBM Plex Mono (Google builds) have **no Greek glyphs** — Greek text in
  them silently falls back to another font. Charts in this project are in English; for Greek use Fira Sans / Fira Sans Condensed.
- Always render the PNG and **look at it** before saying it is done: check overlapping labels, text running out of
  shapes, titles colliding with subtitles, legend colours matching the plot.

---

## 2. Setup (once)

```bash
cd thessaly-dataviz
Rscript setup/install_packages.R   # CRAN packages + ggvmap from GitHub + geomtextpath
Rscript setup/install_fonts.R      # Oswald, Fira Sans, Fira Sans Condensed, Playfair Display
# restart R afterwards so the fonts are found
Rscript run_all.R                  # rebuilds every chart into out/
```

Notes
- R ≥ 4.3. Tested with ggplot2 3.4.4; newer ggplot2 is fine.
- **geomtextpath is required for ggvmap's curved ring labels.** Without it ggvmap silently falls back to straight
  labels (this happened once and looked bad). With ggplot2 < 3.5 install the 2022 version:
  `remotes::install_github("AllanCameron/geomtextpath", ref = "4247e70")`.
- Scripts that print Greek letters or "CO₂" need a UTF-8 locale. `run_all.R` sets it; if you run a script alone and see
  `gridtext has encountered a tag that isn't supported yet: <e2>`, run with `LANG=en_US.UTF-8`.
- `run_all.R` has not been run end-to-end in its final form (the user stopped that test). Every script was rendered
  individually. Run `Rscript run_all.R` first and fix any path problem it reports.

---

## 3. Folder layout

```
thessaly-dataviz/
├── CLAUDE.md                ← this file
├── run_all.R                ← rebuild everything
├── setup/                   ← install_packages.R, install_fonts.R
├── R/radial_fan.R           ← reusable spren9er-style fan chart function
├── scripts/                 ← one script per chart (names below)
├── data/                    ← all input data (CSV)
└── out/                     ← rendered PNGs
```

All scripts use paths relative to the project root (`data/...`, `out/...`). Run them from the root.

---

## 4. Every chart: status, data, caveats

Status key: ✅ done and liked · 🟡 done, needs a check or redesign · ⏳ not run yet

### Greece, Thessaly, Larissa

| Script | Chart | Status | Data & source | Caveats |
|---|---|---|---|---|
| `t4_greek_parliament.R` | Hellenic Parliament 1974–2023, seat share per party, ribbon bars (Bundestag style) | ✅ | `data/greek_parliament_seats.csv` | **Seat counts were typed by Claude from memory** (Wikipedia tables did not load). Each election sums to 300 (the script checks), and 1990, 1993, 2000, 2007, Jun 2023 matched Wikipedia. **Verify every row against the Ministry of Interior / Wikipedia before publishing.** Nov 1989 & Jun 1989 small parties are lumped as "Others". |
| `00_prep_larissa_vs_greece.R` | builds `data/larissa_vs_greece.csv` | ✅ | Ministry of Interior results scraped in github.com/GrigorisLionis/Elektion-Data-Scraper | Matches published shares (2019: ND 39.85% Greece, 39.30% Larissa). NA41 = Golden Dawn (2019). |
| `t5_larissa_bellwether.R` | "As Larissa votes, so votes Greece" — Greece vs Larissa bars per election 2019–2024 | ✅ | above | Only 2019, May/Jun 2023, 2024 EU exist in that repo. |
| `t6_larissa_mayor.R` | Larissa mayor elections 2014–2023, all candidates, both rounds | ✅ | `data/larissa_mayor.csv` from ekloges.thessaly.gov.gr (Dim2014A/B, Dim2019A/B, Dim2023A, `results.aspx?pe=1&d=4`) | Vote counts sum exactly. 2010 page did not load. 2014 first-round numbers differ by ~40 votes between the A and B pages; the A page was used. |
| `t8_larissa_mayors_history.R` | Mayor timeline 1975→ + deciding round of each election since 1998 | 🟡 | onlarissa.gr 2019 retrospective (1998–2014), eleftheria.gr mayor list, Region results | Before 2014 only the deciding round is online. Pre-1994 mayors are grey (party backing unknown). Loukas prefers the 1881 version (t10) for the timeline; possibly merge t10 + the vote panel of t8 into one poster. |
| `t10_larissa_mayors_1881.R` | 145 years of mayors, one row per person, elected vs appointed | ✅ | `data/larissa_mayors_1881.csv`, typed from eleftheria.gr «Οι δήμαρχοι της Λάρισας από το 1881 μέχρι σήμερα» (Greek names kept in the CSV) | Source overlaps (1967–70 vs 1969–74; 1978–81 vs 1980–94): hand-over drawn at the later start. 1944–46 short terms drawn in order, not exact months. Mamakos (2023–) added from election results. |
| `t11_mayor_professions_radar.R` | "Who Ran Larissa?" radar of mayors' professions in 3 eras (Lawlor style) | ✅ | same CSV | Profession groups chosen by Claude (lawyer+judge = Law, merchants+businessmen+landowner = Trade, …). Mamakos' profession is not in the source → excluded; add it to the CSV if known. |
| `t1_storm_daniel.R` | Storm Daniel 2023 as rain gauges vs Athens' yearly rain | ✅ | numbers in the script: NOA/meteo.gr via KeepTalkingGreece (daily records 762/760 mm, Makrynitsa 1,235 mm monthly, old record 417 mm), NASA Earth Observatory (Zagora 910 mm & Karditsa 659 mm in 4 days, Athens 400 mm/yr), Wikipedia (730 km² flooded, 17 deaths, 110,000 animals) | Sources disagree slightly (Zagora one-day 754/759/760 mm). |
| `t12_thessaly_population_3d.R` | Thessaly population density as a 3D spike map (rayshader, Kontur/@researchremora style) | 🟡 | `data/kontur/kontur_population_GR_20231101.gpkg` (Kontur Population 2023-11-01 via HDX, CC BY; 400 m H3 hexagons) + `data/kontur/nuts2_2021.geojson` (Eurostat GISCO, EL61) | Mainland only: Sporades (~13,000 people) cropped. `FAST=TRUE Rscript …` for a quick camera check, `FAST=FALSE` for the rayrender final (~20 min). Needs rgl/rayshader/rayrender; runs headless (`rgl.useNULL`). Total 687,921 people ≈ ELSTAT 2021 census. |
| `t13_threatened_species_map.R` | "Where Thessaly's threatened species have been seen" — hex-bin map of GBIF records (IUCN CR/EN/VU) + strip of the 18 most-recorded species | ✅ | `data/gbif_thessaly_threatened.csv` built by `scripts/00_fetch_gbif_thessaly.R` (GBIF occurrence API, 2026-10-10; 1,971 records, 139 species inside NUTS-2 EL61) | Records with coordinate uncertainty > 10 km and the EBCC 50-km bird atlas are dropped before binning (1,563 kept). Categories = global IUCN list as served by GBIF, **not** the Greek Red Data Book (no open occurrence data). Some GBIF matches look wrong (Oxalis corniculata as CR). Hotspots verified from the data: Lake Karla, Meteora, Pelion, Pineios at Larissa, Olympus foothills. |
| `t14_thessaly_exports.R` | "What Thessaly sells abroad, and to whom" — products on top, markets below, links between ("Made in France" layout) | ✅ | `data/exports/*.csv` typed from the ΣΒΘΣΕ study «Στοιχεία εξαγωγών Περιφέρειας Θεσσαλίας, έτος 2025» (July 2026, ELSTAT data; PDF kept in `data/exports/`) | Box widths = € values. **Links are qualitative** (the study names main products per market but publishes no product × country values) — said on the chart. Bulgaria has only generic mentions → no link. See `data/exports/README.md`. |
| `t7_thessaly_drought.R` | Drought small multiples: years × regional units (Scientific American style) | ⏳ | **downloads ERA5 itself** from the free Open-Meteo archive API (no key) on first run, caches to `data/era5_thessaly.rds` | Download made resumable (one JSON per point in `data/era5_drought/`). **Open-Meteo throttles long daily requests (HTTP 429)**: ~30 points take an hour or more; if the run dies, rerun and it continues from the cache. Grid points assigned to the nearest regional-unit capital (approximate borders). Index = home-made non-parametric SPEI-3. **After running, look at the result and rewrite the title to the finding.** |

### Global data-journalism set

| Script | Chart | Status | Data | Caveats |
|---|---|---|---|---|
| `p1_carbon_majors.R` | Carbon Majors since Paris, **ggvmap** circle with curved ring | ✅ | `data/emissions.csv` (TidyTuesday 2024-05-21, Carbon Majors) | China (coal) = 29% is a nation-state entity in the dataset. |
| `p2b_ai_fan.R` | "Who Owns the Power Behind AI" — **spren9er fan chart** (uses `R/radial_fan.R`) | ✅ liked | `data/epoch_data_centers.csv` | **Transcribed from Epoch AI's `data_centers.csv` by a web tool, not downloaded.** Re-download https://epoch.ai/data/data_centers/data_centers.csv and rebuild the CSV (columns: name, owner, country, power_mw = "Current power (MW)", h100e) before publishing. |
| `p2_ai_datacenters.R` | same data as ggvmap | 🟡 | same | alternative version |
| `p3_redistribution.R` | Gini before vs after taxes (US vs Germany) | 🟡 | `data/income_inequality_processed.csv` (TidyTuesday 2025-08-05, OWID/LIS) | Loukas liked it but **did not understand it**. Redesign: explain Gini in plain words on the chart, label "before"/"after" on the top row, add a column "inequality cut by X%". |
| `p4_incarceration.R` | US imprisonment rate by race | 🟡 | `data/prison_summary.csv` (TidyTuesday 2019-01-22, Vera) | **Loukas found it confusing** ("same crime?"). It is prisoners per 100,000 residents of each group, not per crime. Redesign simpler, say that clearly in the title. Data ends 2015. |
| `p5_plant_extinction.R` | Plant extinction roses by continent | 🟡 | `data/plants.csv`, `data/threats.csv` (TidyTuesday 2020-08-18, IUCN) | Called ugly. Redesign or drop. |
| `t9_music_flavors.R` | Radar of Rock / Rap / EDM audio features | ✅ | `data/spotify_songs.csv` (TidyTuesday 2020-01-21) | demo of the Lawlor style |
| `x1_europe_acled_map.R` | Europe protests vs armed violence map (Africa ACLED map remake) | ⏳ | needs `data/acled_europe.csv` | ACLED needs a login; Open accounts only get **aggregated** data (weekly × Admin1 with centroid lat/lon) — the script expects that format. Europe coverage starts 2018. |

---

## 5. Reusable pieces

- `R/radial_fan.R` → `radial_fan(items, groups_order, colours, title, subtitle, caption, ...)`.
  `items` = tibble(item, group, value). Groups become bubbles (area ∝ total) pushed apart so they never overlap;
  items sit on the rim with curved links. Hub labels shrink to fit their bubble.
- Ribbon bars (t4, t5, t6, t8): compute `xmin/xmax` per row with `cumsum`, then polygons between consecutive rows
  for the same party/candidate key. Copy from `t4_greek_parliament.R`.
- Radar (t9, t11): draw in Cartesian coordinates (`x = r·sin θ, y = r·cos θ`) — not `coord_polar` — so edges stay straight.
- ggvmap: groups are coloured **in order of appearance**, not alphabetically. Pass `palette = unname(pal[unique(group)])`.

---

## 6. Next tasks (in Loukas's order of interest)

Do them one at a time, show the PNG, wait for feedback.

### 6.1 Run the drought chart
`Rscript scripts/t7_thessaly_drought.R` → look at it → set a real title (e.g. if recent years are darker, say so) →
also make a **map** version: share of months in drought per grid cell 1981–2024 vs 2015–2024, in the dark
"Price of Land" style (decile colour classes + dot strip of the distribution).

### 6.2 ELSTAT data (statistics.gr) — download and build
ELSTAT pages are not reachable from Claude's cloud sandbox; from Loukas's computer they are. Many tables are .xlsx
behind "Δημοσιεύσεις / Publications" pages; if a file cannot be fetched automatically, give Loukas the exact page and ask
him to download it into `data/elstat/`. Useful tables:

| Dataset (ELSTAT) | What to make |
|---|---|
| **Census 2021 & 2011 — permanent population by municipality, municipal unit and local community** (Απογραφή 2021, Μόνιμος πληθυσμός) | "Emptying villages": population change 2011→2021 per municipal unit of Thessaly. Fan chart (regional units → municipalities) or decile map. |
| Census historical tables (also ELSTAT digital library, openarchives.gr → ELSTAT) | Larissa city population 1881→2021, to pair with the mayors timeline (t10). |
| **Annual Agricultural Statistical Survey** — crop area & production by regional unit (cotton, wheat, maize, tomatoes, peaches, apples…) | Thessaly's share of Greek production per crop; ggvmap of Thessaly's farmland by crop. |
| **Agricultural Census 2020** (Farm Structure) — holdings, utilised area, livestock by region | farm sizes, livestock heads by regional unit |
| Livestock survey (sheep, goats, cattle by regional unit) | ties to Storm Daniel livestock losses |
| Regional accounts — GDP per capita by regional unit (NUTS3) | Thessaly units vs Greece |
| Labour Force Survey by region | unemployment Thessaly vs Greece |
| Vital statistics — births & deaths by municipality | natural decline map |
| Tourism — arrivals & nights by region | Pelion / Meteora / Sporades |

Municipality boundaries for maps: geoBoundaries (github.com/wmgeolab/geoBoundaries, Greece GRC) or GADM via
`geodata::gadm("GRC", level = 3)`. **Check which level matches the 2011 Kallikratis municipalities (~325) and match
names carefully (Greek vs Latin spellings)** before joining.

### 6.3 Endangered species in Thessaly (new idea)
- Source: **GBIF occurrence API**, e.g.
  `https://api.gbif.org/v1/occurrence/search?country=GR&iucnRedListCategory=EN&geometry=<Thessaly WKT polygon>&limit=300`
  (repeat for CR, EN, VU; page with `offset`; or use the `rgbif` package: `occ_search(country = "GR", iucnRedListCategory = "EN", geometry = ...)`).
  Check the parameter name in the current GBIF API docs first.
- Optional layers: Natura 2000 sites (EEA), the Greek Red Data Book.
- Chart idea: hex-bin map of threatened-species records over Thessaly + a strip of species by category.
  **Caveat to print on the chart:** GBIF records show where people looked, not only where species live.

### 6.4 Beekeepers in Thessaly (new idea)
- Source: Ministry of Rural Development & Food (minagric.gr / ΥΠΑΑΤ) beekeeping registry — number of beekeepers and
  hives by regional unit, published yearly (often PDF tables). Also ELSTAT livestock survey (beehives) and
  Eurostat honey statistics. Ask Loukas to download the PDF if it cannot be fetched; extract with `pdftools` / `tabulizer`.
- Chart idea: hives per regional unit (unit chart or ggvmap), Thessaly vs other regions, trend over years.

### 6.5 Where does Thessaly export? — DONE as t14 (2026-10-11). Yearly ΣΒΘΣΕ studies exist since ~2008; a time series of totals could follow.
- National data (UN Comtrade, Eurostat Comext) has no regional split. Regional sources:
  **ΣΕΒΕ / ΠΣΕ (Panhellenic Exporters Association) regional export reports for the Region of Thessaly**, and ELSTAT
  exports by region if available. They list top products and top destination countries.
- Chart: products on top, countries at the bottom, flows in between (ggalluvial or hand-drawn ribbons like the
  ribbon bars). Only build with real figures from one named source and year.

### 6.6 Redesigns asked for
p3 (taxes) and p4 (prisons) need to be understandable at a glance; p5 to be redone or dropped.
Possibly merge t10 (mayors since 1881) with the vote panel of t8 into one Larissa poster.

---

## 7. Suggested fixes for the ggvmap package (Loukas's own)

1. `vm_add_ring()` silently drops to straight labels when geomtextpath is missing → print a one-time message.
2. Ring labels ignore `family` → pass the font family through so the ring matches the cells.
3. Groups are coloured in order of appearance; document it or accept a named palette.

---

## 8. Sources used so far

- Carbon Majors via TidyTuesday 2024-05-21 · Epoch AI Frontier Data Centers hub · OWID/LIS income inequality via
  TidyTuesday 2025-08-05 · Vera Institute incarceration via TidyTuesday 2019-01-22 · IUCN extinct plants via
  TidyTuesday 2020-08-18 · Spotify via TidyTuesday 2020-01-21
- Hellenic Ministry of Interior results via github.com/GrigorisLionis/Elektion-Data-Scraper
- Region of Thessaly results: https://ekloges.thessaly.gov.gr/
- eleftheria.gr — mayors of Larissa since 1881 · onlarissa.gr — 20 years of elections in Larissa (2019)
- iefimerida.gr & thetoc.gr — Larissa as bellwether · protothema.gr — 2023 mayoral result
- NASA Earth Observatory "A Deluge in Greece" · KeepTalkingGreece (NOA records) · Wikipedia "Storm Daniel"
- ERA5 (Copernicus/ECMWF) via Open-Meteo archive API (drought, to be downloaded)
- ΣΒΘΣΕ (Σύνδεσμος Βιομηχανιών Θεσσαλίας & Στερεάς Ελλάδος) export study 2025 via larissanet.gr PDF · thessaliaeconomy.gr
- GBIF occurrence API (api.gbif.org/v1/occurrence/search, iucnRedListCategory filter) · Eurostat GISCO NUTS-3 2021
- Kontur Population Greece 2023-11-01 via HDX (data.humdata.org/dataset/kontur-population-greece) · Eurostat GISCO NUTS 2021

---

## 9. Handoff from the session of 10–11 October 2026

Read this first next time. A visual status board of every chart is `../gallery.html` (open it in a browser).

### What was done
- **t12 3D population map** — final rayrender version done. Script has `FAST` (software preview), `TEST` (24-sample rayrender for tuning lights) and the full run. Labels are drawn with magick after projecting spike tops through rgl; do not use `render_label`.
- **t13 threatened-species hex map** — done, English. Fetch script `scripts/00_fetch_gbif_thessaly.R`.
- **t14 exports chart** — done from the ΣΒΘΣΕ 2025 study (PDF + typed CSVs in `data/exports/`). Links qualitative.
- **Fonts** — `setup/install_fonts.R` now also installs Cormorant Garamond. All fonts are in `~/Library/Fonts`.
- **Exhibit panel 17** (other project) — real ERA5-Land series written, stamp cleared, heat-days figure added in R. See `../Thessaly Infographic Installation/HANDOFF.md` §3.1.

### What is pending, in Loukas's order
1. **Drought (t7)** — rerun `LANG=en_US.UTF-8 Rscript scripts/t7_thessaly_drought.R`. Open-Meteo refused everything after ~40 long requests on 10 Oct (HTTP 429, daily quota). The script caches one JSON per point in `data/era5_drought/` and resumes; 3 of 30 points are in. Expect ~1 h. Then look at the chart, write the finding into the title, and build the "Price of Land" style map version (CLAUDE.md §6.1).
2. **Rent prices over time** — spitogatos.gr blocks fetchers and headless Chrome. Loukas opens `https://www.spitogatos.gr/deiktis-timon` himself, picks Ενοικίαση + each Thessaly unit, and copies the quarterly €/m² series into `data/rents_spitogatos.csv` (columns: unit, quarter, eur_m2). Then: 4-line chart. Only press points exist otherwise (Larissa 7.5 €/m² Q3 2023; student housing Aug 2026: Larissa 10.0, Volos 10.0, Trikala 8.5, Karditsa 8.1).
3. **Exports cross table** — ask ΣΒΘΣΕ (sbtse.gr) or ELSTAT user support for product × country values for Thessaly 2025; then t14 becomes a true weighted Sankey. Fallback: Eurostat Comext, Greek feta (CN 0406 90 32) exports by partner, national level.
4. Everything in §6.2–6.6 above that is not ticked.

### Things learned (do not relearn)
- Oswald / Playfair / IBM Plex Mono have no Greek glyphs. Greek → Fira Sans (here) or Plex Sans (exhibit).
- Open-Meteo: cache per point, back off 45 s × attempt, request only needed variables, run in background.
- Copernicus CDS via `ecmwfr` needs the macOS Keychain password interactively → run in a foreground R session.
- The Chrome extension was not connected; headless Chrome print-to-PDF (`--print-to-pdf`, `--virtual-time-budget=20000`) is the way to proof the exhibit panels; `pdftools::pdf_convert(pages = 17)` gives the PNG.
- rayshader: `rgl.useNULL = TRUE` works headless; `render_snapshot(software_render = TRUE)` for previews; `rayrender::diffuse()` ground colour + sampling the rendered corner pixel for the magick border hides the scene rectangle.
