# Day 28 · Feeling — how hot it felt on the worst day of the August 2021 heatwave
# Map of ERA5 daily maximum "apparent temperature" (feels-like: air temperature + humidity + wind, as
# computed by Open-Meteo) on the hottest day of the late-July / early-August 2021 heatwave, interpolated
# smoothly between ERA5 grid points and clipped to Thessaly. A strip below counts days ≥ 40 °C in Larissa
# per decade 1960–2024 (ERA5-Land air temperature, not feels-like) for context.
#
# Data
#   * ERA5 reanalysis (Copernicus/ECMWF) via the Open-Meteo historical weather API, models=era5,
#     daily apparent_temperature_max on the native 0.25° ERA5 grid (88 cell centres, 21.0–23.5 E, 38.75–40.5 N),
#     25 Jul – 8 Aug 2021. https://archive-api.open-meteo.com/v1/archive  (CC BY 4.0)
#     One multi-location request, cached in 30daymap/cache/heat2021/era5_apparent_grid.json
#   * Larissa daily ERA5-Land tmax 1960–2024 (Open-Meteo, grid cell 39.64 N 22.42 E), from the exhibit project:
#     ../Thessaly Infographic Installation/data/larissa_daily_era5land.csv
#   * Border: Eurostat GISCO NUTS 2021; DEM hillshade: Copernicus GLO-90 (via m30_base.R)
#
# Caveats
#   * ERA5 cells are ~25 km wide: the map is smooth by design and misses town heat islands; values are
#     grid-cell values, not station readings. Interpolation = bilinear between the 0.25° cell centres (no overshoot), 500 m output.
#   * Apparent temperature is Open-Meteo's formula (Steadman-type), not the Greek met office's index.
#   * The day is chosen from the data: the day with the highest mean feels-like maximum over all points.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(jsonlite); library(shadowtext); library(patchwork) })

# ---- 1. data: ERA5 points -------------------------------------------------------------------------
cdir <- file.path(M30_CACHE, "heat2021"); dir.create(cdir, showWarnings = FALSE)
reg  <- m30_region()
# full rectangle of native 0.25° ERA5 cell centres (11 x 8 = 88), so bilinear interpolation has neighbours
pts  <- expand_grid(lon = seq(21, 23.5, .25), lat = seq(38.75, 40.5, .25)) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE)
inreg <- lengths(st_intersects(pts, st_transform(st_buffer(reg, 8000), 4326))) > 0   # 32 points near the region

jf <- file.path(cdir, "era5_apparent_grid.json")
if (!file.exists(jf)) {
  url <- paste0("https://archive-api.open-meteo.com/v1/archive?latitude=", paste(pts$lat, collapse = ","),
                "&longitude=", paste(pts$lon, collapse = ","),
                "&start_date=2021-07-25&end_date=2021-08-08&daily=apparent_temperature_max,temperature_2m_max",
                "&models=era5&timezone=Europe%2FAthens")
  for (a in 1:5) {
    ok <- tryCatch({ download.file(url, jf, quiet = TRUE); TRUE }, error = \(e) FALSE)
    if (ok) break
    message("Open-Meteo refused (attempt ", a, "), waiting ", 45 * a, " s"); Sys.sleep(45 * a)
  }
}
js <- fromJSON(jf, simplifyVector = FALSE)
era <- map2_dfr(js, seq_along(js), \(r, i) tibble(
  i = i, lon = pts$lon[i], lat = pts$lat[i], inreg = inreg[i],
  date = as.Date(unlist(r$daily$time)),
  app = as.numeric(unlist(r$daily$apparent_temperature_max)),
  tmax = as.numeric(unlist(r$daily$temperature_2m_max))))

# hottest day = highest mean feels-like maximum over the 32 points in and around the region
daily <- era |> filter(inreg) |> group_by(date) |> summarise(app = mean(app), tmax = mean(tmax), .groups = "drop")
day   <- daily$date[which.max(daily$app)]
d1    <- era |> filter(date == day)
message("Hottest day (mean of ", sum(d1$inreg), " ERA5 points): ", day, ", mean feels-like max ",
        round(max(daily$app), 1), " °C")

