# m30_base.R — shared pieces for the #30DayMapChallenge 2026 series (Thessaly).
# Every day script starts with  source("30daymap/R/m30_base.R")  and is run from thessaly-dataviz/.
#
# One look for the whole series: white paper, Oswald titles, Fira Sans text, a small coloured
# "DAY NN · THEME" tag on top, sources in the caption. Format 8 x 10 in at 300 dpi (4:5, social media).
# Greek text must use Fira Sans (Oswald has no Greek glyphs).

suppressPackageStartupMessages({
  library(dplyr); library(tidyr); library(purrr); library(sf); library(terra)
  library(ggplot2); library(ggtext); library(tidyterra)
})
sf_use_s2(FALSE)

M30_CACHE <- "30daymap/cache"
M30_OUT   <- "30daymap/out"
dir.create(M30_CACHE, showWarnings = FALSE, recursive = TRUE)
dir.create(M30_OUT,   showWarnings = FALSE, recursive = TRUE)
CRS_GR <- 2100                                   # Greek Grid (EGSA87), metres

# ---- colours -------------------------------------------------------------------------------------
M30 <- list(
  paper = "#FFFFFF", ink = "#1E1E1E", soft = "#5E5E5E", mute = "#9A9A9A", line = "#D9D9D9",
  land  = "#F3F1EC", water = "#BFD9E6",
  night = "#0E1116", night_ink = "#ECE8E1", night_mute = "#8C8F96"
)

# ---- geography -----------------------------------------------------------------------------------
# Region border (NUTS-2 EL61) and the four regional units (NUTS-3 EL611..EL614), Eurostat GISCO 2021 1:1M.
m30_nuts <- function(level = 2) {
  f <- sprintf("data/kontur/nuts%d_2021.geojson", level)
  if (!file.exists(f)) download.file(sprintf(paste0(
    "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/",
    "NUTS_RG_01M_2021_4326_LEVL_%d.geojson"), level), f, quiet = TRUE)
  read_sf(f)
}
m30_region <- function(mainland = TRUE) {
  th <- m30_nuts(2) |> filter(NUTS_ID == "EL61") |> st_transform(CRS_GR) |> st_geometry() |> st_cast("POLYGON")
  if (mainland) th <- th[which.max(st_area(th))]
  st_sf(geometry = st_union(th))
}
# The 25 Kallikratis municipalities (GADM 4.1, level 3) and the 5 regional units they make up.
# NUTS-3 2021 merges Karditsa+Trikala, so the units are dissolved from municipalities instead.
M30_UNIT_OF <- c(
  Agia = "Larissa", Elassona = "Larissa", Kileler = "Larissa", Larissa = "Larissa", Tempi = "Larissa",
  Tyrnavos = "Larissa", Farsala = "Larissa",
  Almyros = "Magnesia", Volos = "Magnesia", `Zagora-Mouresi` = "Magnesia", `Notios Pilios` = "Magnesia",
  `Rigas Feraios` = "Magnesia", Alonnisos = "Sporades", Skiathos = "Sporades", Skopelos = "Sporades",
  Trikala = "Trikala", Kalambaka = "Trikala", Pyli = "Trikala", Farkadona = "Trikala",
  Karditsa = "Karditsa", Palamas = "Karditsa", Mouzaki = "Karditsa", Sofades = "Karditsa",
  Argithea = "Karditsa", `Limni Plastiras` = "Karditsa")
m30_municipalities <- function() {
  g <- geodata::gadm("GRC", level = 3, path = M30_CACHE)
  st_as_sf(g) |> filter(NAME_2 == "Thessaly") |> st_transform(CRS_GR) |>
    transmute(municipality = NAME_3, unit = M30_UNIT_OF[NAME_3]) |> st_make_valid()
}
m30_units <- function(mainland = TRUE) {
  u <- m30_municipalities() |> group_by(unit) |> summarise(.groups = "drop") |> rename(name = unit)
  if (mainland) u <- filter(u, name != "Sporades")
  u
}
# Neighbouring Greece for context (grey land around the region)
m30_greece <- function() {
  m30_nuts(2) |> filter(CNTR_CODE == "EL") |> st_transform(CRS_GR) |> st_union() |> st_sf(geometry = _)
}

