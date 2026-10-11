# ΘΕΣΣΑΛΙΑ — data handoff

A brief for Claude (or anyone) to **source the real data and regenerate the plots** for this
wall exhibit. The design is finished; what it needs is observations.

---

## 1 · What this project is

An 18-panel printed exhibit about Thessaly and Larisa. Each panel is **B1 portrait, 70 × 100 cm**,
bilingual Greek-primary / English-secondary, printed at 12 pt minimum type and read from 1.5–3 m.

| File | What it is |
| --- | --- |
| `thessaly.html` | The 18 panels. One `<section class="page">` per panel, `id="p01"…"p18"`. |
| `charts.js` | Every map and chart, d3 v7 + topojson. One function per chart, registered in `drawAll()`. |
| `installation-plan.html` | Two A3 sheets: wall elevations, panel index, print spec. |
| `data/climate.json` | The only externalised dataset so far. **Currently provisional.** |
| `R/` | ggplot2 pipeline — see `R/README.md`. Built to be driven by Claude Code. |
| `export-svg.html` | Exports every chart as a standalone vector SVG. Open it, click through the two buttons. |

**Hard rules — do not break these:**

- Nothing below **12 pt** at final size. A panel is 2646 px ≡ 70 cm, so 12 pt = **16.0 px**.
  SVG text is subject to viewBox scaling — check *effective* px, not the declared attribute.
- **Contrast ≥ 4.5:1**, measured against the background the text actually sits on. The trap here
  is a *constant foreground over a parameterised background* — a label coloured `paper` while its
  background comes from a variable, or from a fill with opacity that composites against the page.
  This shipped twice and was caught twice. If the background varies, the foreground must vary with
  it, keyed off the same flag. Composite opacity before you measure.
- Palette only: `#f2eee3` paper · `#e7e1d1` paper2 · `#191713` ink · `#4a463d` ink2 ·
  `#8b8474` mute · `#c7bfa9` rule · `#b3241f` red · `#1c4b52` teal · `#c08a1e` ochre ·
  `#d9bd6a` wheat · `#141d1c` deep · `#2b6b76` water · `#dfe6e4` snow · `#5c6139` olive.
  No new colours. On the dark panels body-size red lifts to `#e8705f`; the red badges keep `#b3241f`.
- Type: Alegreya (display/numerals), IBM Plex Sans (body), IBM Plex Mono (labels). All carry Greek.
- Every number on a panel carries a source in that panel's footer. **If you cannot source it,
  do not print it** — leave the slot visibly empty rather than estimate.
- Greek first, English second, always. Greek decimal comma and thousands stop: `47,2 °C`, `688.255`.

---

## 2 · How the charts work

Each chart is a function in `charts.js` that calls `setup(id)` to get `{svg, w, h}`, draws with d3,
and is listed in the `drawAll()` array. Animation classes: `.fade` (fades in), `.gw` (grows),
`drawable(sel)` (draws a stroke on). Everything freezes at final state for print.

To add a chart: write the function, add an `<svg id="…">` inside a `.ph` div on the panel,
register it in `drawAll()`.

---

## 3 · What needs real data

### 3.1 Annual mean temperature, Thessaly and Larisa — `temptime()` · panel 17 · **DONE 2026-10-10**

`data/climate.json` now holds observations (`status: "observed"`): ERA5-Land annual means 1960–2024,
fetched with `R/fetch-openmeteo.R` (Open-Meteo archive API, no account needed; the CDS route in
`R/fetch-era5.R` needs the Keychain password at run time). Thessaly = mean of 35 grid points at 0.2°
inside NUTS-2 EL61; Larisa = the grid cell at 39.64 N 22.42 E. Daily Larisa values are kept in
`data/larissa_daily_era5land.csv` and feed `fig_heatdays()` (days ≥ 35 °C / ≥ 40 °C; R only, not yet
on the wall — panel 17 is full). The headline is now **last decade vs first decade** (+1,3 °C), not
2024 minus 1960: 2024 is the warmest year of the series and a single-year difference (+1,9 °C) would
let it set the number. Grid cells average ~9 km, so the Larisa series runs a little cooler than the
city station. The original brief follows for reference.

Wanted: annual mean 2 m air temperature, **1960–2024**, two series —
(a) Thessaly regional mean, (b) Larisa station or grid cell (39.639 N, 22.419 E).

Sources, best first:

1. **ERA5 / ERA5-Land monthly means** via Copernicus CDS (`reanalysis-era5-land-monthly-means`,
   variable `2m_temperature`). Free with a CDS account. Area for Thessaly roughly
   `[40.2, 21.1, 38.9, 23.4]` (N, W, S, E). Aggregate monthly → annual, and area-average for (a).
   This is the defensible choice: consistent, gridded, no station-move artefacts.
2. **Berkeley Earth** gridded land product — an independent cross-check.
3. **ΕΜΥ / HNMS** station series for Larisa — the authoritative national record, but check for
   station relocations, which are common and will show as step changes.
4. **NOA / meteo.gr** automatic network — dense and current, but only from ~2006, so it cannot
   carry the 1960 baseline. Good for validating the recent end.

Write back into `data/climate.json`:

```json
{
  "status": "observed",
  "series": {
    "_source": "ERA5-Land monthly means, annual mean of 2m temperature",
    "_retrieved": "YYYY-MM-DD",
    "years": [...], "thessaly": [...], "larissa": [...]
  }
}
```

Flip `status` to `"observed"` **only** when both series are real. The stamp and the
caption under the panel heading clear themselves automatically.

Then update the panel footer source line and the `+X,X °C ΣΤΑ 64 ΧΡΟΝΙΑ` annotation — it is
computed from the series, so it follows automatically, but sanity-check the sign and magnitude
(expect roughly +1.5 to +2.0 °C; anything outside that means you aggregated wrong).

### 3.2 Warm extreme — sourced, keep

- **Τρίκαλα 47,2 °C, 10 July 1977** — the highest in Thessaly.
- **Λάρισα 45,0 °C** the same day; **44,9 °C on 2 August 2021** (NOA network).
- **Μακρακώμη 46,3 °C, 2 August 2021** — Fthiotida, just outside Thessaly, among Europe's five
  highest ever. Included as scale, labelled as outside the region.

Worth verifying against the ΕΜΥ archive directly if you can reach it, and worth adding:
number of days per year above 35 °C and above 40 °C at Larisa — that is the figure that actually
communicates the change to a visitor, more than the annual mean does.

### 3.3 Cold-air pooling diagram — `doline()` · panel 17

Schematic, no data needed. The −14 °C ridge / −34 °C basin figures are illustrative of the
mechanism and labelled as such. Leave them, or replace with a real measured profile if you find one.

### 3.4 Coldest place in Thessaly — **UNSOURCED, DELIBERATELY BLANK**

I could not verify a Thessalian cold record, so the panel prints no number for it and says so.
Do not fill this in with an estimate.

Candidates to check, all closed basins or high plateaus where cold air drains and pools:

- **Νευρόπολη Αγράφων** (Karditsa, ~800 m, a closed basin — the strongest candidate)
- **Οροπέδιο Ασπροποτάμου** (Trikala, 1,100–1,300 m)
- **Ελασσόνα** and the Olympus refuges
- Any doline in the Pindus flank of the region

Where to look: the NOA/meteo.gr station network (it has the dense mountain coverage and publishes
station extremes), then ΕΜΥ. Greece's national record, **−35,3 °C at the Kechroti doline on
Mainalo, 17 January 2012**, was set at exactly this kind of landform — so the Thessalian cold pole
is very likely a hole in the ground, not a summit, and a station on a summit will not find it.

When you have it, fill `records.cold` in `data/climate.json` with `place`, `value`, `date`, `src`,
and add a fourth tile to panel 17 mirroring the existing three.

### 3.5 Other numbers already on the wall that would benefit from a better source

| Panel | Figure | Current state |
| --- | --- | --- |
| 13 | Trikala & Sporades 2021 population | Derived from the regional total — replace with the exact ΕΛΣΤΑΤ figures |
| 13 | Population series pre-2011 | Approximate — replace with the exact ΕΛΣΤΑΤ census series |
| 05 | Meteora pillar heights | Marked "≈" — replace with surveyed heights if available |
| 08 | Storm Daniel rainfall | Verify against the NOA event report |

---

## 3.6 · Session log, 10–11 Oct 2026

- Panel 17 series replaced with ERA5-Land observations (`R/fetch-openmeteo.R`); stamp cleared; headline now
  last decade vs first decade; Greek decimal commas fixed in `temptime()`; markers dropped for series > 30 points.
- `fig_heatdays()` added in R (days ≥ 35 / ≥ 40 °C at Larisa). Not on the wall yet — panel 17 has no room.
  If wanted, split the temperature block into two columns or move the doline diagram.
