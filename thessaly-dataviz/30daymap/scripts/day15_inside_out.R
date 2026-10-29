# Day 15 · Inside out — Close the Vale of Tempe and Thessaly becomes a lake again
# Herodotus (Histories 7.129) writes that Thessaly was once a lake, shut in by mountains, until the Pineios cut the
# gorge of Tempe to the sea. Thought experiment on today's terrain: plug the Tempe gorge floor, then raise the water
# until it finds the next lowest way out. The basin is drawn as water, the mountains as the land.
# Finding: the spill level the DEM gives, where the water would overflow, and the lake area below it.
#
# Data
#   * Copernicus GLO-90 DEM (ESA / Airbus, 2021), https://copernicus-dem-90m.s3.amazonaws.com/ via m30_dem()
#   * Pineios course through Tempe: OpenStreetMap waterway = river, name = Πηνειός (Geofabrik extract 2026-10-28, ODbL)
#   * Coast (sea = outlet) and region border: Eurostat GISCO NUTS 2021 1:1M
#
# How
#   * Outlets = sea cells (outside the NUTS land polygon) + the edge of the DEM window (region + 20 km).
#   * Plug = the Pineios line between 22.545 E and 22.72 E buffered by 500 m and set to 5,000 m.
#   * Binary search on the water level L: cells <= L are grouped with terra::patches(); the spill level is the lowest L
#     at which the patch holding Larissa reaches an outlet. The lake = that patch just below the spill level.
#
# Caveats
#   * A thought experiment on today's ground, not a reconstruction of an ancient lake: the plain has been filled with
#     river sediment for millennia, and the gorge has been cut since. GLO-90 is a surface model (trees, buildings).
#   * Depths are lake level minus today's ground height.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages(library(shadowtext))

# ---- 1. data -------------------------------------------------------------------------------------
dem <- m30_dem(crop = NULL)
reg <- m30_region(TRUE)
landr <- rasterize(vect(m30_greece()), dem)
out <- is.na(landr)
nr <- nrow(dem); nc <- ncol(dem)
out[c(cellFromRowCol(dem, 1, 1:nc), cellFromRowCol(dem, nr, 1:nc),
      cellFromRowCol(dem, 1:nr, 1), cellFromRowCol(dem, 1:nr, nc))] <- 1
oc  <- which(values(out) == 1)
lar <- cellFromXY(dem, st_coordinates(filter(m30_towns, name == "Larissa")))

riv <- m30_osm("lines", "waterway = 'river' AND name = 'Πηνειός'", clip = NULL)
win <- st_as_sfc(st_bbox(c(xmin = 22.545, xmax = 22.72, ymin = 39.84, ymax = 39.96), crs = st_crs(4326))) |>
  st_transform(CRS_GR)
plug <- st_intersection(st_union(riv), win) |> st_buffer(500)
d2 <- dem; d2[cells(dem, vect(plug))[, 2]] <- 5000

# ---- 2. spill level ------------------------------------------------------------------------------
comp <- function(L, d = d2) { w <- d <= L | out; w[w == 0] <- NA; patches(w, directions = 8) }
conn <- function(L, d = d2) { p <- comp(L, d); pl <- p[lar][1, 1]; !is.na(pl) && any(values(p)[oc] == pl, na.rm = TRUE) }
cache <- file.path(M30_CACHE, "terrain", "day15_spill.rds")
if (!file.exists(cache)) {
  lo <- 85; hi <- 1000
  while (hi - lo > 0.25) { m <- (lo + hi) / 2; if (conn(m)) hi <- m else lo <- m }
  # open gorge, for comparison: level at which Larissa already drains to the sea
  lo0 <- 0; hi0 <- 200
  while (hi0 - lo0 > 0.25) { m <- (lo0 + hi0) / 2; if (conn(m, dem)) hi0 <- m else lo0 <- m }
  saveRDS(list(lo = lo, hi = hi, open = hi0), cache)
}
sp <- readRDS(cache); LEVEL <- sp$lo
pA <- comp(LEVEL); lake <- pA == pA[lar][1, 1]
lake <- classify(lake, cbind(c(0, NA), NA))
# the saddle: lowest cells just above the level next to both the lake and an outlet-connected patch
outp <- unique(values(pA)[oc]); outp <- outp[!is.na(outp)]
nA <- focal(classify(lake, cbind(NA, 0)), 3, max, na.rm = TRUE)
nB <- focal(pA %in% outp, 3, max, na.rm = TRUE)
sad <- which(values(nA) == 1 & values(nB) == 1 & values(d2) > LEVEL & values(d2) <= sp$hi + 0.5)
sad_xy <- colMeans(xyFromCell(dem, sad)[, , drop = FALSE])
sad_ll <- st_coordinates(st_transform(st_sfc(st_point(sad_xy), crs = CRS_GR), 4326))

