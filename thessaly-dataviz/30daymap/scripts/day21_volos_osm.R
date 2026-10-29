# day21 — OpenStreetMap: Volos between Pelion and the Pagasetic Gulf
# A poster of Volos from OpenStreetMap alone: sea, parks and woods, faint building footprints and every road, with
# line width by its place in the road hierarchy (motorway → residential → service & tracks). Strip below: km of road
# mapped per class inside the frame.
#
# Data
#   * OpenStreetMap, Geofabrik Greece extract 2026-10-28 (ODbL, © OpenStreetMap contributors), from
#     30daymap/cache/thessaly_osm.gpkg: lines (highway, natural = coastline), multipolygons (building, leisure = park,
#     landuse = forest, natural = wood, natural = water). https://download.geofabrik.de/europe/greece.html
#
# Caveats
#   * Land and sea come from polygonising the OSM coastline inside the frame; a face is land if any road crosses it.
#   * Road km = length of OSM highway ways clipped to the frame, dual carriageways counted twice (as mapped).
#   * Footways, paths, steps and cycleways are not counted as roads (they are drawn very faintly).
source("30daymap/R/m30_base.R")
DIR <- file.path(M30_CACHE, "osm_days"); dir.create(DIR, showWarnings = FALSE, recursive = TRUE)

PAPER <- "#FBFAF7"; SEA <- "#DCE6EA"; INK <- "#1F2A36"; ACC <- "#B4532A"; GREEN <- "#E3E8DA"

# ---- 1. data ----
W <- 15000; H <- 13000
c0 <- st_sfc(st_point(c(22.958, 39.372)), crs = 4326) |> st_transform(CRS_GR) |> st_coordinates()
fr <- st_as_sfc(st_bbox(c(xmin = c0[1] - W / 2, xmax = c0[1] + W / 2, ymin = c0[2] - H / 2, ymax = c0[2] + H / 2),
                        crs = st_crs(CRS_GR)))
fr_sf <- st_sf(geometry = fr)
clipf <- function(x) suppressWarnings(st_intersection(x, fr))

hw <- m30_osm("lines", "highway IS NOT NULL", clip = fr) |> clipf()
cl <- m30_osm("lines", "other_tags LIKE '%\"natural\"=>\"coastline\"%'", clip = fr)
cl_poly <- m30_osm("multipolygons", "\"natural\" = 'coastline'", clip = fr)
bld <- m30_osm("multipolygons", "building IS NOT NULL", clip = fr) |> st_make_valid() |> clipf()
green <- m30_osm("multipolygons", "leisure IN ('park','garden') OR landuse = 'forest' OR \"natural\" IN ('wood','scrub')",
                 clip = fr) |> st_make_valid() |> clipf()
water <- m30_osm("multipolygons", "\"natural\" = 'water'", clip = fr) |> st_make_valid() |> clipf()

# ---- 2. land and sea from the coastline ----
edges <- c(st_geometry(cl), st_cast(st_boundary(st_geometry(cl_poly)), "MULTILINESTRING")) |>
  st_intersection(fr) |> st_union()
faces <- st_polygonize(st_union(edges, st_boundary(fr))) |> st_collection_extract("POLYGON") |> st_sf(geometry = _)
main_hw <- filter(hw, highway %in% c("residential", "tertiary", "secondary", "primary", "unclassified", "track"))
faces$land <- lengths(st_intersects(faces, main_hw)) > 0
land <- filter(faces, land)
message(sprintf("Coastline faces: %d (land %d); land %.1f km² of the %.0f km² frame", nrow(faces), nrow(land),
                sum(as.numeric(st_area(land))) / 1e6, W * H / 1e6))

# ---- 3. road hierarchy & lengths ----
cls <- tribble(~highway, ~cl, ~lw,
  "motorway", "Motorway & trunk", 0.95, "motorway_link", "Motorway & trunk", 0.45, "trunk", "Motorway & trunk", 0.85,
  "trunk_link", "Motorway & trunk", 0.4,
  "primary", "Primary & secondary", 0.6, "primary_link", "Primary & secondary", 0.35,
  "secondary", "Primary & secondary", 0.5, "secondary_link", "Primary & secondary", 0.3,
  "tertiary", "Tertiary", 0.34, "tertiary_link", "Tertiary", 0.25,
  "residential", "Residential & local", 0.17, "unclassified", "Residential & local", 0.17,
  "living_street", "Residential & local", 0.15, "pedestrian", "Residential & local", 0.15,
  "service", "Service & tracks", 0.08, "track", "Service & tracks", 0.09, "road", "Residential & local", 0.15)
roads <- hw |> inner_join(cls, by = "highway"); roads$km <- as.numeric(st_length(roads)) / 1000
paths <- hw |> st_collection_extract("LINESTRING") |> filter(highway %in% c("footway", "path", "steps", "cycleway", "bridleway"))
km_cls <- roads |> st_drop_geometry() |> group_by(cl) |> summarise(km = sum(km), .groups = "drop") |>
  mutate(cl = factor(cl, c("Motorway & trunk", "Primary & secondary", "Tertiary", "Residential & local",
                           "Service & tracks"))) |> arrange(cl)
tot_km <- sum(km_cls$km)
message(sprintf("Roads in the frame: %.0f km (%s)", tot_km,
                paste(sprintf("%s %.0f", km_cls$cl, km_cls$km), collapse = "; ")))
message(sprintf("Paths & footways (not counted): %.0f km; buildings: %d", sum(as.numeric(st_length(paths))) / 1000,
                nrow(bld)))