# ---- 2. bilinear interpolation of the ERA5 grid to 500 m, clipped -------------------------------------
# (bilinear: never overshoots the grid values, unlike a spline; the 25 km grid shows as soft facets)
r0 <- rast(xmin = 20.875, xmax = 23.625, ymin = 38.625, ymax = 40.625, resolution = .25, crs = "EPSG:4326")
r0[cellFromXY(r0, cbind(d1$lon, d1$lat))] <- d1$app
dem <- m30_dem(crop = reg, buffer = 3000)
g   <- project(r0, rast(ext(dem), resolution = 500, crs = crs(dem)), method = "bilinear")
g   <- mask(g, vect(reg)); names(g) <- "app"
gdf <- as.data.frame(g, xy = TRUE, na.rm = TRUE)

# hottest spot = hottest ERA5 cell centre in the region (raw value, not interpolated)
rawmax <- d1 |> filter(inreg) |> slice_max(app, n = 1)
pk_pt <- st_as_sf(rawmax, coords = c("lon", "lat"), crs = 4326) |> st_transform(CRS_GR)
pk <- tibble(x = st_coordinates(pk_pt)[, 1], y = st_coordinates(pk_pt)[, 2], app = rawmax$app)
pk_mun <- m30_municipalities()$municipality[st_nearest_feature(pk_pt, m30_municipalities())]
lo <- gdf[which.min(gdf$app), ]
message(sprintf("Map max %.1f °C (municipality %s); hottest ERA5 cell %.1f °C at %.2f N %.2f E; ",
                max(gdf$app), pk_mun, rawmax$app, rawmax$lat, rawmax$lon),
        sprintf("coolest %.1f °C", lo$app))
share40 <- mean(gdf$app >= 40) * 100
message(sprintf("Share of the region with feels-like max >= 40 °C: %.0f%%", share40))

# hillshade for texture
hs <- m30_hillshade(aggregate(dem, 3)) |> mask(vect(reg))
hsd <- as.data.frame(hs, xy = TRUE, na.rm = TRUE)

# ---- 3. Larissa days >= 40 °C per decade ------------------------------------------------------------
lar <- read.csv("../Thessaly Infographic Installation/data/larissa_daily_era5land.csv") |>
  mutate(date = as.Date(date), yr = as.integer(format(date, "%Y")))
dec <- lar |> filter(yr <= 2019) |> mutate(dec = paste0(yr %/% 10 * 10, "s")) |>
  group_by(dec) |> summarise(d40 = sum(tmax >= 40) / n_distinct(yr), .groups = "drop")
last5 <- lar |> filter(yr >= 2020) |> summarise(d40 = sum(tmax >= 40) / n_distinct(yr)) |> pull(d40)
message("Larissa days >= 40 °C per decade: ", paste(dec$dec, round(dec$d40, 1), collapse = "; "), "; 2020–2024: ", last5, " (days per year)")

# ---- 4. plot ----------------------------------------------------------------------------------------
acc  <- "#B42318"
brks <- seq(floor(min(gdf$app) / 2) * 2, ceiling(max(gdf$app) / 2) * 2, 2)
heat <- colorRampPalette(c("#FFF1D6", "#FBD38D", "#F6A04D", "#E8613C", "#C0392B", "#7A1E2B", "#3D0C1C"))
bb <- st_bbox(reg)
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Kalambaka", "Farsala", "Elassona")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2],
         v = terra::extract(g, cbind(x, y))[, 1])

