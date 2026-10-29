# Day 20 · Hexagons — "Half of Thessaly lives in 8 hexagons"
# Kontur's 400 m population hexagons summed into their H3 resolution-6 parents (about 36 km² each) and drawn as
# hexagonal prisms in a hand-made oblique view: height = residents. The 8 tallest prisms, which together hold half
# of the people, are in the accent colour; a strip below shows all hexagons ranked.
#
# Data   : Kontur Population Greece 2023-11-01, 400 m H3 hexagons (res 8), HDX, CC BY 4.0
#          https://data.humdata.org/dataset/kontur-population-greece
#          H3 grid (Uber, Apache 2.0) via h3jsr · Eurostat GISCO NUTS 2021 EL61 mainland border
# Method : res-8 hexagons with centre inside mainland Thessaly → parent cell at res 6 (h3jsr::get_parent) → sum.
#          Prisms projected with screen_y = 0.62·y + z (view from the south), drawn back to front (painter's order),
#          only south-facing walls drawn. Heights linear in population.
# Caveats: Kontur is modelled population (2023). Res-6 cells on the border stick out of the region slightly.
#          Sporades excluded.

source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(h3jsr) })

# ---- 1. data ----
reg <- m30_region(TRUE)
pop <- read_sf("data/kontur/kontur_population_GR_20231101.gpkg") |> st_transform(CRS_GR)
cen <- suppressWarnings(st_centroid(pop))
pop <- pop[lengths(st_intersects(cen, reg)) > 0, ] |> st_drop_geometry()
hx <- pop |> mutate(h6 = get_parent(h3, res = 6)) |> group_by(h6) |> summarise(pop = sum(population)) |>
  arrange(desc(pop)) |> mutate(rank = row_number(), cs = cumsum(pop) / sum(pop))
N50 <- which(hx$cs >= 0.5)[1]
poly <- cell_to_polygon(hx$h6, simple = FALSE) |> st_transform(CRS_GR)
hx$km2 <- as.numeric(st_area(poly)) / 1e6
hx$top <- hx$rank <= N50
land_sh <- sum(hx$km2[hx$top]) / sum(hx$km2)
message(sprintf("FINDING: %d of %d res-6 hexagons hold %.1f%% of %s people on %.1f%% of the hexagon area (%.0f of %.0f km2)",
                N50, nrow(hx), 100 * hx$cs[N50], format(sum(hx$pop), big.mark = ","), 100 * land_sh,
                sum(hx$km2[hx$top]), sum(hx$km2)))
write.csv(select(hx, h6, pop, rank, km2), "30daymap/data/day20_h3res6_population.csv", row.names = FALSE)

# nearest town (of the 9 in m30_towns) to each top hexagon, if within 12 km — for labels
hc <- suppressWarnings(st_centroid(poly))
nt <- st_nearest_feature(hc, m30_towns)
hx$town <- ifelse(as.numeric(st_distance(hc, m30_towns[nt, ], by_element = TRUE)) < 12000, m30_towns$name[nt], NA)

# ---- 2. oblique projection of prisms ----
TILT <- 0.62; ZMAX <- 62000                              # tallest prism, in metres of screen height
hx$z <- hx$pop / max(hx$pop) * ZMAX
vx <- st_coordinates(poly) |> as.data.frame() |> transmute(x = X, y = Y, id = L2) |>
  group_by(id) |> slice(-n()) |> mutate(k = row_number()) |> ungroup()
vx$z <- hx$z[vx$id]; vx$cy <- ave(vx$y, vx$id)          # hexagon centre y for drawing order
grey_of <- function(p) colorRampPalette(c("#ECE9E3", "#C4BFB6", "#8E887F"))(100)[pmin(100, 1 + floor(99 * sqrt(p / hx$pop[N50 + 1])))]
ACC <- "#D9480F"; ACC_D <- "#9C3208"
hx$col_top  <- ifelse(hx$top, ACC, grey_of(hx$pop))
hx$col_side <- ifelse(hx$top, ACC_D, colorspace::darken(grey_of(hx$pop), 0.25))

tops <- vx |> mutate(X = x, Y = TILT * y + z, grp = id)
walls <- vx |> group_by(id) |>
  mutate(x2 = lead(x, default = first(x)), y2 = lead(y, default = first(y)),
         ccw = sum(x * y2 - x2 * y) > 0) |> ungroup() |>
  mutate(ny = ifelse(ccw, -(x2 - x), (x2 - x))) |>       # y-component of the outward normal
  filter(z > 0, ny < 0) |>                                # south-facing walls only
  mutate(wid = paste(id, k)) |>
  rowwise() |>
  mutate(poly = list(tibble(X = c(x, x2, x2, x),
                            Y = c(TILT * y, TILT * y2, TILT * y2 + z, TILT * y + z)))) |>
  ungroup() |> select(id, wid, cy, ny, poly) |> unnest(poly)

# painter's order: north (large y) first; within a hexagon, walls then top
ord <- hx |> mutate(id = row_number(), cy = vx$cy[match(id, vx$id)]) |> arrange(desc(cy)) |> pull(id)
walls$o <- match(walls$id, ord); tops$o <- match(tops$id, ord)
layers <- bind_rows(
  walls |> transmute(o, sub = 1, g = wid, X, Y, fill = hx$col_side[id]),
  tops  |> transmute(o, sub = 2, g = paste(id, "t"), X, Y, fill = hx$col_top[id])) |>
  arrange(o, sub) |> mutate(g = factor(g, unique(g)))