# ---- 4. poster ----
fb <- st_bbox(fr)
strip_h <- 0.16 * H
ylim <- c(fb[["ymin"]] - strip_h, fb[["ymax"]])
lwd_of <- setNames(cls$lw, cls$highway)
roads <- roads |> mutate(top = cl %in% c("Motorway & trunk", "Primary & secondary"),
                         ord = match(cl, levels(km_cls$cl))) |> arrange(desc(ord))

# strip: proportional bar of road km per class, drawn in map units under the frame
sx <- km_cls |> mutate(x1 = fb[["xmin"]] + W * cumsum(km) / tot_km, x0 = lag(x1, default = fb[["xmin"]]),
                       col = c(ACC, INK, "#3E4A57", "#6B7682", "#B4BAC1"))
y_bar <- fb[["ymin"]] - 0.07 * H
# place labels at the OSM place nodes (name lookup in Greek, labels in English); the gulf label is placed by hand
en <- c("Βόλος" = "VOLOS", "Νέα Ιωνία" = "Nea Ionia", "Πορταριά" = "Portaria", "Μακρινίτσα" = "Makrinitsa",
        "Μακρυνίτσα" = "Makrinitsa", "Αγριά" = "Agria")
places <- m30_osm("points", sprintf("place IN ('city','town','village') AND name IN (%s)",
                                    paste0("'", names(en), "'", collapse = ",")), clip = fr) |>
  transmute(name = en[name], size = ifelse(name == "VOLOS", 4.2, 3)) |>
  st_set_geometry("geometry") |>
  bind_rows(st_sf(name = "Pagasetic Gulf", size = 3.4,
                  geometry = st_transform(st_sfc(st_point(c(22.95, 39.318)), crs = 4326), CRS_GR)))
message("Place labels from OSM: ", paste(places$name, collapse = ", "))
pc <- st_coordinates(places); places <- places |> st_drop_geometry() |> mutate(x = pc[, 1], y = pc[, 2])

p <- ggplot() +
  geom_sf(data = fr_sf, fill = SEA, colour = NA) +
  geom_sf(data = land, fill = PAPER, colour = NA) +
  geom_sf(data = green, fill = GREEN, colour = NA) +
  geom_sf(data = water, fill = SEA, colour = NA) +
  geom_sf(data = bld, fill = "#D9D6CF", colour = NA) +
  geom_sf(data = paths, colour = "#C9C6BF", linewidth = 0.08) +
  geom_sf(data = filter(roads, cl == "Service & tracks"), aes(linewidth = I(lw)), colour = "#8B939C", lineend = "round") +
  geom_sf(data = filter(roads, cl %in% c("Residential & local", "Tertiary")), aes(linewidth = I(lw)), colour = INK,
          lineend = "round") +
  geom_sf(data = filter(roads, cl == "Primary & secondary"), aes(linewidth = I(lw)), colour = INK, lineend = "round") +
  geom_sf(data = filter(roads, cl == "Motorway & trunk"), aes(linewidth = I(lw)), colour = ACC, lineend = "round") +
  geom_sf(data = fr_sf, fill = NA, colour = INK, linewidth = 0.35) +
  shadowtext::geom_shadowtext(data = places, aes(x, y, label = name, size = I(size)),
                              family = "Fira Sans Condensed", fontface = ifelse(places$name == "VOLOS", "bold", "plain"),
                              colour = INK, bg.colour = PAPER, bg.r = 0.15) +
  # strip
  annotate("text", x = fb[["xmin"]], y = fb[["ymin"]] - 0.025 * H, hjust = 0, vjust = 1,
           label = sprintf("%s KM OF ROAD MAPPED IN THIS FRAME", format(round(tot_km, -1), big.mark = ",")),
           family = "Fira Sans Condensed", size = 3, colour = M30$soft) +
  geom_rect(data = sx, aes(xmin = x0, xmax = x1, ymin = y_bar - 0.025 * H, ymax = y_bar, fill = I(col)),
            colour = "white", linewidth = 0.5) +
  geom_point(data = sx, aes(x = fb[["xmin"]] + (row_number(cl) - 1) * W / 5, y = y_bar - 0.05 * H, colour = I(col)),
             shape = 15, size = 2.6) +
  geom_text(data = sx, aes(x = fb[["xmin"]] + (row_number(cl) - 1) * W / 5 + 0.012 * W, y = y_bar - 0.05 * H,
            label = sprintf("%s\n%s km", cl, format(round(km), big.mark = ","))),
            hjust = 0, vjust = 0.75, family = "Fira Sans Condensed", size = 2.8, colour = M30$soft, lineheight = 0.95) +
  coord_sf(datum = NA, expand = FALSE, xlim = fb[c(1, 3)], ylim = ylim, clip = "off") +
  theme_m30() +
  m30_labs(21, "OpenStreetMap",
    title = sprintf("Volos, in %s km of mapped road", format(round(tot_km, -1), big.mark = ",")),
    subtitle = sprintf(paste0(
      "The port city between Mount Pelion and the Pagasetic Gulf, drawn only from OpenStreetMap. Line width follows the ",
      "road hierarchy, from the <b style='color:%s'>motorway</b> to the hairpins up to Portaria and Makrinitsa ",
      "and the service lanes and tracks of Pelion; %s building footprints in grey."),
      ACC, format(nrow(bld), big.mark = ",")),
    source = "© OpenStreetMap contributors, Geofabrik extract 2026-10-28 (ODbL): highway, coastline, building, park/wood, water",
    accent = ACC, extra = sprintf("Frame %d × %d km; footways and paths not counted", W / 1000, H / 1000))
m30_save(p, 21, "volos_osm", 8, 10)
