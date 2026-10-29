# Day 26 · Water — Storm Daniel, September 2023: the flooded plain
# Every patch of land that Copernicus Emergency Management Service saw under water at least once between
# 6 and 22 September 2023 (union of all delineation + monitoring products of activation EMSR692), drawn over
# the relief of Thessaly with today's Lake Karla and the Pineios river. A strip below shows how the water
# receded in the four big areas of interest (flooded km² per satellite image date).
#
# Data
#   * Copernicus EMS Rapid Mapping, activation EMSR692 "Flood in Greece" (event 5 Sep 2023), vector packages
#     DEL_PRODUCT + DEL_MONIT01..05 for AOI01–07, layer observedEventA (notation "Flooded area").
#     https://rapidmapping.emergency.copernicus.eu/EMSR692  — API: .../backend/dashboard-api/public-activations/?code=EMSR692
#     © European Union, Copernicus EMS; free use with attribution. Cached in 30daymap/cache/emsr692/
#   * OpenStreetMap (Geofabrik extract 2026-10-28, ODbL): Lake Karla polygon, Pineios river line
#   * Relief: Copernicus GLO-90 DEM; border Eurostat GISCO NUTS 2021 (via m30_base.R)
#
# Caveats
#   * Area = union of "Flooded area" polygons over all products, rasterised at 20 m (fast and exact to ~0.1%).
#     "Flood trace" polygons (mud, wet soil left behind) are not counted.
#   * The 7 AOIs cover the plain and Pelion but not every corner of Thessaly; cloud gaps on some dates.
#   * Monitoring dates differ between AOIs, so the receding strip compares each AOI with itself.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(jsonlite); library(shadowtext); library(patchwork) })

# ---- 1. data: Copernicus EMS EMSR692 ---------------------------------------------------------------
cdir <- file.path(M30_CACHE, "emsr692"); dir.create(cdir, showWarnings = FALSE)
af <- file.path(cdir, "activation.json")
if (!file.exists(af)) download.file(
  "https://rapidmapping.emergency.copernicus.eu/backend/dashboard-api/public-activations/?code=EMSR692", af, quiet = TRUE)
act <- fromJSON(af, simplifyVector = FALSE)$results[[1]]
prods <- map_dfr(act$aois, \(a) map_dfr(a$products, \(p) if (length(p$downloadPath) && nzchar(p$downloadPath)) tibble(
  aoi = a$name, url = p$downloadPath,
  date = as.Date(substr(unlist(map(p$images, "acquisitionTime"))[1], 1, 10)))))
walk(prods$url, \(u) {
  z <- file.path(cdir, basename(u)); x <- file.path(cdir, "x", sub("\\.zip$", "", basename(u)))
  if (!file.exists(z)) download.file(u, z, mode = "wb", quiet = TRUE)          # follows the S3 redirect
  if (!dir.exists(x)) unzip(z, exdir = x)
})
prods <- prods |> mutate(dir = file.path(cdir, "x", sub("\\.zip$", "", basename(url))),
                         shp = map_chr(dir, \(d) list.files(d, "observedEventA.*\\.shp$", full.names = TRUE)[1]))
ev <- map2_dfr(prods$shp, seq_len(nrow(prods)), \(f, i)
  read_sf(f) |> st_transform(CRS_GR) |> filter(notation == "Flooded area") |>
    transmute(aoi = prods$aoi[i], date = prods$date[i]))
aoi <- map(prods$dir, \(d) read_sf(list.files(d, "areaOfInterestA.*\\.shp$", full.names = TRUE)[1]) |>
             st_transform(CRS_GR) |> st_geometry()) |> do.call(c, args = _) |> st_union()

