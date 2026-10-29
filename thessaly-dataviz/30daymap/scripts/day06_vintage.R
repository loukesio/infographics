# Day 06 · Vintage — Thessaly as an old-atlas relief plate
# Hypsometric tints in faded atlas colours, 200 m contour lines, soft relief shading, rivers in faded blue,
# engraved-style coast ripples and a serif cartouche. Finding: how much of Thessaly is plain (< 200 m) and how much
# is mountain (> 1,000 m).
#
# Data
#   * Copernicus GLO-90 DEM (ESA / Airbus, 2021), https://copernicus-dem-90m.s3.amazonaws.com/ via m30_dem()
#   * Rivers, lakes, mountain and range names: OpenStreetMap, Geofabrik Greece extract 2026-10-28 (ODbL)
#     https://download.geofabrik.de/europe/greece.html — waterway = river; natural = water (Karla, Plastiras, Smokovo);
#     positions of "Μύτικας", "Όσσα", "Πουριανός Σταυρός", "Γερακοβούνι (Όθρυς)", "Κακαρδίτσα", "Ντεληδήμι Αγράφων"
#   * Region border and Greek coast: Eurostat GISCO NUTS 2021 1:1M (EL61)
#
# Caveats
#   * Shares are of mainland Thessaly's land cells in the 90 m DEM (Sporades excluded). The DEM is a surface model
#     (tops of trees and buildings), a few metres above bare ground in places.
#   * Coast ripples and the cartouche are decoration; they carry no data.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages(library(shadowtext))

# ---- 1. data -------------------------------------------------------------------------------------
reg  <- m30_region(TRUE)
gr   <- m30_greece()
dem  <- m30_dem(crop = NULL)
breaks <- c(-Inf, 100, 200, 500, 1000, 1500, 2000, Inf)
bands  <- c("0–100 m", "100–200", "200–500", "500–1,000", "1,000–1,500", "1,500–2,000", "> 2,000")
tints  <- c("#B9C29A", "#CDCFA2", "#E2D9AC", "#E0C695", "#CFA87E", "#B98E6C", "#9F7A66")

land <- mask(dem, vect(reg))
land <- mask(land, land > 0, maskvalues = FALSE)
cls  <- classify(land, cbind(breaks[-length(breaks)], breaks[-1], seq_along(bands)), right = FALSE)
tab  <- freq(cls) |> as_tibble() |> mutate(band = factor(bands[value], bands), share = count / sum(count))
below200 <- sum(tab$share[tab$value <= 2]); above1000 <- sum(tab$share[tab$value >= 5])
km2 <- sum(tab$count) * 90^2 / 1e6
message(sprintf("Land: %.0f km2 | below 200 m: %.1f%% | above 1000 m: %.1f%%", km2, 100 * below200, 100 * above1000))
print(tab)

rivers <- m30_osm("lines", "waterway = 'river'", clip = reg) |> st_intersection(reg)
lakes  <- m30_osm("multipolygons", "natural = 'water' AND name IN ('Λίμνη Κάρλα','Τεχνητή Λίμνη Πλαστήρα','Τεχνητή Λίμνη Σμοκόβου')",
                  clip = reg)

# ---- 2. drawing layers ---------------------------------------------------------------------------
PAPER <- "#F1E6CC"; INK <- "#3E2F23"; SEPIA <- "#6E5641"; RIVER <- "#56819D"; SEA <- "#D5DCCB"
bb <- st_bbox(reg); bb["xmin"] <- bb["xmin"] - 4000; bb["xmax"] <- bb["xmax"] + 52000
bb["ymin"] <- bb["ymin"] - 4000; bb["ymax"] <- bb["ymax"] + 4000
frame <- st_as_sfc(bb) |> st_set_crs(CRS_GR)

demc <- crop(dem, ext(bb[c(1, 3, 2, 4)]))
hs   <- m30_hillshade(demc, z = 2) * 255      # m30_hillshade() returns cos/255; back to 0..1 (flat ground = sin 40° = 0.64)
hs <- mask(hs, demc > 1, maskvalues = FALSE)                    # no shading on the sea
inr <- rasterize(vect(reg), hs)
hs_df <- c(hs, inr) |> setNames(c("shade", "inreg")) |> as.data.frame(xy = TRUE) |> filter(!is.na(shade)) |>
  mutate(inreg = !is.na(inreg))
cls_df <- as.data.frame(cls, xy = TRUE, na.rm = TRUE) |> setNames(c("x", "y", "b")) |>
  mutate(b = factor(bands[b], bands))
# contours: smooth a 270 m copy first so lines look drawn, not pixelated
d270 <- aggregate(mask(demc, vect(st_buffer(reg, 1500))), 3, mean, na.rm = TRUE) |> focal(3, mean, na.rm = TRUE)
cont <- as.contour(d270, levels = seq(200, 2800, 200)) |> st_as_sf() |> st_intersection(reg) |>
  mutate(index = level %% 1000 == 0)
