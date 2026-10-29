# Day 24 · Network — Thessaly's road network as a hierarchy, from motorway to dirt track
# Every OSM road of mainland Thessaly drawn by class (line weight and ink fall with rank), the railway on top,
# and the route from the village furthest (by road) from any motorway exit.
#
# Data   : OpenStreetMap, Geofabrik Greece extract 2026-10-28 (© OpenStreetMap contributors, ODbL)
#          https://download.geofabrik.de/europe/greece.html — read from 30daymap/cache/thessaly_osm.gpkg
#          highway=* (lines), railway=rail (lines), railway=station (points), highway=motorway_junction (points),
#          place=village (points). Eurostat GISCO NUTS 2021 EL61 mainland border.
# Method : km per class = length of OSM ways clipped to the region (EGSA87). Road graph: every non-track road
#          (motorway … residential, links, living streets; no service roads, tracks or paths) split at its OSM
#          vertices; nodes joined where coordinates coincide (1 m). Distances by Dijkstra (igraph) from all
#          motorway exits (motorway_junction nodes inside the region) to every place=village, each snapped to the
#          nearest node of the largest connected piece of the graph.
# Caveats: OSM classes reflect mappers' tagging; tracks are very unevenly mapped. Road graph ignores one-way rules
#          and turn restrictions. Exits just outside the border (e.g. on the A1 in Phthiotis) are not counted.

source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext); library(igraph) })
DIR <- file.path(M30_CACHE, "day24"); dir.create(DIR, showWarnings = FALSE)
tg <- function(x, k) unname(vapply(x, \(s) {
  if (is.na(s)) return(NA_character_)
  m <- regmatches(s, regexpr(sprintf('"%s"=>"[^"]*"', k), s))
  if (length(m)) sub('.*=>"(.*)"', "\\1", m) else NA_character_ }, ""))

# ---- 1. data ----
reg <- m30_region(TRUE)
CLS <- c(motorway = "Motorway", motorway_link = "Motorway", trunk = "Main road", trunk_link = "Main road",
         primary = "Main road", primary_link = "Main road", secondary = "Secondary", secondary_link = "Secondary",
         tertiary = "Tertiary", tertiary_link = "Tertiary", unclassified = "Local & street",
         residential = "Local & street", living_street = "Local & street", track = "Track")
LV <- c("Motorway", "Main road", "Secondary", "Tertiary", "Local & street", "Track")
f <- file.path(DIR, "roads.rds")
if (!file.exists(f)) {
  rd <- m30_osm("lines", sprintf("highway IN (%s)", paste0("'", names(CLS), "'", collapse = ",")), reg) |>
    transmute(osm_id, highway, class = factor(CLS[highway], LV))
  rd <- st_sf(st_drop_geometry(rd), geometry = st_geometry(rd))
  rail <- m30_osm("lines", "railway = 'rail'", reg); rail <- st_sf(name = rail$name, geometry = st_geometry(rail))
  pts <- m30_osm("points", "highway = 'motorway_junction' OR place = 'village' OR hstore_get_value(other_tags,'railway') = 'station'", reg)
  pts <- st_sf(name = pts$name, highway = pts$highway, place = pts$place, en = tg(pts$other_tags, "name:en"),
               rail = tg(pts$other_tags, "railway"), geometry = st_geometry(pts))
  saveRDS(list(rd = rd, rail = rail, pts = pts), f)
}
invisible(list2env(readRDS(f), environment()))

# ---- 2. km per class (clipped) ----
rdc <- st_intersection(rd, st_geometry(reg))
rdc$km <- as.numeric(st_length(rdc)) / 1000
km <- rdc |> st_drop_geometry() |> group_by(class) |> summarise(km = sum(km)) |> mutate(sh = km / sum(km))
print(km)
write.csv(km, "30daymap/data/day24_road_km_by_class.csv", row.names = FALSE)
message(sprintf("FINDING: %s km of mapped road; tracks %.0f%%; motorway %.0f km", format(round(sum(km$km)), big.mark = ","),
                100 * km$sh[km$class == "Track"], km$km[km$class == "Motorway"]))