# union by rasterising at 20 m
fr <- file.path(cdir, "flood_union_20m.tif")
if (!file.exists(fr)) {
  tmpl <- rast(ext(vect(aoi)), resolution = 20, crs = paste0("EPSG:", CRS_GR))
  writeRaster(rasterize(vect(ev), tmpl, field = 1, background = NA), fr, overwrite = TRUE)
}
fl <- rast(fr)
km2 <- global(fl, "sum", na.rm = TRUE)[1, 1] * 400 / 1e6
reg <- m30_region()
km2_th <- global(mask(fl, vect(reg)), "sum", na.rm = TRUE)[1, 1] * 400 / 1e6
message(sprintf("Flooded at least once, 6–22 Sep 2023 (union of %d products): %.0f km2 (%.0f km2 inside Thessaly mainland)",
                nrow(prods), km2, km2_th))
message(sprintf("EMS's own activation statistic max_extent: %.0f km2; press figure 730 km2", act$stats$max_extent / 100))

# receding: flooded km2 per AOI and date (AOIs with >= 4 dates)
rec <- ev |> mutate(a = as.numeric(st_area(geometry)) / 1e6) |> st_drop_geometry() |>
  group_by(aoi, date) |> summarise(km2 = sum(a), .groups = "drop") |>
  group_by(aoi) |> filter(n() >= 4) |> ungroup()
message("Receding, km2 per date:\n", paste(capture.output(print(tidyr::pivot_wider(rec, names_from = aoi, values_from = km2) |> arrange(date))), collapse = "\n"))

# ---- 2. context layers -----------------------------------------------------------------------------
view <- st_bbox(st_buffer(st_as_sfc(st_bbox(as.polygons(fl, aggregate = TRUE) |> st_as_sf())), 6000))
vbox <- st_as_sfc(view) |> st_sf()
dem <- m30_dem(crop = reg, buffer = 10000) |> crop(ext(view["xmin"], view["xmax"], view["ymin"], view["ymax"]))
hs  <- m30_hillshade(aggregate(dem, 2))
hsd <- as.data.frame(hs, xy = TRUE, na.rm = TRUE)
el  <- as.data.frame(aggregate(dem, 2), xy = TRUE, na.rm = TRUE)
fld <- as.data.frame(aggregate(fl, 3, fun = "max", na.rm = TRUE), xy = TRUE, na.rm = TRUE)   # 60 m for drawing
karla <- m30_osm("multipolygons", "name = 'Λίμνη Κάρλα'", clip = vbox)
riv <- m30_osm("lines", "waterway = 'river' AND (name LIKE '%Πηνει%' OR name LIKE '%Pin%')", clip = vbox)
greece <- m30_greece()
message("OSM: Karla polygons ", nrow(karla), ", Pineios segments ", nrow(riv))

towns <- m30_towns |> filter(name %in% c("Larissa", "Trikala", "Karditsa", "Farsala", "Volos")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])

kc <- st_coordinates(st_point_on_surface(st_union(karla)))
rv <- st_coordinates(st_cast(st_union(riv), "MULTILINESTRING"))[, 1:2]
rv <- rv[which.min((rv[, 1] - 345000)^2 + (rv[, 2] - 4395000)^2), ]        # river vertex north-west of Larissa
feat <- tibble(lab = c("Lake\nKarla", "Pineios"), x = c(kc[1] + 11000, rv[1]), y = c(kc[2] + 4000, rv[2] + 3500))

