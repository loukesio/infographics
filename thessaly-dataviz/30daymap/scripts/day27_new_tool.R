# Day 27 · New tool — Olympus, the Vale of Tempe and Ossa in 3D with mapgl (MapLibre GL JS from R)
# New in this project: mapgl (Kyle Walker) drives MapLibre GL JS — real 3D terrain in the browser, no token.
# The 3D scene is saved as an HTML widget, photographed with headless Chrome (webshot2/chromote), then framed
# in the series look with magick + ggplot2.
#
# Data
#   Terrain in the 3D view: Mapzen/AWS Terrarium elevation tiles (open, https://registry.opendata.aws/terrain-tiles/)
#   Base style: OpenFreeMap Positron (OpenMapTiles, © OSM) + MapLibre hillshade from the Terrarium tiles
#   Numbers in the title: Copernicus GLO-90 DEM via m30_dem() (ESA, © DLR / Airbus, free licence)
#   Peaks + heights: OpenStreetMap natural=peak with ele tag, re-extracted from the Geofabrik Greece extract
#     (2026-10-28) with a copy of GDAL's osmconf.ini in which ele is not ignored -> 30daymap/cache/day27/peaks.gpkg
#   River: OSM waterway=river "Πηνειός" (m30_osm) · border: Eurostat GISCO NUTS-2 2021
# Caveats
#   * GLO-90 is a 90 m grid: it smooths the summit, so the DEM top of Olympus is lower than the surveyed
#     2,917.7 m in OSM. The relief in the title uses the DEM for both ends; the OSM height is quoted separately.
#   * 3D view is vertically exaggerated 1.4x (said on the image).
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(mapgl); library(htmlwidgets) })
dir.create(file.path(M30_CACHE, "day27"), showWarnings = FALSE)

# ---- 1. data: peaks with their OSM height ----
peaks_f <- file.path(M30_CACHE, "day27", "peaks.gpkg")
if (!file.exists(peaks_f)) {
  conf <- readLines(system.file("gdal/osmconf.ini", package = "sf"))
  conf <- gsub(",ele,", ",", conf, fixed = TRUE)                       # stop ignoring ele
  i <- grep("^attributes=name,barrier", conf)[1]; conf[i] <- paste0(conf[i], ",natural,ele")
  cf <- normalizePath(file.path(M30_CACHE, "day27", "osmconf_ele.ini"), mustWork = FALSE); writeLines(conf, cf)
  m30_osm_gpkg()                                                       # makes sure the pbf is there
  gdal_utils("vectortranslate", file.path(M30_CACHE, "greece.osm.pbf"), peaks_f,
             options = c("-f", "GPKG", "-overwrite", "-oo", paste0("CONFIG_FILE=", cf),
                         "-spat", "20.8", "38.8", "24.4", "40.4", "-where", "natural IN ('peak','mountain_range')", "-nln", "peaks", "points"))
}
peaks <- read_sf(peaks_f) |> mutate(ele = suppressWarnings(as.numeric(ele)),
                                    en = stringr::str_match(other_tags, '"name:en"=>"([^"]+)"')[, 2]) |>
  st_transform(CRS_GR)
top_near <- function(lon, lat, km) {
  p <- st_sfc(st_point(c(lon, lat)), crs = 4326) |> st_transform(CRS_GR)
  peaks[as.numeric(st_distance(peaks, p)) < km * 1000 & !is.na(peaks$ele), ] |> slice_max(ele, n = 1, with_ties = FALSE)
}
mytikas <- peaks |> filter(name == "Μύτικας", ele > 2900)
# OSM maps the Ossa summit not as a peak but as a natural=mountain_range node named Όσσα at the top
ossa    <- peaks |> filter(name == "Όσσα", natural == "mountain_range", !is.na(ele))
message(sprintf("OSM: %s %s m · Ossa top: %s (%s) %s m", mytikas$name, mytikas$ele, ossa$name, ossa$en, ossa$ele))

