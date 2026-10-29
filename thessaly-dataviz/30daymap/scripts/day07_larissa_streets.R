# day07 — 10 minute map: which way do Larissa's streets run?
# Every drivable / walkable street inside 3 km of the centre of Larissa, split into straight segments. Each segment gets
# its compass bearing (folded to 0–180°, a street runs both ways). A polar histogram ("street orientation rose",
# after Geoff Boeing's OSMnx city roses) weights bearings by length. Streets within ±10° of the two dominant
# directions of the grid are coloured, everything else is grey.
#
# Data
#   * OpenStreetMap, Geofabrik Greece extract 2026-10-28 (ODbL, © OpenStreetMap contributors), layer lines, highway =
#     motorway…residential, living_street, pedestrian, unclassified, service excluded. Cached in thessaly_osm.gpkg.
#   * Centre: Larissa town centre from m30_base.R (39.6390 N, 22.4191 E).
#
# Caveats
#   * Bearings are computed in the Greek Grid (EGSA87, EPSG:2100); grid north differs from true north by < 1° here.
#   * Footways, service roads and tracks are excluded so the rose shows the street grid, not parking aisles.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork) })

# ---- 1. data ----
R_KM <- 3
ctr <- m30_towns |> filter(name == "Larissa")
circ <- st_buffer(ctr, R_KM * 1000, nQuadSegs = 90) |> st_geometry()
types <- c("motorway", "trunk", "primary", "secondary", "tertiary", "unclassified", "residential",
           "living_street", "pedestrian", "motorway_link", "trunk_link", "primary_link", "secondary_link",
           "tertiary_link")
st <- m30_osm("lines", sprintf("highway IN (%s)", paste0("'", types, "'", collapse = ",")), clip = circ)
st <- suppressWarnings(st_intersection(st, circ)) |> st_cast("MULTILINESTRING") |> st_cast("LINESTRING")
message(sprintf("%d street pieces inside %d km of the centre", nrow(st), R_KM))

# ---- 2. segments and bearings ----
xy <- st_coordinates(st) |> as_tibble()
seg <- xy |> group_by(L1) |>
  mutate(x2 = lead(X), y2 = lead(Y)) |> filter(!is.na(x2)) |> ungroup() |>
  mutate(len = sqrt((x2 - X)^2 + (y2 - Y)^2), brg = (atan2(x2 - X, y2 - Y) * 180 / pi) %% 180) |>
  filter(len > 0)
total_km <- sum(seg$len) / 1000

# dominant bearing: the 1°-bin with most length after smoothing ±5°; the second axis = the peak at least 60° away
h <- seg |> mutate(b = floor(brg)) |> count(b, wt = len) |> right_join(tibble(b = 0:179), by = "b") |>
  mutate(n = replace_na(n, 0)) |> arrange(b)
sm <- sapply(0:179, \(b) sum(h$n[((b + (-5:5)) %% 180) + 1]))
b1 <- which.max(sm) - 1
far <- abs(((0:179) - b1 + 90) %% 180 - 90) >= 60
b2 <- (0:179)[far][which.max(sm[far])]
dev <- function(b, ref) abs(((b - ref + 90) %% 180) - 90)
seg <- seg |> mutate(axis = case_when(dev(brg, b1) <= 10 ~ "a1", dev(brg, b2) <= 10 ~ "a2", TRUE ~ "other"))
sh <- seg |> group_by(axis) |> summarise(km = sum(len) / 1000) |> mutate(share = km / sum(km))
s12 <- sum(sh$share[sh$axis != "other"])
message(sprintf("Total %.0f km of street. Dominant bearings %d° and %d° (difference %d°)", total_km, b1, b2,
                dev(b2, b1)))
message(sprintf("Within ±10° of them: %.1f%% (axis 1 %.1f%%, axis 2 %.1f%%). A uniform city would give %.1f%%",
                100 * s12, 100 * sh$share[sh$axis == "a1"], 100 * sh$share[sh$axis == "a2"], 100 * 40 / 180))
compass <- function(b) c("N–S", "NNE–SSW", "NE–SW", "ENE–WSW", "E–W", "ESE–WNW", "SE–NW", "SSE–NNW")[
  (round(b / 22.5) %% 8) + 1]

# turn away from the compass: 0° = runs N–S or E–W, 45° = runs exactly diagonal (NE–SW / NW–SE)
seg <- seg |> mutate(turn = pmin(brg %% 90, 90 - brg %% 90),
                     cls = cut(turn, c(-1, 10, 30, 46), labels = c("compass", "between", "diagonal")))
cs <- seg |> group_by(cls) |> summarise(km = sum(len) / 1000) |> mutate(share = km / sum(km))
s_c <- cs$share[cs$cls == "compass"]; s_d <- cs$share[cs$cls == "diagonal"]
message(sprintf("Within 10° of N–S/E–W: %.1f%%; 10–30°: %.1f%%; within 15° of a diagonal: %.1f%% (uniform: 22%%, 56%%, 33%%)",
                100 * s_c, 100 * cs$share[cs$cls == "between"], 100 * s_d))

# ---- 3. map ----
C1 <- "#1D5C8C"; C3 <- "#C2410C"; GREY <- "#CFCFCF"
cols <- c(compass = C1, between = GREY, diagonal = C3)
segs_sf <- seg |> mutate(geometry = pmap(list(X, Y, x2, y2), \(a, b, c, d) st_linestring(matrix(c(a, c, b, d), 2)))) |>
  st_as_sf(crs = CRS_GR)