# ---- 3. plot ----------------------------------------------------------------------------------------
acc <- "#0B5CAD"
map <- ggplot() +
  geom_raster(data = el, aes(x, y, fill = elev), show.legend = FALSE) +
  scale_fill_gradient(low = "#F4F2EE", high = "#C9C3BA", limits = c(0, 1500), oob = scales::squish) +
  ggnewscale::new_scale_fill() +
  geom_raster(data = hsd, aes(x, y, alpha = 1 - shade), fill = "#3A3530", show.legend = FALSE) +
  scale_alpha(range = c(0, .45)) +
  geom_sf(data = st_difference(vbox, st_union(st_buffer(reg, 0))), fill = "white", colour = NA, alpha = .55) +
  geom_sf(data = reg, fill = NA, colour = M30$soft, linewidth = .3, linetype = "22") +
  geom_raster(data = fld, aes(x, y), fill = acc) +
  geom_sf(data = riv, colour = "#5B8DB8", linewidth = .45) +
  geom_sf(data = karla, fill = "#6FA3CF", colour = NA) +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 2, stroke = .6) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", fontface = "bold",
                  size = 3.6, colour = M30$ink, bg.colour = "white", bg.r = .12, nudge_y = 3200) +
  geom_shadowtext(data = feat, aes(x, y, label = lab), family = "Fira Sans Condensed", fontface = "bold",
                  size = 3.3, colour = "#2F6390", bg.colour = "white", bg.r = .12, lineheight = .9) +
  coord_sf(crs = CRS_GR, xlim = view[c(1, 3)], ylim = view[c(2, 4)], expand = FALSE) +
  m30_scalebar(10, bbox = view) +
  theme_m30() + theme(plot.margin = margin(22, 30, 0, 30))

last <- rec |> group_by(aoi) |> slice_max(date, n = 1) |> ungroup() |> filter(aoi != "Karditsa") |>
  bind_rows(rec |> filter(aoi == "Karditsa") |> slice_min(date, n = 1))   # Karditsa labelled at its start
first <- rec |> group_by(aoi) |> slice_min(date, n = 1)
strip <- ggplot(rec, aes(date, km2, group = aoi)) +
  geom_line(colour = acc, linewidth = .7) +
  geom_point(colour = acc, size = 1.6) +
  geom_text(data = last, aes(label = aoi, vjust = .5, hjust = -.15), family = "Fira Sans Condensed", size = 3.3, colour = M30$ink) +
  scale_x_date(date_labels = "%e Sep", breaks = seq(as.Date("2023-09-10"), as.Date("2023-09-20"), 2),
               expand = expansion(add = c(.3, 2.2))) +
  scale_y_continuous(labels = \(v) paste(v, "km²"), breaks = seq(0, 200, 100), limits = c(0, NA), expand = expansion(mult = c(0, .08))) +
  labs(title = "The water stayed for weeks",
       subtitle = "Flooded area seen on each satellite image, four Copernicus areas of interest named after their main town") +
  theme_m30() +
  theme(axis.text = element_text(family = "Fira Sans Condensed", size = 9, colour = M30$soft),
        panel.grid.major.y = element_line(colour = M30$line, linewidth = .25),
        plot.title = element_markdown(family = "Oswald", face = "plain", size = 13, colour = M30$ink, margin = margin(0, 0, 2, 0)),
        plot.subtitle = element_textbox_simple(size = 9, colour = M30$soft, margin = margin(0, 0, 6, 0)),
        plot.margin = margin(14, 30, 18, 30))

map <- map + m30_labs(26, "Water",
  title = sprintf("Daniel flooded %s km² of Thessaly", scales::comma(round(km2))),
  subtitle = sprintf(paste0(
    "<b style='color:%s'>Blue</b> is every field, road and village that the EU's Copernicus emergency service saw flooded ",
    "at least once between 6 and 22 September 2023, in %d satellite map products. That is more than the ~730 km² ",
    "reported from a single Sentinel-1 image, and %.0f times the size of today's <b style='color:#3F7FB5'>Lake Karla</b>."),
    acc, nrow(prods), km2 / (sum(as.numeric(st_area(karla))) / 1e6)), accent = acc) + labs(caption = NULL)
strip <- strip + labs(caption = m30_labs(26, "x", "x", source = paste0(
  "Copernicus EMS Rapid Mapping, activation EMSR692 (2023), observed flooded area, union of ", nrow(prods),
  " products · OpenStreetMap (Lake Karla, Pineios) · Relief: Copernicus GLO-90 · Border: Eurostat GISCO 2021"))$caption)
p <- map / strip + plot_layout(heights = c(3, 1))
m30_save(p, 26, "water_daniel_flood", w = 8, h = 10)
