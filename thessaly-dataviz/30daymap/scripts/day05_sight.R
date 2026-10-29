# Day 05 · Sight — What you can see from Olympus and from Meteora
# Two viewsheds over mainland Thessaly: from Mytikas, the summit of Mount Olympus, and from the rock of the
# Great Meteoron monastery. Each coloured cell is ground a person standing at that point could see (line of sight
# over the bare terrain, earth curvature and normal refraction included). Finding: share of Thessaly's land in view.
#
# Data
#   * Copernicus GLO-90 DEM (ESA / Airbus, 2021 release), via m30_dem(); AWS open data
#     https://copernicus-dem-90m.s3.amazonaws.com/  — used for the line of sight
#   * Copernicus GLO-30 DEM tiles N39 E021 and N40 E022, https://copernicus-dem-30m.s3.amazonaws.com/
#     — only to get the true height of the two observer points (the 90 m grid smooths summits and rock towers)
#   * Observer locations from OpenStreetMap (Geofabrik extract 2026-10-28): peak node "Μύτικας" and the polygon of
#     "Μονή Μεγάλου Μετεώρου" (the prompt's 39.7217 N 21.6261 E falls in the valley below the rock, 330 m, so OSM is used)
#   * Region border: Eurostat GISCO NUTS 2021 (EL61), mainland part
#
# Caveats
#   * Bare-earth surface: trees, buildings and haze are ignored, so this is the best case on a perfectly clear day.
#   * Mytikas lies ~80 m outside the region's (1:1M) border; the line of sight is computed on the DEM around it.
#   * The DEM cuts the sharp summit of Mytikas (GLO-30 top 2,792 m, GLO-90 cell 2,768 m vs the official 2,918 m of the
#     Hellenic Military Geographical Service), so the Mytikas eye is set at 2,918 + 1.7 m. Great Meteoron: GLO-30 top of
#     the monastery polygon + 1.7 m (the often-quoted 613 m of the rock would see slightly more).
#     Eye heights are passed to viewshed() as height above the 90 m cell the point sits in.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages(library(shadowtext))

# ---- 1. data -------------------------------------------------------------------------------------
dem <- m30_dem(crop = NULL)                          # full cache: region + 20 km, 90 m, EGSA87
reg <- m30_region(TRUE)
tdir <- file.path(M30_CACHE, "terrain")
dir.create(tdir, showWarnings = FALSE)
dem30 <- function(tile) {
  id <- sprintf("Copernicus_DSM_COG_10_%s_DEM", tile); f <- file.path(tdir, paste0(id, ".tif"))
  if (!file.exists(f)) download.file(sprintf("https://copernicus-dem-30m.s3.amazonaws.com/%s/%s.tif", id, id),
                                     f, mode = "wb", quiet = TRUE)
  rast(f)
}

# observers from OSM
osm <- m30_osm_gpkg()
myt <- read_sf(osm, query = "SELECT * FROM points WHERE name = 'Μύτικας'") |> st_transform(CRS_GR)
myt <- myt[which.min(st_distance(myt, st_sfc(st_point(c(22.3586, 40.0856)), crs = 4326) |> st_transform(CRS_GR))), ]
met <- read_sf(osm, query = "SELECT * FROM multipolygons WHERE name = 'Μονή Μεγάλου Μετεώρου'") |> st_transform(CRS_GR)

# true top of each observer point from GLO-30: max within the monastery polygon / within 150 m of the peak node
top30 <- function(geom, tile) {
  r <- dem30(tile); g <- st_transform(geom, 4326)
  v <- terra::extract(r, vect(g), fun = max, na.rm = TRUE)[, 2]
  v
}
obs <- tibble(
  name = c("Mytikas", "Great Meteoron"),
  geom = c(st_geometry(myt), st_centroid(st_geometry(met))),
  z30  = c(top30(st_buffer(st_geometry(myt), 150), "N40_00_E022_00"), top30(st_geometry(met), "N39_00_E021_00"))
) |> st_as_sf(sf_column_name = "geom", crs = CRS_GR)
xy <- st_coordinates(obs)
obs <- obs |> mutate(x = xy[, 1], y = xy[, 2], z90 = terra::extract(dem, xy)[, 1],
                     zeye = c(2918, z30[2]) + 1.7,        # Mytikas: official height, see caveats
                     eye = zeye - z90,
                     inside = lengths(st_intersects(geom, reg)) > 0,
                     to_border_m = as.numeric(st_distance(geom, st_boundary(reg))))
