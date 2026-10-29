# Day 29 · Raster — Thessaly's land cover, 10 m pixels
# ESA WorldCover 2021 land-cover raster of mainland Thessaly as a print poster: the plain's patchwork of fields
# ringed by the forests of Pindus, Olympus, Ossa, Pelion and Othrys. A strip compares what covers the plain
# (land below 200 m) with what covers the hills and mountains.
#
# Data
#   * ESA WorldCover 10 m 2021 v200, tiles N39E021 + N36E021, CC BY 4.0, © ESA WorldCover project 2022 /
#     Contains modified Copernicus Sentinel data (2021) processed by ESA WorldCover consortium.
#     https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_N39E021_Map.tif
#     (same cache as day 25: 30daymap/cache/worldcover/)
#   * "The plain" = land below 200 m in the Copernicus GLO-90 DEM (via m30_dem()); border Eurostat GISCO 2021
#
# How / caveats
#   * Shares are counted on the full 10 m pixels (crosstab, ~5 min, cached in 30daymap/data/day29_plain_counts.csv).
#   * For drawing only, the 10 m raster is reduced to 40 m with the modal (most common) class per 4 x 4 block and
#     reprojected to EPSG:2100 nearest-neighbour: at 300 dpi one printed pixel is ~60 m, so nothing finer is visible.
#     Modal aggregation slightly favours the dominant class of each block (thin roads, small villages fade).
#   * WorldCover classes: 10 tree cover (incl. orchards, olive groves), 20 shrubland, 30 grassland, 40 cropland,
#     50 built-up, 60 bare/sparse, 80 water, 90 herbaceous wetland.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(shadowtext); library(patchwork) })

# ---- 1. data -----------------------------------------------------------------------------------------
wdir <- file.path(M30_CACHE, "worldcover"); dir.create(wdir, showWarnings = FALSE)
tiles <- c("N39E021", "N36E021")
tf <- file.path(wdir, sprintf("ESA_WorldCover_10m_2021_v200_%s_Map.tif", tiles))
walk2(tiles, tf, \(t, f) if (!file.exists(f)) download.file(sprintf(
  "https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_%s_Map.tif", t),
  f, mode = "wb", quiet = TRUE))
reg <- m30_region(); reg4 <- st_transform(reg, 4326)
wc <- crop(vrt(tf), ext(vect(reg4)) + 0.01)

# plain = DEM < 200 m, as polygons
dem <- m30_dem(crop = reg, buffer = 2000)
plain <- as.polygons(classify(dem, rbind(c(-Inf, 200, 1), c(200, Inf, 2)))) |> st_as_sf() |>
  rename(zone = 1) |> mutate(zone = c("Plain (below 200 m)", "Hills & mountains")[zone]) |>
  st_intersection(st_geometry(reg))

cf <- "30daymap/data/day29_plain_counts.csv"
if (!file.exists(cf)) {
  zr <- rasterize(vect(st_transform(plain, 4326)), wc, field = "zone")
  ct <- crosstab(c(wc, zr), long = TRUE); names(ct) <- c("code", "zone", "pixels")
  write.csv(ct, cf, row.names = FALSE)
}
cls <- c(`10` = "Tree cover", `20` = "Shrubland", `30` = "Grassland", `40` = "Cropland", `50` = "Built-up",
         `60` = "Bare / sparse", `80` = "Water", `90` = "Wetland")
cnt <- read.csv(cf) |> mutate(class = cls[as.character(code)])
cnt <- cnt |> mutate(zone = if (is.numeric(zone)) levels(factor(plain$zone))[zone] else zone)
sh <- cnt |> group_by(zone) |> mutate(share = pixels / sum(pixels)) |> ungroup()
crop_plain <- sh |> filter(class == "Cropland", grepl("Plain", zone)) |> pull(share)
crop_mtn   <- sh |> filter(class == "Cropland", !grepl("Plain", zone)) |> pull(share)
plain_km2  <- sum(as.numeric(st_area(filter(plain, grepl("Plain", zone))))) / 1e6
message(sprintf("Plain (< 200 m): %.0f km2 = %.0f%% of mainland Thessaly; cropland %.1f%% of the plain vs %.1f%% of hills & mountains",
                plain_km2, 100 * plain_km2 / (as.numeric(st_area(reg)) / 1e6), 100 * crop_plain, 100 * crop_mtn))
message("Plain shares: ", sh |> filter(grepl("Plain", zone)) |> arrange(-share) |>
          with(paste(sprintf("%s %.1f%%", class, 100 * share), collapse = "; ")))

# drawing raster: modal 4x4 (40 m) then EGSA87 at 40 m, masked to the region
rf <- file.path(wdir, "wc_thessaly_40m_2100.tif")
if (!file.exists(rf)) {
  w40 <- aggregate(wc, 4, fun = "modal", na.rm = TRUE)
  w40 <- project(w40, paste0("EPSG:", CRS_GR), res = 40, method = "near")
  writeRaster(mask(w40, vect(reg)), rf, overwrite = TRUE, datatype = "INT1U")
}
w <- rast(rf)

