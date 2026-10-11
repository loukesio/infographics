# ── Register every figure here; this is the only file that writes to disk. ──
FIGURES <- list(
  "03-peaks"      = fig_peaks,
  "06-river"      = fig_river,
  "07-karla"      = fig_karla,
  "13-population" = fig_pop,
  "14-transhumance" = fig_trans,
  "17-temperature"  = fig_temptime,
  "17-heatdays"     = fig_heatdays
)

render_all <- function(only = NULL) {
  slugs <- if (is.null(only)) names(FIGURES) else only
  for (s in slugs) {
    if (s == "17-heatdays" && is.null(d_heat)) next   # needs R/fetch-openmeteo.R first
    save_fig(FIGURES[[s]](), s)
  }
  invisible(TRUE)
}

render_all()

# ── Animated versions, for a screen loop beside the printed wall ─────────────
# library(gganimate); library(av)
# anim <- fig_karla() + gganimate::transition_reveal(year)
# gganimate::animate(anim, width = 1920, height = 1080, res = 150, fps = 30,
#                    duration = 8, renderer = gganimate::av_renderer("R/out/karla.mp4"))

# ── Maps ────────────────────────────────────────────────────────────────────
# The HTML draws Natural Earth 1:50m with real coordinates on top. In R:
#
# library(sf); library(rnaturalearth)
# coast <- ne_countries(scale = 50, returnclass = "sf")
# ggplot() +
#   geom_sf(data = coast, fill = "#e9e4d4", colour = WATER, linewidth = .2) +
#   coord_sf(xlim = c(21.0, 23.5), ylim = c(38.9, 40.3)) +
#   theme_thess(grid = "none")
#
# Natural Earth 50m does NOT carry the Thessaly administrative boundary.
# For the real NUTS-2 polygon (EL61):
# sf::read_sf(paste0("https://gisco-services.ec.europa.eu/distribution/v2/nuts/",
#                    "geojson/NUTS_RG_01M_2021_4326_LEVL_2.geojson")) |>
#   dplyr::filter(NUTS_ID == "EL61")