print(st_drop_geometry(obs))

# ---- 2. viewsheds --------------------------------------------------------------------------------
vs <- map(seq_len(nrow(obs)), \(i) viewshed(dem, c(obs$x[i], obs$y[i]), observer = obs$eye[i], target = 0,
                                             curvcoef = 6/7, output = "yes/no"))
inreg <- rasterize(vect(reg), dem, touches = FALSE)          # 1 inside mainland Thessaly
land  <- inreg * (dem > 0)                                    # land cells (DEM > 0 m)
n_land <- global(land, "sum", na.rm = TRUE)[1, 1]
share <- map_dbl(vs, \(v) global(v * land, "sum", na.rm = TRUE)[1, 1] / n_land)
both  <- global(vs[[1]] * vs[[2]] * land, "sum", na.rm = TRUE)[1, 1] / n_land
anyv  <- global(((vs[[1]] + vs[[2]]) > 0) * land, "sum", na.rm = TRUE)[1, 1] / n_land
km2   <- n_land * 90^2 / 1e6
# farthest visible land cell inside Thessaly, per observer
far <- map_dbl(seq_along(vs), \(i) {
  m <- mask(vs[[i]] * land, vs[[i]] * land, maskvalues = c(0, NA))
  p <- as.data.frame(m, xy = TRUE)
  max(sqrt((p$x - obs$x[i])^2 + (p$y - obs$y[i])^2)) / 1000
})
message(sprintf("Land cells in mainland Thessaly: %.0f km2", km2))
message(sprintf("Visible from Mytikas: %.1f%% (%.0f km2), farthest %.0f km", 100 * share[1], share[1] * km2, far[1]))
message(sprintf("Visible from Great Meteoron: %.1f%% (%.0f km2), farthest %.0f km", 100 * share[2], share[2] * km2, far[2]))
message(sprintf("Visible from both: %.1f%%; from at least one: %.1f%%", 100 * both, 100 * anyv))

# ---- 3. map --------------------------------------------------------------------------------------
A_OLY <- "#2F5D8A"; A_MET <- "#C8553D"; A_BOTH <- "#6B3F6B"
bb <- st_bbox(st_buffer(reg, 3000))
demc <- crop(dem, ext(bb[c(1, 3, 2, 4)]))
hs <- m30_hillshade(demc)
cls <- (crop(vs[[1]], demc) + 2 * crop(vs[[2]], demc)) * crop(land, demc)
cls <- classify(cls, cbind(0, NA))
names(cls) <- "cls"
cls_df <- as.data.frame(cls, xy = TRUE, na.rm = TRUE) |>
  mutate(cls = factor(cls, 1:3, c("Olympus", "Meteora", "Both")))
hs_in  <- mask(hs, vect(reg))
hs_out <- mask(hs, vect(reg), inverse = TRUE)

towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])
obs_lab <- obs |> mutate(lab = c(sprintf("**Mytikas**, Olympus<br>eye at %s m", format(round(zeye[1]), big.mark = ",")),
                                 sprintf("**Great Meteoron**<br>eye at %s m", round(zeye[2]))),
                         lx = x + c(9000, -6000), ly = y + c(-6000, 12000))

map <- ggplot() +
  geom_raster(data = as.data.frame(hs_out, xy = TRUE, na.rm = TRUE), aes(x, y, alpha = shade), fill = "#BDBAB3") +
  geom_raster(data = as.data.frame(hs_in, xy = TRUE, na.rm = TRUE), aes(x, y, alpha = shade), fill = "#9E9A92") +
  scale_alpha_continuous(range = c(0.55, 0), guide = "none") +
  geom_raster(data = cls_df, aes(x, y, fill = cls), alpha = 0.82) +
  scale_fill_manual(values = c(Olympus = A_OLY, Meteora = A_MET, Both = A_BOTH), guide = "none") +
  geom_sf(data = reg, fill = NA, colour = M30$ink, linewidth = 0.35) +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.8, stroke = 0.5) +
  geom_shadowtext(data = towns, aes(x, y - 4200, label = name), family = "Fira Sans Condensed", size = 3.3,
                  colour = M30$ink, bg.colour = "white", bg.r = 0.15) +
  geom_segment(data = obs_lab, aes(x, y, xend = lx, yend = ly - 1500), linewidth = 0.3, colour = M30$ink) +
  geom_point(data = obs_lab, aes(x, y), shape = 24, size = 3.2, fill = c(A_OLY, A_MET), colour = "white", stroke = 0.7) +
  geom_richtext(data = obs_lab, aes(lx, ly, label = lab), family = "Fira Sans Condensed", size = 3.4, hjust = c(0, 1),
                vjust = 0, colour = c(A_OLY, A_MET), fill = alpha("white", 0.85), label.colour = NA,
                lineheight = 1.1, label.padding = unit(c(2, 3, 2, 3), "pt")) +
  m30_scalebar(20, x = bb["xmax"] - 26000, y = bb["ymin"] + 6000, bbox = bb)