# ---- 3. road graph and distance to the nearest motorway exit ----
net <- rd |> filter(class != "Track") |> st_cast("LINESTRING", warn = FALSE)
xy <- st_coordinates(net)                                  # X, Y, L1 (line id)
key <- paste(round(xy[, 1]), round(xy[, 2]))
same <- c(xy[-1, 3] == xy[-nrow(xy), 3], FALSE)            # next vertex on the same line
ed <- data.frame(from = key[same], to = key[c(FALSE, same[-length(same)])],
                 w = sqrt(diff(xy[, 1])[same[-length(same)]]^2 + diff(xy[, 2])[same[-length(same)]]^2))
ed <- ed[ed$w > 0, ]
g <- graph_from_data_frame(ed, directed = FALSE)
cmp <- components(g); g <- induced_subgraph(g, which(cmp$membership == which.max(cmp$csize)))
vxy <- do.call(rbind, strsplit(V(g)$name, " ")) |> apply(2, as.numeric)
vpt <- st_as_sf(data.frame(x = vxy[, 1], y = vxy[, 2]), coords = c("x", "y"), crs = CRS_GR)
message(sprintf("graph: %d nodes, %d edges", vcount(g), ecount(g)))

exits <- filter(pts, highway == "motorway_junction")
vill  <- filter(pts, place == "village")
ex_v  <- unique(st_nearest_feature(exits, vpt))
vi_v  <- st_nearest_feature(vill, vpt)
vill$snap_m <- as.numeric(st_distance(vill, vpt[vi_v, ], by_element = TRUE))
D <- distances(g, v = ex_v, to = unique(vi_v), weights = E(g)$w)
dmin <- apply(D, 2, min); names(dmin) <- unique(vi_v)
vill$road_km <- (dmin[as.character(vi_v)] + vill$snap_m) / 1000
vill <- filter(vill, is.finite(road_km))
far <- vill |> arrange(desc(road_km)) |> slice(1)
message(sprintf("FINDING: %d exits, %d villages; median %.0f km by road to a motorway exit; furthest: %s (%s) %.0f km; %d villages > 50 km",
                length(ex_v), nrow(vill), median(vill$road_km), far$name, far$en, far$road_km, sum(vill$road_km > 50)))
write.csv(st_drop_geometry(vill) |> select(name, en, road_km, snap_m), "30daymap/data/day24_village_exit_km.csv",
          row.names = FALSE)

# route of the furthest village
fv <- st_nearest_feature(far, vpt)
src <- ex_v[which.min(D[, match(fv, unique(vi_v))])]
pth <- shortest_paths(g, from = fv, to = src, weights = E(g)$w)$vpath[[1]]
route <- st_sfc(st_linestring(vxy[as.integer(pth), ]), crs = CRS_GR)

# ---- 4. map ----
ACC <- "#C8102E"; RAIL <- "#1C3F6E"
W <- c(Motorway = 0.9, `Main road` = 0.5, Secondary = 0.32, Tertiary = 0.2, `Local & street` = 0.1, Track = 0.08)
C <- c(Motorway = ACC, `Main road` = "#1E1E1E", Secondary = "#3A3A3A", Tertiary = "#5E5E5E",
       `Local & street` = "#8A8A8A", Track = "#C4B89E")
rdc <- rdc |> mutate(class = factor(class, LV)) |> arrange(desc(class))
st  <- filter(pts, rail == "station")
bb  <- st_bbox(reg)
fxy <- st_coordinates(far); exy <- vxy[src, ]
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])

