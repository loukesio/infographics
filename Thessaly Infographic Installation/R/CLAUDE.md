# Contract for this folder

You are working on figures for a printed wall exhibit (B1, 70x100cm, read from
1.5-3m, Greek primary / English secondary). Read `R/README.md` first.

## Never
- Introduce a colour outside the palette in `00-setup.R`.
- Use a raw ggplot theme. Always `theme_thess()`.
- Put data inside a `fig_*()` function. Data goes in `01-data.R`.
- Print a number you cannot source. Leave it out and say so in the caption.
- Emit text below 12 pt at final size. `pt_ok()` will error; do not suppress it.
- Hard-code a foreground colour over a background that varies. If the fill is conditional, the
  label colour must branch on the same condition — see `fig_peaks()`, where the region label
  follows `thess`. `contrast_ok()` checks this; it errors rather than warns.

## Always
- One `fig_*()` per figure, returning a ggplot object. No side effects.
- Greek first in every label, English second where it helps a visitor.
- Greek numerals: thousands `.`, decimal `,` — use `gr_num()`.
- A `caption` naming the source.
- Contrast of at least 4.5:1 between any text and what sits behind it. Composite alpha first —
  `alpha(INK2, .38)` over paper is a light grey, not a dark one.
- Register new figures in `03-render.R`.

## Data status
`d_temp` is real (ERA5-Land via `R/fetch-openmeteo.R`, 2026-10-10). `d_heat` (daily Larisa) feeds
`fig_heatdays()`. Captions use Plex Sans, not Plex Mono: Google's IBM Plex Mono has no Greek glyphs.