depth <- mask(LEVEL - dem, lake)
names(depth) <- "depth"
area_all <- global(lake, "sum", na.rm = TRUE)[1, 1] * 90^2 / 1e6
area_reg <- global(mask(lake, vect(reg)), "sum", na.rm = TRUE)[1, 1] * 90^2 / 1e6
reg_land <- global(mask(dem > 0, vect(reg)), "sum", na.rm = TRUE)[1, 1] * 90^2 / 1e6
maxd <- global(depth, "max", na.rm = TRUE)[1, 1]
message(sprintf("Open gorge: Larissa drains to the sea at %.1f m. Plugged gorge: spill level %.1f m at %.4f E %.4f N",
                sp$open, LEVEL, sad_ll[1], sad_ll[2]))
message(sprintf("Lake: %.0f km2 (%.0f km2 inside Thessaly = %.0f%% of its land), deepest %.0f m",
                area_all, area_reg, 100 * area_reg / reg_land, maxd))

# depth of each town under the lake
towns <- m30_towns |> mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2],
                             ground = terra::extract(dem, cbind(x, y))[, 1],
                             under = !is.na(terra::extract(lake, cbind(x, y))[, 1]),
                             depth = ifelse(under, LEVEL - ground, NA))
print(st_drop_geometry(towns)[, c("name", "ground", "under", "depth")])

# ---- 3. map --------------------------------------------------------------------------------------
LAND <- "#F3EFE6"; DEEP <- "#0F3B5C"; SHALLOW <- "#8EC3DA"; ACC <- "#0F3B5C"; RED <- "#B4442C"
bb <- st_bbox(st_buffer(reg, 3000))
w  <- ext(bb[c(1, 3, 2, 4)])
demc <- crop(dem, w)
hs <- m30_hillshade(demc, z = 2) * 255
hs <- mask(hs, demc > 1, maskvalues = FALSE)
hdf <- as.data.frame(hs, xy = TRUE, na.rm = TRUE)
ddf <- as.data.frame(crop(depth, w), xy = TRUE, na.rm = TRUE)
lake_v <- as.polygons(crop(lake, w)) |> st_as_sf() |> st_make_valid()
iso <- as.contour(focal(crop(classify(depth, cbind(NA, -1)), w), 5, mean, na.rm = TRUE), levels = c(20, 40, 60)) |>
  st_as_sf() |> st_intersection(st_buffer(lake_v, -200))
sea <- st_difference(st_as_sfc(bb) |> st_set_crs(CRS_GR), st_union(m30_greece()))
tempe <- st_centroid(plug) |> st_coordinates()
lab_t <- towns |> filter(name %in% c("Larissa", "Trikala", "Karditsa", "Farsala", "Tyrnavos", "Volos"))

