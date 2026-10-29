# Day 04 · Clusters — the hotspots of Thessaly's threatened-species records, found with DBSCAN
# #30DayMapChallenge 2026, Thessaly series.
#
# Data
#   * data/gbif_thessaly_threatened.csv, built by scripts/00_fetch_gbif_thessaly.R from the GBIF occurrence API
#     (https://api.gbif.org/v1/occurrence/search, iucnRedListCategory = CR / EN / VU, retrieved 10 Oct 2026),
#     clipped to NUTS-2 EL61. Licences per record (CC0 / CC BY / CC BY-NC), see GBIF.
#   * Same filter as t13: coordinate uncertainty <= 10 km, EBCC bird-atlas squares dropped.
#   * Place names for the clusters: OpenStreetMap places nearest to each cluster centre (Geofabrik 2026-10-28),
#     checked by hand against the dominant species (Lake Karla = waterfowl, Meteora = Egyptian vulture ...).
# Method
#   * DBSCAN (package dbscan) on EGSA87 metres, eps = 3 km, minPts = 20 records. Records that are not in a
#     cluster are "noise" and drawn as small grey dots. Each cluster is drawn as its convex hull + 1.5 km, glowing.
# Caveats
#   * GBIF records show where people looked (iNaturalist users, birders, museums), not only where species live.
#   * Categories are the global IUCN Red List as served by GBIF, not the Greek Red Data Book.
#   * Clusters depend on eps/minPts; with eps 2–4 km and minPts 15–25 the three largest stay the same.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext); library(ggfx) })

# ---- 1. data -------------------------------------------------------------------------------------
d <- read.csv("data/gbif_thessaly_threatened.csv") |>
  filter(is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 10000,
         is.na(datasetName) | !grepl("Atlas", datasetName))
pts <- st_as_sf(d, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326) |> st_transform(CRS_GR)
xy  <- st_coordinates(pts)

# ---- 2. DBSCAN -----------------------------------------------------------------------------------
EPS <- 3000; MINPTS <- 20
set.seed(1)
pts$cl <- dbscan::dbscan(xy, eps = EPS, minPts = MINPTS)$cluster

# names checked against OSM places nearest each cluster centre and the cluster's dominant species
cl_sum <- pts |> filter(cl > 0) |> group_by(cl) |>
  summarise(n = n(), sp = n_distinct(species),
            top = names(sort(table(species), decreasing = TRUE))[1], .groups = "drop") |>
  arrange(desc(n)) |> mutate(rank = row_number())
cen <- st_coordinates(st_centroid(cl_sum)); cl_sum$cx <- cen[, 1]; cl_sum$cy <- cen[, 2]
near <- m30_osm("points", "place IN ('city','town','village','hamlet')", clip = NULL)
cl_sum$osm_near <- map_chr(seq_len(nrow(cl_sum)), \(i) near$name[which.min(st_distance(near, cl_sum[i, ]))])
print(st_drop_geometry(cl_sum))

# English names, keyed by the nearest OSM place (so a changed clustering fails loudly instead of mislabelling)
NAMES <- c("Κανάλια" = "Lake Karla", "Καλαμπάκα" = "Meteora", "Κισσός" = "Mount Pelion",
           "Βόλος" = "Volos shore", "Αργυροπούλι" = "Argyropouli", "Νάματα" = "Namata",
           "Δολίχη" = "Dolichi, Olympus foothills", "Θεόπετρα" = "Theopetra", "Βλαχάβα" = "Vlachava",
           "Βότση" = "Alonnisos")
WHAT <- c("Lake Karla" = "pochard, turtle dove, waders", "Meteora" = "Egyptian vulture, turtle dove",
          "Mount Pelion" = "fire salamander, spring snail", "Volos shore" = "grey plover, Audouin's gull",
          "Argyropouli" = "endemic fish Gobio feraeensis", "Namata" = "pochard",
          "Dolichi, Olympus foothills" = "dwarf beet Beta nana", "Theopetra" = "Centaurea kalambakensis",
          "Vlachava" = "turtle dove, Egyptian vulture", "Alonnisos" = "turtle dove, Audouin's gull")
stopifnot(all(cl_sum$osm_near %in% names(NAMES)))
cl_sum <- cl_sum |> mutate(name = NAMES[osm_near], what = WHAT[name])

n_rec <- nrow(pts); n_in <- sum(pts$cl > 0)
top3 <- sum(cl_sum$n[1:3]); sh3 <- top3 / n_rec
area3 <- cl_sum |> slice(1:3) |> st_convex_hull() |> st_buffer(1500) |> st_area() |> sum() |> as.numeric() / 1e6
area_th <- as.numeric(st_area(m30_region(FALSE))) / 1e6
message(sprintf("%d records, %d clusters (eps %d m, minPts %d), %d records in clusters (%.0f%%); top 3 = %d (%.1f%%) on %.0f km2 = %.2f%% of Thessaly",
                n_rec, nrow(cl_sum), EPS, MINPTS, n_in, 100 * n_in / n_rec, top3, 100 * sh3, area3, 100 * area3 / area_th))
write.csv(st_drop_geometry(cl_sum) |> select(rank, name, records = n, species = sp, top_species = top, osm_near, cx, cy),
          "30daymap/data/day04_clusters.csv", row.names = FALSE)