cx <- st_coordinates(ctr)
R <- R_KM * 1000
m <- ggplot() +
  geom_sf(data = circ, fill = NA, colour = M30$line, linewidth = 0.3) +
  geom_sf(data = filter(segs_sf, cls == "between"), colour = GREY, linewidth = 0.3) +
  geom_sf(data = filter(segs_sf, cls != "between"), aes(colour = cls), linewidth = 0.42) +
  annotate("point", x = cx[1], y = cx[2], shape = 21, fill = "white", colour = M30$ink, size = 2.2, stroke = 0.6) +
  scale_colour_manual(values = cols, guide = "none") +
  coord_sf(datum = NA, expand = FALSE, xlim = cx[1] + c(-1.12, 1.12) * R, ylim = cx[2] + c(-1.30, 1.03) * R) +
  theme_m30()

# ---- 4. rose: length per 5° bin, mirrored to 0–360 ----
rose <- seg |> mutate(bin = floor(brg / 5) * 5) |> group_by(bin) |>
  summarise(km = sum(len) / 1000, .groups = "drop") |>
  right_join(tibble(bin = seq(0, 175, 5)), by = "bin") |> mutate(km = replace_na(km, 0))
rose <- bind_rows(rose, mutate(rose, bin = bin + 180)) |>
  mutate(turn = pmin((bin + 2.5) %% 90, 90 - (bin + 2.5) %% 90),
         cls = cut(turn, c(-1, 10, 30, 46), labels = c("compass", "between", "diagonal")))
r <- ggplot(rose, aes(bin + 2.5, km, fill = cls)) +
  geom_col(width = 5, colour = "white", linewidth = 0.25) +
  annotate("text", x = c(0, 90, 180, 270), y = sqrt(max(rose$km)) * 1.2, label = c("N", "E", "S", "W"),
           family = "Fira Sans Condensed", size = 3.2, colour = M30$soft) +
  scale_fill_manual(values = cols, guide = "none") +
  scale_x_continuous(limits = c(0, 360), breaks = seq(0, 315, 45)) +
  scale_y_continuous(limits = c(0, sqrt(max(rose$km)) * 1.25), trans = "identity") +
  aes(y = sqrt(km)) +
  coord_polar(start = 0) +
  theme_void() +
  theme(panel.grid.major.x = element_line(colour = "#ECECEC", linewidth = 0.25))

# key: three stacked shares
key <- cs |> mutate(lab = c(compass = "run within 10° of N–S or E–W", between = "in between",
                            diagonal = "turned to the diagonal (NE–SW, NW–SE ±15°)")[as.character(cls)],
                    y = 3:1)
k <- ggplot(key) +
  geom_text(aes(0, y, label = sprintf("%.0f%%", 100 * share), colour = cls), hjust = 1, family = "Oswald",
            fontface = "bold", size = 6.5) +
  geom_text(aes(0.08, y, label = lab), hjust = 0, family = "Fira Sans Condensed", size = 3.3, colour = M30$soft) +
  annotate("text", x = -0.55, y = 4, label = "SHARE OF STREET LENGTH", hjust = 0, family = "Fira Sans Condensed",
           size = 2.9, colour = M30$soft) +
  scale_colour_manual(values = c(compass = C1, between = "#A7A7A7", diagonal = C3), guide = "none") +
  scale_x_continuous(limits = c(-0.6, 2.9)) + scale_y_continuous(limits = c(0.5, 4.3)) +
  theme_void()

# ---- 5. assemble ----
frac <- function(s) if (s < 0.333 && s > 0.28) "Fewer than a third" else if (abs(s - 0.25) < 0.02) "A quarter" else
  sprintf("%.0f%%", 100 * s)
title <- sprintf("%s of Larissa's streets<br>keep to the compass", frac(s_c))
p <- m + inset_element(k, left = -0.02, bottom = 0.0, right = 0.55, top = 0.2, align_to = "panel") +
  inset_element(r, left = 0.72, bottom = -0.01, right = 1.03, top = 0.26, align_to = "panel") +
  plot_annotation(theme = theme(plot.background = element_rect(fill = "white", colour = NA)))
p[[1]] <- p[[1]] + m30_labs(7, "A 10 minute map", title,
  subtitle = sprintf(paste0(
    "All %s km of street within %d km of the town centre (dot), cut into straight pieces and coloured by direction. ",
    "Larissa has no single grid: <b style='color:%s'>compass-true</b> blocks sit next to blocks ",
    "<b style='color:%s'>turned to the diagonal</b>. If directions were random, %.0f%% would keep to the compass; here %.0f%% do."),
    format(round(total_km), big.mark = ","), R_KM, C1, C3, 100 * 20 / 90, 100 * s_c),
  source = "© OpenStreetMap contributors, Geofabrik extract 2026-10-28 (ODbL), highway = residential and up (no service roads, tracks or footways)",
  accent = C3, extra = "Rose = street length per 5° of compass, after Geoff Boeing's OSMnx city roses") +
  theme(plot.title = element_markdown(lineheight = 0.95, margin = margin(26, 0, 14, 0)))
m30_save(p, 7, "larissa_streets", 8, 10)