# ---- 2. the finding: Pineios in the gorge vs the summit, both from GLO-90 ----
dem <- m30_dem(crop = NULL)
pin <- m30_osm("lines", "waterway = 'river' AND name = 'Πηνειός'", clip = NULL)
tempe_box <- st_as_sfc(st_bbox(c(xmin = 22.53, xmax = 22.60, ymin = 39.86, ymax = 39.92), crs = 4326)) |>
  st_transform(CRS_GR)
pin_t <- st_intersection(st_union(pin), tempe_box)
pp <- st_line_sample(st_cast(pin_t, "LINESTRING"), density = 1 / 90) |> st_cast("POINT") |> st_sf()
pp$z <- terra::extract(dem, vect(pp))$elev
river_lo <- min(pp$z, na.rm = TRUE); river_hi <- max(pp$z, na.rm = TRUE)
summit_dem <- terra::extract(dem, vect(st_buffer(mytikas, 500)), fun = max)$elev
low_pt <- pp[which.min(pp$z), ]
dist_km <- as.numeric(st_distance(low_pt, mytikas)) / 1000
relief <- summit_dem - river_lo
message(sprintf("Pineios in Tempe (DEM): %.0f–%.0f m · Mytikas DEM max %.0f m (OSM %s m) · relief %.0f m over %.1f km",
                river_lo, river_hi, summit_dem, mytikas$ele, relief, dist_km))
message(sprintf("Relief with the OSM summit height: %.0f m", mytikas$ele - river_lo))

# ---- 3. the 3D map ----
to84 <- \(x) st_transform(x, 4326)
lab <- bind_rows(
  tibble(label = sprintf("MYTIKAS · OLYMPUS\n%s m", format(mytikas$ele, big.mark = ",")), geometry = st_geometry(to84(mytikas))),
  tibble(label = sprintf("OSSA · KISSAVOS\n%s m", format(ossa$ele, big.mark = ",")),
         geometry = st_geometry(to84(ossa))),
  tibble(label = "VALE OF TEMPE\nPineios", geometry = st_geometry(to84(low_pt)))) |> st_sf()
pin84 <- to84(st_sf(geometry = st_union(pin)))
reg84 <- to84(m30_region(TRUE)) |> st_cast("MULTILINESTRING")

# A minimal own style: sea background, the Terrarium DEM (terrain + hillshade) and OpenFreeMap glyphs.
# The DEM lives in the style itself because mapgl's raster-dem helper passes only a TileJSON url to MapLibre
# (no tiles array, no encoding), so Terrarium tiles cannot be added through it.
dem_src <- list(type = "raster-dem", encoding = "terrarium", tileSize = 256, maxzoom = 14,
                tiles = list("https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"),
                attribution = "Terrain: Mapzen Terrarium tiles (AWS Open Data)")
style <- list(version = 8, glyphs = "https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf",
              sources = list(dem = dem_src, dem_hs = dem_src),
              terrain = list(source = "dem", exaggeration = 1.4),
              layers = list(
                list(id = "landbg", type = "background", paint = list("background-color" = "#F3F1EC")),
                list(id = "hills", type = "hillshade", source = "dem_hs",
                     paint = list("hillshade-shadow-color" = "#4A5560", "hillshade-highlight-color" = "#FFFFFF",
                                  "hillshade-accent-color" = "#7D8890", "hillshade-exaggeration" = 0.75,
                                  "hillshade-illumination-direction" = 315))))