# Main towns, coordinates of the town centres (same as t12)
m30_towns <- tribble(
  ~name,       ~name_gr,      ~lon,    ~lat,
  "Larissa",   "Λάρισα",      22.4191, 39.6390,
  "Volos",     "Βόλος",       22.9425, 39.3622,
  "Trikala",   "Τρίκαλα",     21.7681, 39.5556,
  "Karditsa",  "Καρδίτσα",    21.9222, 39.3650,
  "Kalambaka", "Καλαμπάκα",   21.6262, 39.7044,
  "Elassona",  "Ελασσόνα",    22.1862, 39.8947,
  "Tyrnavos",  "Τύρναβος",    22.2876, 39.7384,
  "Farsala",   "Φάρσαλα",     22.3836, 39.2950,
  "Almyros",   "Αλμυρός",     22.7589, 39.1806
) |> st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |> st_transform(CRS_GR)

# ---- terrain: Copernicus GLO-90 DEM ----------------------------------------------------------------
# Tiles from the AWS open-data bucket (copernicus-dem-90m), mosaicked, projected to EGSA87, cached.
m30_dem <- function(res = 90, crop = m30_region(TRUE), buffer = 5000) {
  out <- file.path(M30_CACHE, sprintf("dem_%dm.tif", res))
  if (!file.exists(out)) {
    dir.create(file.path(M30_CACHE, "dem"), showWarnings = FALSE)
    tiles <- expand_grid(la = 38:40, lo = sprintf("%03d", 20:23)) |>
      mutate(id = sprintf("Copernicus_DSM_COG_30_N%d_00_E%s_00_DEM", la, lo),
             f = file.path(M30_CACHE, "dem", paste0(id, ".tif")))
    walk2(tiles$id, tiles$f, \(id, f) if (!file.exists(f)) try(download.file(
      sprintf("https://copernicus-dem-90m.s3.amazonaws.com/%s/%s.tif", id, id), f, mode = "wb", quiet = TRUE)))
    d <- sprc(lapply(tiles$f[file.exists(tiles$f)], rast)) |> merge()
    reg <- m30_region(FALSE) |> st_buffer(20000)
    d <- crop(d, vect(st_transform(reg, 4326)))
    d <- project(d, paste0("EPSG:", CRS_GR), res = res, method = "bilinear")
    writeRaster(d, out, overwrite = TRUE)
  }
  d <- rast(out); names(d) <- "elev"
  if (!is.null(crop)) d <- crop(d, vect(st_buffer(crop, buffer)))
  d
}
# Multi-directional hillshade (0..1), softer than a single sun
m30_hillshade <- function(dem, z = 1.5) {
  sl <- terrain(dem * z, "slope", unit = "radians"); as <- terrain(dem * z, "aspect", unit = "radians")
  hs <- map(c(270, 315, 0, 225), \(az) shade(sl, as, angle = 40, direction = az)) |> rast() |> mean()
  names(hs) <- "shade"; hs / 255
}