ground <- st_coordinates(reg) |> as.data.frame() |> transmute(X = X, Y = TILT * Y, g = paste(L1, L2))
bb <- st_bbox(reg)

lab <- hx |> mutate(id = row_number()) |> filter(top) |>
  left_join(tops |> group_by(id) |> summarise(lx = mean(X), ly = max(Y)), by = "id")
print(select(lab, rank, pop, town))
lab_txt <- lab |> filter(!is.na(town)) |> group_by(town) |>
  summarise(n = n(), parts = paste(format(round(sort(pop, decreasing = TRUE), -2), big.mark = ",", trim = TRUE),
                                    collapse = " + "),
            pop = sum(pop), lx = lx[which.max(ly)], ly = max(ly)) |>
  mutate(txt = sprintf("%s\n%s%s", toupper(town), format(round(pop, -2), big.mark = ","),
                       ifelse(n > 1, sprintf(" in %d hexagons%s", n, ifelse(town == "Larissa", paste0("\n(", parts, ")"), "")),
                              " in 1 hexagon")),
         dx = case_when(town == "Tyrnavos" ~ -16000, town == "Karditsa" ~ 7000, TRUE ~ 0),
         dy = ifelse(town == "Tyrnavos", 12000, 0))
towns_txt <- lab_txt |> arrange(desc(pop)) |> pull(town)
towns_txt <- paste0(paste(head(towns_txt, -1), collapse = ", "), " and ", tail(towns_txt, 1))
YTOP <- max(tops$Y) + 16000

pm <- ggplot() +
  geom_polygon(data = ground, aes(X, Y, group = g), fill = "#F4F2EE", colour = "#D6D2CA", linewidth = 0.3) +
  geom_polygon(data = layers, aes(X, Y, group = g, fill = I(fill)), colour = "white", linewidth = 0.12) +
  geom_segment(data = lab_txt, aes(lx, ly + 1500, xend = lx + dx, yend = ly + 9000 + dy), colour = M30$soft, linewidth = 0.25) +
  geom_text(data = lab_txt, aes(lx + dx, ly + 10000 + dy, label = txt), family = "Oswald", size = 3.1, colour = M30$ink,
            vjust = 0, lineheight = 0.95) +
  coord_equal(expand = FALSE, xlim = c(bb["xmin"] - 4000, bb["xmax"] + 4000),
              ylim = c(TILT * bb["ymin"] - 6000, YTOP), clip = "off")

# ---- 3. strip: all hexagons ranked, as a row of small hexagons ----
nr <- 5; ncol_ <- ceiling(nrow(hx) / nr)
hexpts <- function(cx, cy, r) tibble(x = cx + r * cos(pi / 6 + 0:5 * pi / 3), y = cy + r * sin(pi / 6 + 0:5 * pi / 3))
st <- hx |> mutate(i = rank - 1, col = i %/% nr, row = i %% nr,
                   cx = col * 1.0 + (row %% 2) * 0.5, cy = -row * 0.87) |>
  rowwise() |> mutate(p = list(hexpts(cx, cy, 0.56))) |> ungroup() |> select(rank, top, pop, p) |> unnest(p)
pb <- ggplot(st, aes(x, y, group = rank)) +
  geom_polygon(aes(fill = I(ifelse(top, ACC, grey_of(pop))))) +
  annotate("text", x = -1, y = 1.15, hjust = 0, vjust = 0, family = "Oswald", size = 3.8, colour = M30$ink,
           label = sprintf("ALL %d HEXAGONS, MOST TO LEAST PEOPLE", nrow(hx))) +
  annotate("text", x = N50 / nr + 1.2, y = -4.3, hjust = 0, vjust = 1, family = "Fira Sans Condensed", size = 3.3,
           colour = ACC, label = sprintf("the first %d: %.0f%% of the people on %.0f%% of the land", N50,
                                         100 * hx$cs[N50], 100 * land_sh)) +
  annotate("segment", x = N50 / nr + 1.1, xend = N50 / nr + 0.4, y = -4.4, yend = -3.7, colour = ACC, linewidth = 0.3) +
  coord_equal(clip = "off", xlim = c(-1, ncol_ + 1), ylim = c(-5.4, 2)) + theme_void()

L <- m30_labs(20, "Hexagons",
  title = sprintf("Half of Thessaly lives in %d hexagons", N50),
  subtitle = sprintf(paste0(
    "Thessaly cut into %d hexagons of about %.0f km² each; the height of each prism is the number of residents. ",
    "The <b style='color:%s'>%d tallest</b>, in %s, hold %.0f%% of the region's %s people. ",
    "Volos fits in one hexagon, so it stands tallest; Larissa is bigger but is cut into %d."),
    nrow(hx), median(hx$km2), ACC, N50, towns_txt, 100 * hx$cs[N50], format(round(sum(hx$pop), -3), big.mark = ","),
    lab_txt$n[lab_txt$town == "Larissa"]),
  source = "Kontur Population 2023, 400 m H3 hexagons summed to H3 resolution 6 (HDX, CC BY) · Eurostat GISCO NUTS 2021, mainland Thessaly",
  accent = ACC)
cap <- L$caption; L$caption <- NULL
p <- (pm + L + theme_m30()) / (pb + labs(caption = cap) + theme_m30() + theme(plot.margin = margin(0, 36, 22, 36))) +
  plot_layout(heights = c(4, 0.85))
m30_save(p, 20, "hexagons", 8, 8.7)
