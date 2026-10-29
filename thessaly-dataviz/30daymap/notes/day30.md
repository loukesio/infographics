# Day 30 · Pen & paper — (title to be written by hand)

**Idea**
Loukas draws this map himself. The script only makes the paper: an A4 portrait drawing sheet with a faint
Thessaly outline, the 25 municipality borders very light, the 9 towns as small dots, a 10 km grid in Greek Grid
metres, the series title strip and a key/notes box. After drawing, the scan is framed in the series look.

**Data**
- Region border: Eurostat GISCO NUTS 2021 (EL61) — https://gisco-services.ec.europa.eu/distribution/v2/nuts/ — © EuroGeographics.
- Municipalities: GADM 4.1 level 3 — https://gadm.org — free for non-commercial use.
- Towns: `m30_towns` (town-centre coordinates in `m30_base.R`).

**How**
- Mainland only (Sporades left out to give the mainland the sheet); grid snapped to whole 10 km lines of EPSG:2100,
  stretched north–south to 22 × 25 squares to fill the page; edge labels in km.
- ggplot2 + patchwork; saved as vector PDF (`cairo_pdf`) and 300 dpi PNG at 210 × 297 mm.
- Files: `out/day30_pen_paper_template.pdf`, `out/day30_pen_paper_template.png`.

**Finding**
- Mainland Thessaly fits in 191 × 137 km: about 19 × 14 squares of the grid.

**Caveats**
- Print at 100 % ("actual size") so the 20 km scale bar stays true; the grid squares are 10 km whatever the print scale.
- This is a template, not the Day 30 map. No hand-drawn look was faked.

**Status**
needs Loukas: print the PDF, draw the map by hand, scan it (300 dpi+), then we frame the scan with the series tag, title and caption.