# hulls: convex hull of each cluster's records + 1.5 km, smoothed
hulls <- pts |> filter(cl > 0) |> group_by(cl) |> summarise(.groups = "drop") |> st_convex_hull() |>
  st_buffer(1500, nQuadSegs = 12) |> left_join(st_drop_geometry(cl_sum), by = "cl")

# ---- 3. map --------------------------------------------------------------------------------------
accent <- "#D9480F"
reg <- m30_region(FALSE); units <- m30_units(FALSE)
bb <- st_bbox(reg)
lab <- cl_sum |> st_drop_geometry() |> slice(1:7) |>
  mutate(txt = sprintf("**%s**<br><span style='color:%s'>%d records</span>", name, M30$soft, n),
         # label offsets in metres, chosen by hand so they sit in empty space
         dx = c( 16000,  -2000,  14000, -26000,  -8000,  10000,  -6000)[rank],
         dy = c( 15000,  20000, -16000, -12000,  14000,  14000,  10000)[rank],
         hj = c(0, .5, 0, 1, .5, 0, .5)[rank])
towns <- m30_towns |> filter(name %in% c("Larissa", "Trikala", "Karditsa"))
txy <- st_coordinates(towns); towns$x <- txy[, 1]; towns$y <- txy[, 2]

map <- ggplot() +
  geom_sf(data = reg, fill = M30$land, colour = NA) +
  geom_sf(data = units, fill = NA, colour = "white", linewidth = .6) +
  geom_sf(data = filter(pts, cl == 0), size = .45, colour = "#A9A29A", alpha = .8) +
  with_outer_glow(geom_sf(data = hulls, fill = accent, colour = NA, alpha = .9),
                  colour = accent, sigma = 10, expand = 8) +
  geom_sf(data = filter(pts, cl > 0), size = .35, colour = "white", alpha = .9) +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.6, stroke = .5) +
  geom_text(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", size = 2.9,
            colour = M30$soft, nudge_y = -4200) +
  geom_segment(data = lab, aes(cx, cy, xend = cx + dx * .85, yend = cy + dy * .8), colour = M30$ink, linewidth = .25) +
  ggtext::geom_richtext(data = lab, aes(cx + dx, cy + dy, label = txt, hjust = hj), family = "Fira Sans Condensed",
                        size = 3.2, colour = M30$ink, fill = alpha("white", .85), label.colour = NA, lineheight = 1.05,
                        label.padding = unit(1.5, "pt"), label.r = unit(0, "pt")) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, expand = FALSE, clip = "off")

# ---- 4. ranked strip: records per cluster --------------------------------------------------------
rk <- cl_sum |> st_drop_geometry() |>
  bind_rows(tibble(rank = 99, name = "Not in a cluster", n = n_rec - n_in, what = "scattered across the region")) |>
  mutate(name = factor(name, rev(name)), top3 = rank <= 3)
strip <- ggplot(rk, aes(n, name)) +
  geom_col(aes(fill = case_when(rank == 99 ~ "noise", top3 ~ "top", TRUE ~ "other")), width = .68) +
  geom_text(aes(label = sprintf("%d  ·  %s", n, what)), hjust = 0, nudge_x = 6, family = "Fira Sans Condensed",
            size = 3, colour = M30$soft) +
  scale_fill_manual(values = c(top = accent, other = "#F0A37A", noise = "#CFC9C1"), guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, .55))) +
  labs(title = sprintf("Records per cluster · the top three hold %d%% of all %s records", round(100 * sh3),
                       format(n_rec, big.mark = ","))) +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.y = element_text(family = "Fira Sans Condensed", size = 9.5, colour = M30$ink, hjust = 1,
                                   margin = margin(r = 4)),
        plot.title = element_text(face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 6)))

# ---- 5. assemble ---------------------------------------------------------------------------------
map <- map + m30_labs(4, "Clusters", accent = accent,
  title = sprintf("Three places hold %d%% of Thessaly's<br>threatened-species records", round(100 * sh3)),
  subtitle = sprintf(paste0(
    "Each glow is a cluster of GBIF records of globally threatened species (IUCN CR, EN, VU), found by DBSCAN ",
    "(at least %d records, neighbours closer than %d km). Lake Karla, Meteora and Mount Pelion cover %.1f%% of the ",
    "region but hold %s of its %s records. Grey dots: records outside any cluster.<br>",
    "<b>Read with care:</b> records show where people looked, not only where species live."),
    MINPTS, EPS / 1000, 100 * area3 / area_th, format(top3, big.mark = ","), format(n_rec, big.mark = ","))) +
  labs(caption = NULL) + theme_m30() + theme(plot.margin = margin(30, 36, 4, 36))
strip <- strip + labs(caption = paste0(
  "<b>Data</b> GBIF.org occurrence API, iucnRedListCategory = CR/EN/VU, retrieved 10 Oct 2026, coordinate uncertainty ≤ 10 km, ",
  "EBCC atlas squares removed · global IUCN categories, not the Greek Red Data Book · place names OpenStreetMap · ",
  "border Eurostat GISCO NUTS 2021 &nbsp;·&nbsp; DBSCAN eps 3 km, minPts 20 &nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2")) +
  theme(plot.caption = theme_m30()$plot.caption, plot.caption.position = "plot", plot.margin = margin(8, 36, 22, 36))
p <- (map / free(strip)) + plot_layout(heights = c(1.75, 1))
m30_save(p, 4, "species_clusters", w = 8, h = 10)