# ---- 4. bar strip under the map, in map coordinates ----------------------------------------------
W <- bb["xmax"] - bb["xmin"]; x0 <- bb["xmin"] + 0.0 * W; bw <- 0.62 * W
bars <- tibble(what = c("From Mytikas (Olympus)", "From Great Meteoron", "From both"),
               v = c(share, both), col = c(A_OLY, A_MET, A_BOTH)) |>
  mutate(i = row_number(), y = bb["ymin"] - 16000 - (i - 1) * 13000,
         lab = sprintf("%.0f%%  ·  %s km²", 100 * v, sapply(round(v * km2, -1), format, big.mark = ",")))
strip <- list(
  annotate("text", x = x0, y = bb["ymin"] - 5000, label = "Share of mainland Thessaly's land in direct view",
           hjust = 0, family = "Oswald", size = 4.4, colour = M30$ink),
  geom_rect(data = bars, aes(xmin = x0, xmax = x0 + bw, ymin = y - 2600, ymax = y + 2600), fill = M30$land),
  geom_rect(data = bars, aes(xmin = x0, xmax = x0 + v * bw, ymin = y - 2600, ymax = y + 2600, fill = I(col))),
  geom_text(data = bars, aes(x = x0, y = y + 4900, label = what), hjust = 0, family = "Fira Sans Condensed",
            size = 3.3, colour = M30$soft),
  geom_text(data = bars, aes(x = x0 + v * bw + 1500, y = y, label = lab, colour = I(col)), hjust = 0,
            family = "Fira Sans Condensed", size = 3.6, fontface = "bold"))
far_lab <- sprintf(paste0("<span style='font-family:Oswald;font-size:12.5pt;color:%s'>Farthest ground in view</span><br>",
  "<b style='color:%s'>%.0f km</b> from Mytikas<br><b style='color:%s'>%.0f km</b> from Great Meteoron<br>",
  "<span style='font-size:8.5pt'>inside Thessaly, straight-line distance</span>"), M30$ink, A_OLY, far[1], A_MET, far[2])
strip <- c(strip, list(annotate("richtext", x = x0 + 0.74 * W, y = bb["ymin"] - 2500, label = far_lab, hjust = 0,
                                vjust = 1, family = "Fira Sans Condensed", size = 3.6, colour = M30$soft, fill = NA,
                                label.colour = NA, lineheight = 1.45, label.padding = unit(0, "pt"))))
ylo <- min(bars$y) - 5000

p <- map + strip +
  coord_sf(crs = CRS_GR, xlim = bb[c(1, 3)], ylim = c(ylo, bb["ymax"]), expand = FALSE, clip = "off") +
  theme_m30() +
  theme(plot.title = element_markdown(margin = margin(26, 0, 14, 0)),
        plot.subtitle = element_textbox_simple(margin = margin(0, 0, 22, 0))) +
  m30_labs(
    5, "Sight",
    title = sprintf("Olympus sees %.0f%% of Thessaly,<br>Meteora only %.0f%%", 100 * share[1], 100 * share[2]),
    subtitle = sprintf(paste0(
      "Coloured ground is what a person standing on <b style='color:%s'>Mytikas</b>, the summit of Olympus, or on the rock of ",
      "<b style='color:%s'>Great Meteoron</b> could see on a perfectly clear day, with only bare terrain in the way. ",
      "Ground seen from <b style='color:%s'>both</b> is purple. Olympus' view falls south over the Larissa and Karditsa plains; ",
      "Meteora's is boxed in by the Pindus and the hills around it."),
      A_OLY, A_MET, A_BOTH),
    source = "Copernicus GLO-90 & GLO-30 DEM (ESA, 2021) · OpenStreetMap (2026) · Eurostat NUTS 2021",
    accent = A_OLY,
    extra = "terra::viewshed on the 90 m grid, eye 1.7 m above ground, earth curvature and refraction (k = 1/7); Mytikas eye at its official 2,918 m because the DEM cuts the summit needle")
m30_save(p, 5, "sight", w = 8, h = 10)