sea  <- st_difference(frame, st_union(gr))
coast <- st_intersection(st_boundary(st_union(gr)), frame)
ripples <- map(c(700, 1500, 2500, 3800), \(d) st_intersection(st_boundary(st_buffer(st_union(gr), d)), sea) |>
                 st_sf(d = d, geometry = _)) |> bind_rows()
grat <- st_graticule(st_transform(frame, 4326), lon = seq(21, 24, 0.5), lat = seq(38.5, 40.5, 0.5)) |>
  st_transform(CRS_GR) |> st_intersection(frame)

wgs <- function(lon, lat) st_sfc(st_point(c(lon, lat)), crs = 4326) |> st_transform(CRS_GR) |> st_coordinates()
mtn <- tribble(~lab, ~lon, ~lat, ~dx, ~dy, ~ang,
  "O L Y M P U S",  22.3586, 40.0856,  -4000,  -6500,   0,
  "O S S A",        22.685,  39.796,    1500,  -4200,   0,
  "P E L I O N",    23.046,  39.438,    6000,   1500, -38,
  "O T H R Y S",    22.711,  39.019,       0,  10500,   0,
  "P I N D U S",    21.201,  39.527,    4000,  12000, -62,
  "A G R A F A",    21.561,  39.219,       0,   5500,   0) |>
  rowwise() |> mutate(x = wgs(lon, lat)[1] + dx, y = wgs(lon, lat)[2] + dy) |> ungroup()
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Kalambaka", "Elassona")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2],
         nx = c(0, 0, 0, 0, -2500, 0), ny = c(-3600, 3600, -3600, -3600, -3600, -3600),
         hj = c(.5, .5, .5, .5, 1, .5))
plain <- wgs(22.13, 39.47)

# ---- 3. cartouche: scale of heights with share of land per band ----------------------------------
cx <- bb["xmax"] - 50000; cy <- bb["ymin"] + 79000; cw <- 47000; ch <- 73000
key <- tibble(i = seq_along(bands), b = factor(bands, bands), col = tints, share = tab$share[match(i, tab$value)]) |>
  mutate(yb = cy - 28000 - (7 - i) * 4100, xb = cx + 5000)
cart <- list(
  annotate("rect", xmin = cx, xmax = cx + cw, ymin = cy - ch, ymax = cy, fill = PAPER, colour = INK, linewidth = .5),
  annotate("rect", xmin = cx + 900, xmax = cx + cw - 900, ymin = cy - ch + 900, ymax = cy - 900, fill = NA,
           colour = INK, linewidth = .2),
  annotate("text", x = cx + cw / 2, y = cy - 7500, label = "THESSALIA", family = "Cormorant Garamond",
           fontface = "bold", size = 6.2, colour = INK),
  annotate("text", x = cx + cw / 2, y = cy - 12600, label = "Θεσσαλία", family = "Fira Sans", fontface = "italic",
           size = 3.1, colour = SEPIA),
  annotate("segment", x = cx + 9000, xend = cx + cw - 9000, y = cy - 15500, yend = cy - 15500, colour = INK,
           linewidth = .2),
  annotate("text", x = cx + cw / 2, y = cy - 19000, label = "Scale of heights",
           family = "Cormorant Garamond", fontface = "plain", size = 3.6, colour = INK),
  annotate("text", x = cx + cw / 2, y = cy - 22600, label = "and share of the land",
           family = "Cormorant Garamond", fontface = "plain", size = 2.9, colour = SEPIA),
  geom_rect(data = key, aes(xmin = xb, xmax = xb + 5200, ymin = yb - 1700, ymax = yb + 1700, fill = I(col)),
            colour = SEPIA, linewidth = .2),
  geom_text(data = key, aes(x = xb + 6800, y = yb, label = b), hjust = 0, family = "Cormorant Garamond",
            fontface = "bold", size = 3.3, colour = INK),
  geom_text(data = key, aes(x = cx + cw - 5000, y = yb, label = ifelse(share < .01, sprintf("%.1f%%", 100 * share), sprintf("%.0f%%", 100 * share))), hjust = 1,
            family = "Cormorant Garamond", fontface = "bold", size = 3.4, colour = INK),
  annotate("text", x = cx + cw / 2, y = cy - ch + 4300, label = "Contours every 200 metres",
           family = "Cormorant Garamond", fontface = "plain", size = 3, colour = SEPIA))

