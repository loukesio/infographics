# ── Palette, type, theme, and the print-safety helpers ───────────────────────
suppressPackageStartupMessages({
  library(ggplot2); library(dplyr); library(tibble); library(scales)
  library(showtext); library(sysfonts); library(glue)
})

# Palette — the ONLY colours allowed in this project.
PAPER <- "#f2eee3"; PAPER2 <- "#e7e1d1"; INK  <- "#191713"; INK2  <- "#4a463d"
MUTE  <- "#8b8474"; RULE   <- "#c7bfa9"; RED  <- "#b3241f"; TEAL  <- "#1c4b52"
OCHRE <- "#c08a1e"; WHEAT  <- "#d9bd6a"; DEEP <- "#141d1c"; WATER <- "#2b6b76"
SNOW  <- "#dfe6e4"; OLIVE  <- "#5c6139"
PALETTE <- c(PAPER, PAPER2, INK, INK2, MUTE, RULE, RED, TEAL, OCHRE, WHEAT,
             DEEP, WATER, SNOW, OLIVE)

font_add_google("Alegreya", "alegreya")          # display, numerals
font_add_google("IBM Plex Sans", "plex")         # body
font_add_google("IBM Plex Mono", "plexmono")     # labels, data
showtext_auto(); showtext_opts(dpi = 300)

# ── Print safety ────────────────────────────────────────────────────────────
# A figure is rendered at a known physical width. Anything under 12 pt is
# unreadable on the wall, so this errors rather than warns: a silent 7 pt label
# is exactly the defect that survives review and reaches the printer.
PT_MIN <- 12
pt_ok <- function(size_pt, what = "label") {
  if (any(size_pt < PT_MIN))
    stop(glue("{what}: {round(min(size_pt),1)} pt is below the {PT_MIN} pt floor. ",
              "Raise it or drop the element."), call. = FALSE)
  invisible(TRUE)
}

# Contrast, on the same principle as pt_ok(): a pale label is as unreadable at
# 3 m as a small one. Composite alpha yourself before calling — alpha(INK2,.38)
# over paper is a LIGHT grey, and that exact case shipped a 1.9:1 label twice.
rel_lum <- function(hex) {
  v <- grDevices::col2rgb(hex)[, 1] / 255
  v <- ifelse(v <= 0.03928, v / 12.92, ((v + 0.055) / 1.055) ^ 2.4)
  sum(c(0.2126, 0.7152, 0.0722) * v)
}
contrast <- function(fg, bg) {
  a <- rel_lum(fg); b <- rel_lum(bg)
  (max(a, b) + 0.05) / (min(a, b) + 0.05)
}
composite <- function(fg, bg, alpha)
  grDevices::rgb(t(grDevices::col2rgb(fg) * alpha +
                   grDevices::col2rgb(bg) * (1 - alpha)), maxColorValue = 255)

CONTRAST_MIN <- 4.5
contrast_ok <- function(fg, bg, what = "label") {
  r <- contrast(fg, bg)
  if (r < CONTRAST_MIN)
    stop(glue("{what}: {round(r,2)}:1 against {bg} is below {CONTRAST_MIN}:1. ",
              "If the background varies, branch the foreground on the same flag."),
         call. = FALSE)
  invisible(r)
}

# ── Greek number formatting ─────────────────────────────────────────────────
gr_num <- function(x, dec = 0)
  formatC(x, format = "f", digits = dec, big.mark = ".", decimal.mark = ",")

# ── Theme ───────────────────────────────────────────────────────────────────
# base is in POINTS at final size. 13 keeps body labels just over the floor;
# do not lower it.
theme_thess <- function(base = 13, dark = FALSE, grid = "y") {
  pt_ok(base * 0.95, "theme base")
  bg <- if (dark) DEEP else PAPER
  fg <- if (dark) PAPER else INK
  mu <- if (dark) "#8d8b7e" else MUTE
  ru <- if (dark) "#39423f" else RULE
  theme_minimal(base_size = base, base_family = "plex") %+replace%
    theme(
      plot.background   = element_rect(fill = bg, colour = NA),
      panel.background  = element_rect(fill = bg, colour = NA),
      panel.grid.minor  = element_blank(),
      panel.grid.major.y = if (grid %in% c("y","both")) element_line(colour = ru, linewidth = .25) else element_blank(),
      panel.grid.major.x = if (grid %in% c("x","both")) element_line(colour = ru, linewidth = .25) else element_blank(),
      axis.text   = element_text(family = "plexmono", colour = mu, size = rel(0.95)),
      axis.title  = element_blank(),
      axis.ticks  = element_blank(),
      legend.position = "none",
      plot.title    = element_text(family = "alegreya", face = "bold", colour = fg,
                                   size = rel(2.2), hjust = 0,
                                   margin = margin(b = base * .5)),
      plot.subtitle = element_text(family = "plex", colour = mu, size = rel(1.0),
                                   hjust = 0, margin = margin(b = base * .9)),
      # IBM Plex Mono (Google build) carries no Greek: a Greek caption in it renders as boxes.
      plot.caption  = element_text(family = "plex", colour = mu, size = rel(0.92),
                                   hjust = 0, margin = margin(t = base * .9)),
      plot.title.position = "plot",
      plot.caption.position = "plot",
      plot.margin = margin(base, base, base, base)
    )
}

# A visible stamp for any figure drawn from unsourced data.
stamp_provisional <- function(p)
  p + annotate("label", x = -Inf, y = Inf, hjust = -0.05, vjust = 1.4,
               label = "ΠΡΟΣΩΡΙΝΑ ΔΕΔΟΜΕΝΑ — ΜΗΝ ΕΚΤΥΠΩΘΕΙ",
               family = "plexmono", size = 5, colour = RED,
               fill = NA, label.size = 0.5)

# ── Output ──────────────────────────────────────────────────────────────────
# A figure filling half a B1 panel is about 33 x 25 cm. Both a vector PDF (for
# the printer) and an SVG (for dropping back into the HTML panels).
save_fig <- function(plot, slug, w = 33, h = 22) {
  dir.create("R/out", showWarnings = FALSE, recursive = TRUE)
  ggsave(glue("R/out/{slug}.pdf"), plot, width = w, height = h,
         units = "cm", device = cairo_pdf)
  ggsave(glue("R/out/{slug}.svg"), plot, width = w, height = h, units = "cm")
  message(glue("wrote R/out/{slug}.pdf + .svg"))
  invisible(plot)
}