# sea = a box around the view minus the land (GISCO NUTS 2021, all of Greece); drawn on top of the hillshade
box84 <- st_as_sfc(st_bbox(c(xmin = 21.3, xmax = 24.4, ymin = 39.2, ymax = 40.9), crs = 4326))
sea84 <- st_difference(box84, st_union(to84(m30_greece()))) |> st_sf(geometry = _)
m <- maplibre(style = style, center = c(22.46, 39.94), zoom = 10.3,
              pitch = 62, bearing = 50, projection = "mercator") |>
  add_fill_layer(id = "sea", source = sea84, fill_color = "#D3E3EC", fill_opacity = 1) |>
  add_line_layer(id = "border", source = reg84, line_color = "#1E1E1E", line_width = 1.1,
                 line_opacity = 0.55, line_dasharray = c(2, 2)) |>
  add_line_layer(id = "pineios", source = pin84, line_color = "#2C7FB8", line_width = 3) |>
  add_symbol_layer(id = "labels", source = lab, text_field = get_column("label"),
                   text_font = list("Noto Sans Bold"), text_size = 15, text_color = "#1E1E1E",
                   text_halo_color = "rgba(255,255,255,0.9)", text_halo_width = 1.6, text_line_height = 1.15,
                   text_anchor = "bottom", text_offset = c(0, -0.6), text_allow_overlap = TRUE,
                   text_letter_spacing = 0.06) |>
  add_circle_layer(id = "dots", source = lab, circle_radius = 4, circle_color = "#1E1E1E",
                   circle_stroke_color = "#FFFFFF", circle_stroke_width = 1.2)
html <- file.path(normalizePath(M30_OUT), "day27_new_tool.html")
saveWidget(m, html, selfcontained = TRUE, title = "Olympus–Tempe–Ossa in 3D · #30DayMapChallenge Day 27")
unlink(file.path(M30_OUT, "day27_new_tool_files"), recursive = TRUE)

# ---- 4. screenshot with headless Chrome (CLI, GPU) ----
shot <- file.path(M30_CACHE, "day27", "screenshot.png")
# Chrome's own CLI with the Metal GPU: chromote/webshot2 (SwiftShader) left whole terrain tiles flat.
chrome <- "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
prof <- file.path(tempdir(), "chrome_prof")
system2(chrome, c("--headless=new", "--use-angle=metal", "--enable-gpu", "--ignore-gpu-blocklist",
                  "--window-size=1200,1000", "--force-device-scale-factor=2", "--hide-scrollbars",
                  "--virtual-time-budget=40000", paste0("--user-data-dir=", prof),
                  paste0("--screenshot=", normalizePath(dirname(shot)), "/", basename(shot)),
                  paste0("file://", html)), stdout = FALSE, stderr = FALSE)

# ---- 5. frame ----
img <- magick::image_read(shot)
# trim the far horizon (open sea and Chalkidiki) so the mountains fill the frame
img <- magick::image_crop(img, sprintf("%dx%d+0+%d", magick::image_info(img)$width,
                                       magick::image_info(img)$height - 440, 440))
ii <- magick::image_info(img)
acc <- "#2C7FB8"
p <- ggplot() +
  annotation_raster(as.raster(img), xmin = 0, xmax = ii$width, ymin = 0, ymax = ii$height) +
  coord_fixed(xlim = c(0, ii$width), ylim = c(0, ii$height), expand = FALSE) +
  m30_labs(27, "New tool",
           title = sprintf("From the river to the gods: %s m<br>in %.0f km", format(round(relief), big.mark = ","), dist_km),
           subtitle = sprintf(paste0(
             "The Pineios slips through the Vale of Tempe at about %.0f m above sea level. %.0f km away, ",
             "<b>Mytikas</b>, the top of Olympus, stands at %s m (OSM). Ossa guards the other side of the gorge. ",
             "Looking north-east, towards the Aegean."),
             river_lo, dist_km, format(mytikas$ele, big.mark = ",")),
           source = paste("Copernicus GLO-90 DEM (numbers) · Terrarium terrain tiles, AWS Open Data (3D) ·",
                          "© OpenStreetMap contributors (Geofabrik 2026-10-28)"),
           accent = acc,
           extra = paste0("<b>New tool: mapgl</b> (Kyle Walker) = MapLibre GL JS from R, 3D terrain, no token; ",
                          "screenshot with headless Chrome. Vertical exaggeration 1.4×. Relief = GLO-90 summit (",
                          round(summit_dem), " m) minus lowest river cell in Tempe")) +
  theme_m30()
m30_save(p, 27, "new_tool", w = 8, h = 8.4)