# ---- 4. map --------------------------------------------------------------------------------------
p <- ggplot() +
  geom_sf(data = sea, fill = SEA, colour = NA) +
  geom_sf(data = ripples, aes(alpha = I(0.7 - d / 6000)), colour = RIVER, linewidth = .18) +
  geom_raster(data = filter(hs_df, !inreg), aes(x, y, alpha = I(pmin(.22, pmax(0, 0.66 - shade) * 0.5))), fill = SEPIA) +
  geom_raster(data = cls_df, aes(x, y, fill = b), alpha = .78) +
  scale_fill_manual(values = setNames(tints, bands), guide = "none") +
  geom_raster(data = hs_df |> filter(inreg, shade < .64), aes(x, y, alpha = I(pmin(.55, (0.64 - shade) * 1.2))), fill = INK) +
  geom_raster(data = hs_df |> filter(inreg, shade > .66), aes(x, y, alpha = I(pmin(.5, (shade - 0.66) * 1.6))), fill = "#FFF8E6") +
  geom_sf(data = grat, colour = SEPIA, linewidth = .15, linetype = "22", alpha = .6) +
  geom_sf(data = cont, aes(linewidth = I(ifelse(index, .32, .14))), colour = "#6B4A33", alpha = .55) +
  geom_sf(data = coast, colour = INK, linewidth = .3) +
  geom_sf(data = reg, fill = NA, colour = INK, linewidth = .9, alpha = .25) +
  geom_sf(data = reg, fill = NA, colour = INK, linewidth = .3, linetype = "41") +
  geom_sf(data = rivers, colour = RIVER, linewidth = .38, alpha = .9) +
  geom_sf(data = lakes, fill = "#A9C0C8", colour = RIVER, linewidth = .2) +
  geom_shadowtext(data = mtn, aes(x, y, label = lab, angle = ang), family = "Playfair Display", fontface = "plain",
                  size = 3.5, colour = "#3A2618", bg.colour = alpha(PAPER, .8), bg.r = .09) +
  annotate("shadowtext", x = plain[1], y = plain[2], label = "T H E S S A L I A N    P L A I N",
           family = "Playfair Display", fontface = "plain", size = 3.7, colour = "#4F6B3B",
           bg.colour = alpha(PAPER, .6), bg.r = .12, angle = 8) +
  geom_point(data = towns, aes(x, y), shape = 21, size = 2.2, fill = PAPER, colour = INK, stroke = .6) +
  geom_point(data = towns, aes(x, y), size = .5, colour = INK) +
  geom_shadowtext(data = towns, aes(x + nx, y + ny, label = name, hjust = hj), family = "Cormorant Garamond",
                  fontface = "bold", size = 4, colour = INK, bg.colour = PAPER, bg.r = .15) +
  annotate("text", x = wgs(23.42, 39.76)[1], y = wgs(23.42, 39.76)[2], label = "A E G E A N   S E A",
           family = "Cormorant Garamond", fontface = "plain", size = 4, colour = RIVER, angle = 0) +
  cart +
  m30_scalebar(20, x = cx + cw / 2 - 10000, y = cy - ch + 10500, bbox = bb, col = INK, family = "Cormorant Garamond") +
  geom_sf(data = frame, fill = NA, colour = INK, linewidth = .9) +
  coord_sf(crs = CRS_GR, xlim = bb[c(1, 3)], ylim = bb[c(2, 4)], expand = FALSE, clip = "off",
           label_graticule = "SW") +
  theme_m30() +
  theme(plot.background = element_rect(fill = PAPER, colour = NA),
        panel.background = element_rect(fill = PAPER, colour = NA),
        plot.tag = element_markdown(colour = SEPIA),
        plot.title = element_markdown(family = "Playfair Display", face = "bold", size = 30, colour = INK,
                                      margin = margin(26, 0, 8, 0)),
        plot.subtitle = element_textbox_simple(family = "Cormorant Garamond", size = 15.5, colour = "#55412F",
                                               lineheight = 1.15, margin = margin(0, 0, 14, 0)),
        plot.caption = element_textbox_simple(colour = SEPIA),
        axis.text = element_text(family = "Cormorant Garamond", size = 9.5, colour = SEPIA),
        axis.ticks = element_line(colour = INK, linewidth = .3), axis.ticks.length = unit(3, "pt")) +
  m30_labs(
    6, "Vintage",
    title = sprintf("%.0f%% of Thessaly is plain, %.0f%% is mountain", 100 * below200, 100 * above1000),
    subtitle = sprintf(paste0(
      "Below 200 metres lies %s km² of flat land, the great plain of Larissa and Trikala; above 1,000 metres rise the ",
      "Pindus, Agrafa and Olympus. The ring of mountains holds the plain like a bowl, with one way out to the sea, ",
      "the Pineios through the Vale of Tempe."), format(round(below200 * km2, -1), big.mark = ",")),
    source = "Copernicus GLO-90 DEM (ESA, 2021) · OpenStreetMap rivers, lakes and peaks (Geofabrik, Oct 2026) · Eurostat NUTS 2021",
    accent = "#8C5A3C",
    extra = "shares of mainland land cells, 90 m grid")
m30_save(p, 6, "vintage", w = 10, h = 8, bg = PAPER)