- Cold record checked: Kechroti doline, Mainalo, −35,3 °C on 17 Jan 2012 is an NOA-network reading; the official
  HNMS record is −27,8 °C, Ptolemaida 1963. Suggested wording on the tile: "lowest temperature ever measured in
  Greece", not "official record". The Thessalian cold pole is still unsourced; leave blank.
- Proofing: with the Chrome extension unavailable, use headless Chrome `--print-to-pdf` on the served page and
  `pdftools::pdf_convert(pages = 17)`; a preview of the panel is in `R/out/panel17_preview.png`.
- Captions in R now use Plex Sans (Google's Plex Mono has no Greek). The HTML still declares Plex Mono for labels;
  browsers fall back silently, so check Greek mono labels in the print PDF.

## 4 · Ideas worth plotting that the exhibit does not yet have

Offered as prompts, not instructions — check each is genuinely interesting before building it.

- **Days above 35 °C / 40 °C per year at Larisa.** More legible than annual means.
- **Night-time minima.** Warming nights are the health story, and the plain's basin geometry
  makes them worse. Plot summer T-min alongside T-max.
- **The urban heat island.** Larisa city vs. a rural plain station, same latitude and altitude.
- **Growing-season length** — the agricultural consequence, and this is a farming region.
- **Irrigation water demand vs. rainfall**, tying panel 17 back to panels 06–08 (the river,
  the vanished lake, water and risk). This is the exhibit's strongest through-line.
- **Snow days on Olympus and Pindus over time** — the mountains' version of the same story.

---

## 5 · R — and how to drive it with Claude Code

`R/` is a small, deliberately boring pipeline so a statistician (or Claude) can work in ggplot2
without touching the HTML:

| File | Role |
| --- | --- |
| `R/README.md` | Start here. Quick start, and a table mapping "what you want" → "which file". |
| `R/CLAUDE.md` | The contract. Claude Code reads this automatically. |
| `R/00-setup.R` | Palette, fonts, `theme_thess()`, `gr_num()`, `pt_ok()`, `save_fig()`. |
| `R/01-data.R` | Every dataset, one `d_*` per figure. Reads `data/climate.json`. |
| `R/02-figures.R` | Every figure, one `fig_*()` per chart. Returns a ggplot, no side effects. |
| `R/03-render.R` | The only file that writes. Registers figures, writes `R/out/*.pdf` + `*.svg`. |
| `R/fetch-era5.R` | Pulls the real temperature series from Copernicus and rewrites `data/climate.json`. |

Two things make it safe to hand over unattended:

- **`pt_ok()` errors, it does not warn.** A figure that would print below 12 pt fails the render.
  A silent 7 pt label is exactly the defect that survives review and reaches the printer.
- **The provisional flag is shared.** `R/01-data.R` reads the same `data/climate.json` as the HTML,
  so `fig_temptime()` stamps itself for the same reason panel 17 does — and both clear together
  the moment `fetch-era5.R` writes real observations.

Prompts that work well, because each maps to exactly one file:

> "Add `fig_heatdays()` showing days above 35 °C and 40 °C at Larisa, following the `fig_*` pattern."
> "Replace `d_temp` with real ERA5-Land data using `R/fetch-era5.R`, then re-render panel 17."
> "The Karla figure is too dark for print — adjust `theme_thess(dark=)`, don't touch the figure."

If you rebuild a chart in R, change it in the HTML too — the wall prints from the HTML.

## 5b · SVG export

`export-svg.html` opens the wall in a hidden frame, finds all 16 charts, and downloads each as a
standalone SVG at true size, with a flat background matching its panel and the project fonts
imported. Animation helper classes are stripped, so the files open clean in Illustrator, Inkscape
or Figma. For print, convert text to outlines or install Alegreya and IBM Plex locally.

The two maps are ~2 MB each because they carry the Natural Earth coastline; simplify those paths
if you need lighter files.

---

## 6 · Checklist before printing

- [ ] `data/climate.json` `status` is `"observed"`, no stamp on the chart
- [ ] Every panel footer names its sources
- [ ] No text below 12 pt at final size, SVG included (check effective px after viewBox scaling)
- [ ] Every label ≥ 4.5:1 against its own background, opacity composited
- [ ] All 21 photo slots filled
- [ ] Names, dates and Greek spelling checked by someone local
- [ ] `installation-plan.html` panel count, run lengths and dark-panel list match the deck
- [ ] If figures were rebuilt in R, the HTML panels were updated to match