pm <- ggplot() +
  geom_sf(data = reg, fill = "#FBFAF7", colour = NA) +
  geom_sf(data = rdc, aes(linewidth = class, colour = class), lineend = "round") +
  scale_linewidth_manual(values = W, guide = "none") + scale_colour_manual(values = C, guide = "none") +
  geom_sf(data = rail, colour = "white", linewidth = 1.2) +
  geom_sf(data = rail, colour = RAIL, linewidth = 0.6) +
  geom_sf(data = st, shape = 21, size = 1.3, fill = "white", colour = RAIL, stroke = 0.5) +
  geom_sf(data = route, colour = "white", linewidth = 1.6) +
  geom_sf(data = route, colour = ACC, linewidth = 0.7, linetype = "11") +
  annotate("point", x = fxy[1], y = fxy[2], shape = 21, size = 2.6, fill = ACC, colour = "white", stroke = 0.6) +
  annotate("point", x = exy[1], y = exy[2], shape = 23, size = 2.4, fill = "white", colour = ACC, stroke = 0.8) +
  geom_shadowtext(data = towns, aes(x, y + 4000, label = name), family = "Fira Sans Condensed", fontface = "bold",
                  size = 3.2, colour = M30$ink, bg.colour = "white", bg.r = 0.15) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, datum = NA, expand = FALSE,
           xlim = c(bb["xmin"] - 3000, bb["xmax"] + 3000), ylim = c(bb["ymin"] - 3000, bb["ymax"] + 3000))
far_lab <- sprintf("%s · %.0f km by road\nto the nearest motorway exit", coalesce(far$en, far$name), far$road_km)
pm <- pm + geom_shadowtext(aes(x = fxy[1] + 5000, y = fxy[2] - 5000, label = far_lab), hjust = 0, vjust = 1,
                    family = "Fira Sans Condensed", size = 3.2, colour = ACC, lineheight = 0.95,
                    bg.colour = "white", bg.r = 0.2)

# ---- 5. km per class: line swatches + bars ----
kb <- km |> mutate(class = factor(class, rev(LV)), y = as.integer(class))
pb <- ggplot(kb) +
  geom_segment(aes(x = -0.36, xend = -0.26, y = y, yend = y, linewidth = class, colour = class), lineend = "round") +
  geom_text(aes(x = -0.24, y = y, label = class), hjust = 0, family = "Fira Sans Condensed", size = 3.3,
            colour = M30$ink) +
  geom_rect(aes(xmin = 0, xmax = sh, ymin = y - 0.3, ymax = y + 0.3, fill = class)) +
  geom_text(aes(x = sh + 0.01, y = y, label = sprintf("%s km · %.0f%%", format(round(km, -1), big.mark = ","), 100 * sh)),
            hjust = 0, family = "Fira Sans Condensed", size = 3.1, colour = M30$soft) +
  scale_linewidth_manual(values = W * 2.2, guide = "none") + scale_colour_manual(values = C, guide = "none") +
  scale_fill_manual(values = C, guide = "none") +
  annotate("text", x = -0.36, y = 6.95, label = "KILOMETRES OF MAPPED ROAD, BY CLASS", hjust = 0, family = "Oswald",
           size = 3.7, colour = M30$ink) +
  scale_x_continuous(limits = c(-0.37, 1.02), expand = c(0, 0)) +
  coord_cartesian(clip = "off", ylim = c(0.6, 7.1)) + theme_void()

L <- m30_labs(24, "Network",
  title = sprintf("%s km of road, %.0f%% of it dirt track", format(round(sum(km$km), -2), big.mark = ","),
                  100 * km$sh[km$class == "Track"]),
  subtitle = sprintf(paste0(
    "Every road in OpenStreetMap, from <b style='color:%s'>motorway</b> to farm track, drawn finer as it gets smaller; ",
    "the <b style='color:%s'>railway</b> in blue. Half of the %s villages on the map are within %.0f km of a motorway exit ",
    "by road; the furthest, %s, is %.0f km away."),
    ACC, RAIL, format(nrow(vill), big.mark = ","), median(vill$road_km), coalesce(far$en, far$name), far$road_km),
  source = "OpenStreetMap contributors, Geofabrik extract 2026-10-28 (ODbL) · Eurostat GISCO NUTS 2021, mainland Thessaly",
  accent = ACC)
cap <- L$caption; L$caption <- NULL
p <- (pm + L + theme_m30()) /
  (pb + labs(caption = cap) + theme_m30() + theme(plot.margin = margin(4, 36, 22, 36))) +
  plot_layout(heights = c(3.6, 1))
m30_save(p, 24, "network", 8, 10)
