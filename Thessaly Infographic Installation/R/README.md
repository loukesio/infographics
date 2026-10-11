# ΘΕΣΣΑΛΙΑ — R figure pipeline

Regenerate the exhibit's data figures in R at print size, in the exhibit's own
palette and type. **Designed to be driven by Claude Code.** Point Claude at this
folder and it has everything it needs: the visual contract, the data contracts,
and one function per figure.

## Quick start

```r
install.packages(c("ggplot2","dplyr","tibble","scales","showtext","sysfonts",
                   "sf","rnaturalearth","rnaturalearthdata","jsonlite","glue"))
# optional, for the screen loop:
install.packages(c("gganimate","av"))

source("R/00-setup.R")    # palette, fonts, theme, save helpers
source("R/01-data.R")     # every dataset, one object per figure
source("R/02-figures.R")  # every figure, one fig_*() per chart
source("R/03-render.R")   # writes out/*.pdf and out/*.svg
```

Output lands in `R/out/`.

## Driving this with Claude Code

Ask in these terms — each maps to exactly one place in the code:

| You want | Say | It edits |
| --- | --- | --- |
| A new figure | "add fig_heatdays() following the fig_* pattern" | `02-figures.R` + `03-render.R` |
| Real data behind a figure | "replace d_temp with ERA5-Land, see HANDOFF.md §3.1" | `01-data.R` only |
| A restyle | "change the theme, not the figures" | `00-setup.R` only |
| A different output size | "render at 40x30cm" | `03-render.R` only |

**The contract Claude must not break** (also stated in `R/CLAUDE.md`, which
Claude Code reads automatically):

1. Only the palette in `00-setup.R`. No new colours, no viridis, no default ggplot blue.
2. `theme_thess()` on every figure. Never `theme_minimal()` raw.
3. Greek label first, English second. Greek number format: `gr_num()` → `688.255`, `47,2`.
4. Nothing below 12 pt at final size — see `pt_ok()`, which asserts this and errors out.
5. Every figure carries its source in `labs(caption=)`. No source, no figure.
6. Data lives in `01-data.R` or `data/*.json`. Never inline inside a `fig_*()`.

## Relationship to the HTML

`thessaly.html` is the layout master — it is what gets printed. This pipeline
exists to (a) produce publication-grade vector versions of the data figures,
(b) let a statistician work in a familiar tool, and (c) regenerate everything
when the real data lands. If you change a figure here, change it there too.
`../HANDOFF.md` lists which datasets are still provisional.
