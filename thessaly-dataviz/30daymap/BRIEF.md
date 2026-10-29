# #30DayMapChallenge 2026 — Thessaly series: brief for every day

Owner: Loukas Theodosiou (data scientist, from Larissa). Read `thessaly-dataviz/CLAUDE.md` §1 for his taste.
One map per day, all about Thessaly / Larissa, all in one family look. Work from `thessaly-dataviz/` as the R working dir.

## Hard rules
1. **Never invent data.** Every number, line and point comes from a named, downloadable source; put the source (with
   year) in the caption and a URL in the notes. If a source cannot be reached, try the fallback listed for the day;
   if that fails too, stop and write that in the notes — do not fake it. No "illustrative" values.
2. **Title = the finding**, computed from the data (e.g. "A third of Thessaly's villages sit above 500 m"). Compute
   the number in the script and print it with message() so it can be checked. Subtitle explains in plain words how
   to read the map. Short, plain English.
3. **Look matters most.** Cédric Scherer / Jake Kaupp / award-winner quality: white paper, lots of air, a strong
   single idea, restrained colour (one accent + greys, or one sequential palette), direct labels instead of legends
   where possible, fine hairlines, no default ggplot grey, no rainbow, no red-green. Label 4–8 towns or features at most,
   never clutter. Use `shadowtext` or white halos for labels over busy rasters.
4. **Always render the PNG and look at it** (Read the PNG) — check: overlapping labels, text leaving shapes,
   title/subtitle collisions, legend colours matching, big empty areas, readable at phone size. Iterate at least twice.
   Only stop when it looks publishable.
5. Fonts: Oswald (titles, English only), Fira Sans / Fira Sans Condensed (all text; **Greek only in Fira Sans** —
   Oswald and Playfair have no Greek glyphs). Playfair Display / Cormorant Garamond allowed for a vintage title (Latin).

## Shared code — use it, do not edit it
`30daymap/R/m30_base.R` (read it first). Start every script with
```r
source("30daymap/R/m30_base.R")
```
It gives: `m30_region()` (mainland border, EGSA87 EPSG:2100), `m30_region(FALSE)` (with Sporades),
`m30_municipalities()` (25 Kallikratis municipalities, GADM 4.1, with `unit`), `m30_units()` (Larissa, Magnesia,
Trikala, Karditsa), `m30_greece()`, `m30_towns` (9 towns, real coordinates, Greek names), `m30_dem()` (Copernicus
GLO-90, cached, 90 m), `m30_hillshade(dem)`, `m30_osm(layer, where, clip)` (OSM Geofabrik extract of 2026-10-28, already
in `30daymap/cache/thessaly_osm.gpkg`; non-column tags via `hstore_get_value(other_tags,'key')`), `theme_m30(dark)`,
`m30_labs(day, theme, title, subtitle, source, accent, extra)` (puts the "#30DAYMAPCHALLENGE 2026 · DAY NN · THEME" tag,
title, subtitle, caption), `m30_save(p, day, slug, w, h)` (300 dpi, ragg), `m30_scalebar()`, colours in `M30`.
If you need a helper, write it inside your own script. Cache downloads in `30daymap/cache/<your-folder>/`.
Put small derived data you want to keep (CSV < 2 MB) in `30daymap/data/`.

## Canvas
Default 8 × 10 in (4:5, Instagram/Bluesky). Thessaly is wider than tall, so either use the space under/next to the map
for a second element (a small strip chart, ranked bars, a key, a locator inset, an annotation column), or choose
another size (e.g. 10 × 8, 9 × 9). No big empty bands. Pick per day an accent colour that suits the theme.
Dark backgrounds only where the theme asks for it (Light & dark, night, raster glow): `theme_m30(dark = TRUE)`.

## Output per day (exact names)
- script: `30daymap/scripts/dayNN_<slug>.R` (self-contained, runs with `Rscript` from thessaly-dataviz/, downloads and
  caches its own data, comments in the style of the existing scripts: a header with title, data sources + URLs,
  caveats; short section comments `# ---- 1. data ----`)
- image: `30daymap/out/dayNN_<slug>.png`
- notes: `30daymap/notes/dayNN.md` with exactly these headings:
  `# Day NN · Theme — Title`, `**Idea**` (2–3 sentences), `**Data**` (source, year, URL, licence),
  `**How**` (2–4 bullets: method, key packages), `**Finding**` (the computed number(s)), `**Caveats**`,
  `**Status**` (done / needs Loukas: …).

## Do not
- do not commit or push, do not edit README.md, gallery.html, CLAUDE.md or m30_base.R;
- do not touch other days' files; do not install fonts; install CRAN packages only if really needed;
- do not run rayshader high-quality renders longer than ~10 min.

## Reporting back
A short summary per day: file names, the title, the finding number, the source, anything that failed or needs
Loukas. Plain words.