# ---- OpenStreetMap: Geofabrik Greece extract read with osmextract/GDAL -----------------------------
# The Greece extract (Geofabrik, downloaded 2026-10-29) is translated ONCE into thessaly_osm.gpkg
# (bbox 20.8–24.4 E, 38.8–40.4 N; layers points, lines, multilinestrings, multipolygons, other_relations).
# Tags without their own column live in the hstore text column other_tags; query them in SQL with
#   hstore_get_value(other_tags, 'power') = 'plant'
# where: SQL condition, e.g. "highway IS NOT NULL". clip: keep features touching this polygon (NULL = all).
m30_osm_gpkg <- function() {
  dst <- file.path(M30_CACHE, "thessaly_osm.gpkg")
  if (!file.exists(dst)) {
    pbf <- file.path(M30_CACHE, "greece.osm.pbf")
    if (!file.exists(pbf)) download.file("https://download.geofabrik.de/europe/greece-latest.osm.pbf",
                                         pbf, mode = "wb", quiet = TRUE)
    Sys.setenv(OSM_MAX_TMPFILE_SIZE = "2000")
    for (L in c("points", "lines", "multilinestrings", "multipolygons", "other_relations"))
      gdal_utils("vectortranslate", pbf, dst, options = c("-f", "GPKG", if (file.exists(dst)) c("-update", "-append"),
        "-spat", "20.8", "38.8", "24.4", "40.4", "-nln", L, L, "-oo", "INTERLEAVED_READING=NO"))
  }
  dst
}
m30_osm <- function(layer, where = NULL, clip = m30_region(FALSE)) {
  q <- paste0("SELECT * FROM ", layer, if (!is.null(where)) paste(" WHERE", where))
  x <- read_sf(m30_osm_gpkg(), query = q) |> st_transform(CRS_GR)
  if (!is.null(clip)) x <- x[lengths(st_intersects(x, clip)) > 0, ]
  x
}
`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- theme & titles --------------------------------------------------------------------------------
theme_m30 <- function(dark = FALSE, base = 13) {
  bg <- if (dark) M30$night else M30$paper
  ink <- if (dark) M30$night_ink else M30$ink
  soft <- if (dark) M30$night_mute else M30$soft
  theme_void(base_family = "Fira Sans", base_size = base) +
    theme(
      plot.background  = element_rect(fill = bg, colour = NA),
      panel.background = element_rect(fill = bg, colour = NA),
      plot.margin = margin(30, 36, 22, 36),
      plot.title.position = "plot", plot.caption.position = "plot",
      plot.tag.position = c(0, 1),
      plot.tag = element_markdown(family = "Fira Sans Condensed", size = base * 0.85, colour = soft,
                                  hjust = 0, vjust = 1, margin = margin(0, 0, 0, 0)),
      plot.title = element_markdown(family = "Oswald", face = "bold", size = base * 2.6, colour = ink,
                                    lineheight = 1, margin = margin(26, 0, 8, 0)),
      plot.subtitle = element_textbox_simple(size = base * 1.02, colour = soft, lineheight = 1.3,
                                             margin = margin(0, 0, 14, 0)),
      plot.caption = element_textbox_simple(size = base * 0.68, colour = soft, lineheight = 1.25,
                                            margin = margin(14, 0, 0, 0)),
      legend.position = "top", legend.justification = "left",
      legend.title = element_text(size = base * 0.8, colour = soft),
      legend.text  = element_text(size = base * 0.75, colour = soft),
      text = element_text(colour = ink)
    )
}
# Tag "#30DAYMAPCHALLENGE · DAY 01 · POINTS" with the day theme in the accent colour
m30_labs <- function(day, theme, title, subtitle = NULL, source = NULL, accent = "#C2410C", extra = NULL) {
  labs(
    tag = sprintf("<span style='letter-spacing:2px'>#30DAYMAPCHALLENGE 2026 &nbsp;·&nbsp; DAY %02d &nbsp;·&nbsp; <b style='color:%s'>%s</b></span>",
                  day, accent, toupper(theme)),
    title = title, subtitle = subtitle,
    caption = paste0(if (!is.null(source)) paste0("<b>Data</b> ", source, " &nbsp;·&nbsp; "),
                     if (!is.null(extra)) paste0(extra, " &nbsp;·&nbsp; "),
                     "<b>Map</b> Loukas Theodosiou · #rstats ggplot2")
  )
}
m30_save <- function(p, day, slug, w = 8, h = 10, dpi = 300, bg = NULL) {
  f <- file.path(M30_OUT, sprintf("day%02d_%s.png", day, slug))
  ggsave(f, p, width = w, height = h, dpi = dpi, bg = bg %||% M30$paper, device = ragg::agg_png)
  message("saved ", f); invisible(f)
}
# Scale bar in km for EGSA87 maps (bottom-left by default)
m30_scalebar <- function(km = 20, x = NULL, y = NULL, bbox, col = M30$soft, family = "Fira Sans Condensed") {
  x <- x %||% (bbox["xmin"] + 0.04 * (bbox["xmax"] - bbox["xmin"]))
  y <- y %||% (bbox["ymin"] + 0.03 * (bbox["ymax"] - bbox["ymin"]))
  list(annotate("segment", x = x, xend = x + km * 1000, y = y, yend = y, colour = col, linewidth = 0.6),
       annotate("segment", x = c(x, x + km * 1000), xend = c(x, x + km * 1000), y = y - 800, yend = y + 800,
                colour = col, linewidth = 0.6),
       annotate("text", x = x + km * 500, y = y + 2500, label = paste(km, "km"), family = family,
                size = 3, colour = col))
}