map <- ggplot() +
  geom_contour_filled(data = gdf, aes(x, y, z = app), breaks = brks) +
  geom_raster(data = hsd, aes(x, y, alpha = 1 - shade), fill = "#2B0A12", show.legend = FALSE) +
  scale_alpha(range = c(0, .32)) +
  geom_contour(data = gdf, aes(x, y, z = app), breaks = brks, colour = "white", linewidth = .18, alpha = .7) +
  geom_sf(data = reg, fill = NA, colour = M30$ink, linewidth = .35) +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.8, stroke = .5) +
  geom_shadowtext(data = towns, aes(x, y, label = sprintf("%s  %.0f°", name, v)), family = "Fira Sans Condensed",
                  size = 3.3, colour = M30$ink, bg.colour = "white", bg.r = .12, hjust = 0, nudge_x = 2600) +
  annotate("point", pk$x, pk$y, shape = 4, size = 3, stroke = .9, colour = "white") +
  scale_fill_manual(values = heat(length(brks) - 1), drop = FALSE,
                    labels = \(l) sub("^\\((\\d+).*", "\\1", l) |> paste0("°"),
                    name = "Feels-like maximum, °C") +
  guides(fill = guide_legend(nrow = 1, label.position = "bottom", title.position = "top",
                             keywidth = unit(30, "pt"), keyheight = unit(7, "pt"),
                             label.hjust = 0, label.theme = element_text(size = 8.5, colour = M30$soft,
                                                                          family = "Fira Sans Condensed"))) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, expand = FALSE, clip = "off") +
  theme_m30() + theme(legend.position = "top", plot.margin = margin(0, 0, 0, 0),
                      legend.spacing.x = unit(0, "pt"), legend.margin = margin(0, 0, 6, 0))

strip <- bind_rows(dec, tibble(dec = "2020–24", d40 = last5)) |>
  mutate(dec = factor(dec, dec), last = dec == "2020–24") |>
  ggplot(aes(dec, d40)) +
  geom_col(aes(fill = last), width = .5, show.legend = FALSE) +
  geom_text(aes(label = format(round(d40, 1), nsmall = 1), colour = last), vjust = -.5, family = "Oswald", size = 4.2, show.legend = FALSE) +
  scale_fill_manual(values = c(`FALSE` = "#E3D9CF", `TRUE` = acc)) +
  scale_colour_manual(values = c(`FALSE` = M30$soft, `TRUE` = acc)) +
  scale_y_continuous(expand = expansion(mult = c(0, .25))) +
  labs(title = "Days of 40 °C or more in Larissa, per year",
       subtitle = "Average per decade. Air temperature (not feels-like), ERA5-Land grid cell over the city; 2020–24 is five years.") +
  theme_m30() +
  theme(axis.text.x = element_text(family = "Fira Sans Condensed", size = 9.5, colour = M30$soft, margin = margin(t = 3)),
        axis.line.x = element_line(colour = M30$line, linewidth = .4),
        plot.title = element_markdown(family = "Oswald", face = "plain", size = 13, colour = M30$ink, margin = margin(0, 0, 2, 0)),
        plot.subtitle = element_textbox_simple(size = 9, colour = M30$soft, margin = margin(0, 0, 4, 0)),
        plot.margin = margin(10, 30, 0, 30))

day_lab <- format(day, "%e %B %Y") |> trimws()
cool <- floor(quantile(gdf$app, .05))
message(sprintf("5%% of the region stayed below %.0f °C", cool))
cap <- paste0("ERA5 reanalysis (Copernicus/ECMWF) via Open-Meteo, daily apparent temperature max, 0.25° grid, ",
              "bilinear interpolation to 500 m · Larissa strip: ERA5-Land via Open-Meteo, 1960–2024 · ",
              "Border: Eurostat GISCO 2021 · Relief: Copernicus GLO-90")
map <- map + m30_labs(28, "Feeling",
  title = sprintf("%s: the plain felt like %.0f °C", day_lab, floor(pk$app)),
  subtitle = sprintf(paste0(
    "Daily maximum <b>feels-like temperature</b> (heat plus humidity and wind) on the hottest day of the summer 2021 heatwave, ",
    "%s. %.0f%% of the region felt like 40 °C or more; only the highest mountains stayed below %.0f °C. ",
    "The white cross marks the hottest ERA5 cell, %.1f °C, in %s municipality."),
    day_lab, share40, cool, pk$app, pk_mun), accent = acc) + labs(caption = NULL)
strip <- strip + labs(caption = m30_labs(28, "x", "x", source = cap)$caption)
p <- map / strip + plot_layout(heights = c(3.6, 1))
m30_save(p, 28, "feeling_heat", w = 8, h = 10)