p <- ggplot() +
  geom_sf(data = sea, fill = "#E4E9EC", colour = NA) +
  geom_raster(data = hdf, aes(x, y, alpha = I(pmin(.5, pmax(0, .66 - shade) * .9))), fill = "#6B6253") +
  geom_raster(data = ddf, aes(x, y, fill = depth)) +
  scale_fill_gradientn(colours = c(SHALLOW, "#3F86AF", DEEP), limits = c(0, maxd), guide = "none") +
  geom_sf(data = iso, colour = "white", linewidth = .18, alpha = .5) +
  geom_sf(data = lake_v, fill = NA, colour = DEEP, linewidth = .3) +
  geom_sf(data = reg, fill = NA, colour = M30$soft, linewidth = .25, linetype = "22") +
  # Tempe plug and spill point
  annotate("point", x = tempe[1], y = tempe[2], shape = 4, size = 3.2, stroke = 1.1, colour = RED) +
  annotate("richtext", x = tempe[1] + 3500, y = tempe[2] + 2500, hjust = 0, vjust = 0, label = "<b>Vale of Tempe</b><br>closed",
           family = "Fira Sans Condensed", size = 3.2, colour = RED, fill = NA, label.colour = NA, lineheight = 1.05) +
  annotate("point", x = sad_xy[1], y = sad_xy[2], shape = 21, size = 3, fill = "white", colour = DEEP, stroke = 1) +
  annotate("segment", x = sad_xy[1], y = sad_xy[2], xend = sad_xy[1] + 14000, yend = sad_xy[2] + 6000,
           colour = DEEP, linewidth = .3) +
  annotate("richtext", x = sad_xy[1] + 14500, y = sad_xy[2] + 6000, hjust = 0, vjust = .5,
           label = sprintf("<b>Overflows here</b><br>lowest gap, %.0f m", LEVEL),
           family = "Fira Sans Condensed", size = 3.2, colour = DEEP, fill = alpha("white", .8), label.colour = NA,
           lineheight = 1.05) +
  geom_point(data = lab_t, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.8, stroke = .5) +
  geom_shadowtext(data = lab_t, aes(x, y - 4000, label = ifelse(under, sprintf("%s\n%.0f m under", name, depth), name)),
                  family = "Fira Sans Condensed", size = 3.1, colour = M30$ink, bg.colour = "white", bg.r = .15,
                  lineheight = .9, vjust = 1) +
  m30_scalebar(20, x = bb["xmin"] + 6000, y = bb["ymin"] + 6000, bbox = bb) +
  coord_sf(crs = CRS_GR, xlim = bb[c(1, 3)], ylim = bb[c(2, 4)], expand = FALSE, clip = "off") +
  theme_m30() +
  theme(plot.title = element_markdown(margin = margin(26, 0, 14, 0), lineheight = 1.15),
        plot.subtitle = element_textbox_simple(margin = margin(0, 0, 18, 0))) +
  m30_labs(
    15, "Inside out",
    title = sprintf("Close the Vale of Tempe and Thessaly<br>is a lake of %s km² again",
                    format(round(area_all, -1), big.mark = ",")),
    subtitle = sprintf(paste0(
      "Herodotus (<i>Histories</i> 7.129) tells that Thessaly was once a lake, walled in by mountains, until the Pineios ",
      "cut the gorge of Tempe to the sea. A thought experiment on today's terrain, not a reconstruction: block the gorge and ",
      "the water rises until it spills over the <b style='color:%s'>next lowest gap, at %.0f m</b> near the Aegean coast. ",
      "Everything below that line, %.0f%% of Thessaly's land, is drawn as water; darker is deeper, white lines every 20 m."),
      DEEP, LEVEL, 100 * area_reg / reg_land),
    source = "Copernicus GLO-90 DEM (ESA, 2021) · OpenStreetMap Pineios (Geofabrik, Oct 2026) · Eurostat NUTS 2021",
    accent = ACC,
    extra = sprintf("lake = cells below %.1f m connected to Larissa (terra::patches), gorge floor plugged, sea and DEM edge as outlets; deepest %.0f m",
                    LEVEL, maxd))
m30_save(p, 15, "inside_out", w = 8.6, h = 9.4)