# ---- 2. colours: WorldCover legend, toned for paper -----------------------------------------------------
pal <- c(`10` = "#2F5D45", `20` = "#9A9455", `30` = "#C9D3A2", `40` = "#E9C46A", `50` = "#C2410C",
         `60` = "#D8D2C4", `80` = "#3E7CB1", `90` = "#5FA39A")
v <- values(w, mat = FALSE)
col <- ifelse(is.na(v), NA, pal[as.character(v)])
img <- matrix(col, nrow = nrow(w), ncol = ncol(w), byrow = TRUE)
img[is.na(img)] <- "#FFFFFF00"
e <- ext(w)

towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Kalambaka", "Elassona", "Farsala")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])
mts <- tribble(~lab, ~lon, ~lat,
               "PINDUS", 21.30, 39.62, "OLYMPUS", 22.36, 40.08, "OSSA", 22.70, 39.80,
               "PELION", 23.08, 39.42, "OTHRYS", 22.42, 39.06) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |> st_transform(CRS_GR) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])
bb <- st_bbox(reg)

map <- ggplot() +
  annotation_raster(img, xmin = e$xmin, xmax = e$xmax, ymin = e$ymin, ymax = e$ymax, interpolate = FALSE) +
  geom_sf(data = reg, fill = NA, colour = M30$ink, linewidth = .3) +
  geom_shadowtext(data = mts, aes(x, y, label = lab), family = "Fira Sans Condensed", size = 3.1, colour = "white",
                  bg.colour = "#1F3B2C", bg.r = .1, fontface = "bold") +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.6, stroke = .5) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", size = 3.3, colour = M30$ink,
                  bg.colour = "white", bg.r = .14, nudge_y = 2800, fontface = "bold") +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, xlim = bb[c(1, 3)], ylim = bb[c(2, 4)], expand = FALSE, clip = "off") +
  theme_m30() + theme(plot.margin = margin(18, 30, 0, 30))

# strip: what covers the plain vs the hills (100% bars)
ord <- c("Cropland", "Grassland", "Tree cover", "Shrubland", "Built-up", "Water", "Wetland", "Bare / sparse")
palc <- setNames(pal[names(cls)], cls)
zones <- c("Plain (below 200 m)", "Hills & mountains")
sb <- sh |> mutate(class = factor(class, ord), zy = match(zone, rev(zones))) |> arrange(zone, class) |>
  group_by(zone) |> mutate(x1 = cumsum(share), x0 = x1 - share, mid = (x0 + x1) / 2) |> ungroup()
lab <- sb |> filter(share >= .045) |>
  mutate(txt = ifelse(share >= .12, sprintf("%s %.0f%%", class, 100 * share), sprintf("%.0f%%", 100 * share)),
         tc = ifelse(class %in% c("Tree cover", "Shrubland", "Built-up", "Water"), "white", M30$ink))
strip <- ggplot(sb) +
  geom_rect(aes(xmin = x0, xmax = x1, ymin = zy - .32, ymax = zy + .32, fill = class), colour = "white", linewidth = .4,
            show.legend = FALSE) +
  geom_text(data = lab, aes(mid, zy, label = txt, colour = I(tc)), family = "Fira Sans Condensed", size = 3.2, fontface = "bold") +
  scale_fill_manual(values = palc) +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(breaks = 1:2, labels = rev(zones), expand = expansion(add = .1)) +
  theme_m30() +
  theme(axis.text.y = element_text(family = "Fira Sans Condensed", size = 10, colour = M30$ink, hjust = 1, margin = margin(r = 4)),
        plot.margin = margin(8, 30, 0, 30))

legend_txt <- paste(map_chr(c("40", "30", "10", "20", "50", "80", "60"), \(k)
  sprintf("<span style='color:%s;font-size:15pt'>■</span> %s", pal[k], cls[k])), collapse = " &nbsp; ")
map <- map + m30_labs(29, "Raster",
  title = sprintf("%.0f%% of Thessaly's plain is fields", floor(100 * crop_plain)),
  subtitle = paste0(sprintf(paste0(
    "Every 10 m pixel of ESA WorldCover 2021 for mainland Thessaly. Below 200 m, in the plain of Larissa, Trikala and ",
    "Karditsa (%s km², %.0f%% of the region), <b style='color:#B8892A'>cropland</b> covers %.0f%% of the land; ",
    "in the hills and mountains only %.0f%%, where <b style='color:#2F5D45'>tree cover</b> takes over."),
    scales::comma(round(plain_km2, -1)), 100 * plain_km2 / (as.numeric(st_area(reg)) / 1e6), 100 * crop_plain, 100 * crop_mtn),
    "<br><span style='font-size:10.5pt'>", legend_txt, "</span>"), accent = "#B8892A") + labs(caption = NULL)
strip <- strip + labs(caption = m30_labs(29, "x", "x", source = paste0(
  "ESA WorldCover 10 m 2021 v200 (CC BY 4.0); shares from full 10 m pixels, drawn at 40 m (modal class) · ",
  "Plain = below 200 m in Copernicus GLO-90 · Border: Eurostat GISCO 2021"),
  extra = "Tree cover includes orchards and olive groves")$caption)
p <- map / strip + plot_layout(heights = c(6, 1))
m30_save(p, 29, "raster_landcover", w = 10, h = 10)
