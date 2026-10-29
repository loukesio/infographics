# #30DayMapChallenge 2026 · Day 10 · Prompting only — Thessaly's mountain ring
#
# The Thessalian plain is a lowland bowl walled in by mountains: Olympus and Ossa in the north-east,
# Pelion on the coast, Othrys in the south, Agrafa and the Pindus in the west, Chasia/Antichasia in the north.
# Land above 1,000 m is coloured on a hillshade; everything lower stays grey. Made by prompting only.
#
# Data
#   - Copernicus GLO-90 DEM (ESA / Airbus), AWS open data, via m30_dem()
#       https://registry.opendata.aws/copernicus-dem/
#   - OpenStreetMap natural=peak and natural=mountain_range nodes, Geofabrik Greece extract 2026-10-28
#       https://download.geofabrik.de/europe/greece.html  (© OpenStreetMap contributors, ODbL)
#   - Region border: Eurostat GISCO NUTS 2021 (EL61); GADM 4.1 via m30_base.R
#
# Caveats
#   - GDAL's default osmconf.ini drops the `ele` tag, so the shared thessaly_osm.gpkg has no heights.
#     This script re-reads the peak/range nodes from the cached Geofabrik .pbf with a config that keeps `ele`
#     (cached in 30daymap/cache/day10/peaks.gpkg).
#   - Heights are OSM `ele` tags as mapped, not DEM values. Ossa has no peak node with a height near its summit;
#     its 1,977 m is the `ele` of the OSM natural=mountain_range node "Όσσα".
#   - Mytikas (Olympus) lies ~1 km outside the GISCO Thessaly border (Pieria side); it is shown as the ring's top.
#   - Range of each peak = OSM mountain_range node it is nearest to / OSM peak name, not an official definition.
#   - Shares are of DEM cells (90 m, EGSA87) inside the mainland region border.

source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext) })

DAY <- 10; SLUG <- "prompting_only"; N_PROMPTS <- 2
ACC <- "#8C4A2F"                                   # burnt sienna accent
CDIR <- file.path(M30_CACHE, "day10"); dir.create(CDIR, showWarnings = FALSE)

# ---- 1. data: DEM ----------------------------------------------------------------------------------
reg  <- m30_region(TRUE)
dem  <- m30_dem(buffer = 6000)
demr <- mask(dem, vect(reg))
v    <- values(demr, na.rm = TRUE)[, 1]
share1000 <- mean(v > 1000); share500 <- mean(v > 500); share200 <- mean(v < 200)
message(sprintf("FINDING: %.1f%% of mainland Thessaly lies above 1,000 m; %.1f%% above 500 m; %.1f%% below 200 m",
                100 * share1000, 100 * share500, 100 * share200))

# ---- 2. data: OSM peaks with heights (re-read from the pbf, keeping `ele`) ---------------------------
pk_file <- file.path(CDIR, "peaks.gpkg")
if (!file.exists(pk_file)) {
  ini <- readLines(system.file("gdal/osmconf.ini", package = "sf"))
  ini <- sub("^ignore=created_by,converted_by,source,time,ele,", "ignore=created_by,converted_by,source,time,", ini)
  ini <- sub("^attributes=name,barrier,highway,ref,address,is_in,place,man_made$",
             "attributes=name,natural,ele,place,man_made", ini)
  writeLines(ini, file.path(CDIR, "osmconf_ele.ini"))
  pbf <- file.path(M30_CACHE, "greece.osm.pbf")
  if (!file.exists(pbf)) download.file("https://download.geofabrik.de/europe/greece-latest.osm.pbf", pbf, mode = "wb")
  gdal_utils("vectortranslate", pbf, pk_file, options = c(
    "-f", "GPKG", "-overwrite", "-oo", paste0("CONFIG_FILE=", file.path(CDIR, "osmconf_ele.ini")),
    "-spat", "20.8", "38.8", "24.4", "40.4",
    "-where", "natural IN ('peak','mountain_range')", "-nln", "peaks", "points"))
}
tag <- \(t, k) ifelse(grepl(sprintf('"%s"=>', k), t), sub(sprintf('.*"%s"=>"([^"]*)".*', k), "\\1", t), NA)
osm <- read_sf(pk_file) |> st_transform(CRS_GR) |>
  mutate(name_en = tag(other_tags, "name:en"), elev = suppressWarnings(as.numeric(ele)))
message(sum(osm$natural == "peak"), " OSM peaks in bbox, ", sum(osm$natural == "peak" & !is.na(osm$elev)), " with ele")

# The labelled summits: for each range, the highest OSM node (with ele) of that massif.
# Chosen from the OSM data (highest ele within ~10 km of the OSM mountain_range node, inside or on the border);
# English labels transliterate the OSM Greek name where name:en is missing.
pick <- tribble(
  ~osm_id,       ~range,        ~peak,                ~hj,  ~dx,    ~dy,
  "354099249",   "OLYMPUS",     "Mytikas",            0,     9000,   2500,   # just across the border
  "Ossa_range",  "OSSA",        "Highest point",         0,     7000,      0,
  "26864354",    "PELION",      "Pourianos Stavros",  0,     7000,   2000,
  "26865152",    "OTHRYS",      "Gerakovouni",        0,     7000,  -3000,
  "26864682",    "AGRAFA",      "Karava",             1,    -7000,  -4000,
  "2799721082",  "PINDUS",      "Brisimi",            1,    -7000,  -6000,
  "7274331195",  "CHASIA",      "Mytikas",            1,    -6000,   6500,
  "353186717",   "ANTICHASIA",  "Mamali",             0,     6000,   6000)
ossa <- osm |> filter(natural == "mountain_range", name == "Όσσα")
stopifnot(nrow(ossa) == 1)
peaks <- osm |> mutate(osm_id = ifelse(natural == "mountain_range" & name == "Όσσα", "Ossa_range", osm_id)) |>
  inner_join(pick, by = "osm_id") |> arrange(-elev)
stopifnot(nrow(peaks) == nrow(pick), all(!is.na(peaks$elev)))
peaks <- peaks |> mutate(real_id = ifelse(osm_id == "Ossa_range", ossa$osm_id, osm_id),
                         x = st_coordinates(geom)[, 1], y = st_coordinates(geom)[, 2])
print(st_drop_geometry(peaks) |> select(range, peak, name, name_en, ele, real_id, natural))

# Relief: Mytikas above the plain around Larissa (DEM at the town centre)
z_lar <- extract(dem, vect(filter(m30_towns, name == "Larissa")))$elev
rise  <- peaks$elev[peaks$range == "OLYMPUS"] - z_lar
message(sprintf("Mytikas (OSM ele %.1f m) rises %.0f m above Larissa (DEM %.0f m)",
                peaks$elev[peaks$range == "OLYMPUS"], rise, z_lar))

# ---- 3. raster layers for plotting --------------------------------------------------------------------
dem2 <- aggregate(dem, 2, mean, na.rm = TRUE)                     # 180 m is plenty at print size
hs   <- m30_hillshade(dem2, z = 2)
# m30_hillshade returns shade()/255, and shade() is already 0..1 here, so stretch it back to 0..1 (2-98% quantiles)
q  <- global(hs, quantile, probs = c(0.02, 0.98), na.rm = TRUE)
hs <- clamp((hs - q[[1]]) / (q[[2]] - q[[1]]), 0, 1); names(hs) <- "shade"
inside <- rasterize(vect(reg), dem2, touches = TRUE)
brks <- c(1000, 1500, 2000, 3000)
cls  <- classify(dem2, rcl = cbind(brks[-4], brks[-1], 1:3), right = FALSE, others = NA)
cls  <- mask(cls, inside); names(cls) <- "band"
levels(cls) <- data.frame(id = 1:3, band = c("1", "2", "3"))
pal  <- c(`1` = "#D9A88A", `2` = "#B26E4B", `3` = "#6E3220")      # one sienna ramp, light to dark
hs_in  <- mask(hs, inside)
hs_out <- mask(hs, inside, inverse = TRUE)
bb <- st_bbox(st_buffer(reg, 4000))

# ---- 4. map ----------------------------------------------------------------------------------------
lab_df <- st_drop_geometry(peaks) |>
  mutate(lab = sprintf("<span style='font-size:7.4pt;letter-spacing:1.5px;color:%s'><b>%s</b></span><br><span style='font-size:8.6pt;color:#1E1E1E'>%s <b>%s m</b></span>",
                       ACC, range, peak, format(round(elev), big.mark = ",")))

map <- ggplot() +
  geom_spatraster(data = hs_out, aes(fill = shade), maxcell = 4e6, show.legend = FALSE) +
  scale_fill_gradient(low = "#D6D6D6", high = "#FFFFFF", na.value = NA, limits = c(0, 1)) +
  ggnewscale::new_scale_fill() +
  geom_spatraster(data = hs_in, aes(fill = shade), maxcell = 4e6, show.legend = FALSE) +
  scale_fill_gradient(low = "#6F6F6F", high = "#E9E9E9", na.value = NA, limits = c(0, 1)) +
  ggnewscale::new_scale_fill() +
  geom_spatraster(data = cls, aes(fill = band), maxcell = 4e6, alpha = 0.72, show.legend = FALSE) +
  scale_fill_manual(values = pal, na.value = NA, na.translate = FALSE) +
  geom_sf(data = reg, fill = NA, colour = M30$ink, linewidth = 0.35) +
  geom_segment(data = lab_df, aes(x = x, y = y, xend = x + dx * 0.85, yend = y + dy * 0.85),
               colour = M30$ink, linewidth = 0.25) +
  geom_point(data = lab_df, aes(x, y), shape = 24, size = 2.1, fill = M30$ink, colour = "white", stroke = 0.4) +
  geom_richtext(data = lab_df, aes(x = x + dx, y = y + dy, label = lab, hjust = hj),
                family = "Fira Sans Condensed", lineheight = 1.05, fill = alpha("white", 0.82),
                label.colour = NA, label.padding = unit(c(1.5, 3, 1.5, 3), "pt"), label.r = unit(0, "pt"),
                vjust = 0.5) +
  geom_shadowtext(data = filter(m30_towns, name %in% c("Larissa", "Trikala", "Karditsa", "Volos")),
                  aes(geometry = geometry, label = name), stat = "sf_coordinates", family = "Fira Sans Condensed",
                  size = 3.1, colour = "#3A3A3A", bg.colour = "white", bg.r = 0.15) +
  annotate("text", x = 330000, y = 4385000, label = "T H E   P L A I N", family = "Fira Sans Condensed",
           size = 3.6, colour = "#4A4A4A", fontface = "bold") +
  m30_scalebar(20, bbox = bb, x = bb["xmin"] + 4000, y = bb["ymin"] + 4000) +
  coord_sf(crs = CRS_GR, xlim = bb[c("xmin", "xmax")], ylim = bb[c("ymin", "ymax")], expand = FALSE,
           datum = NA, clip = "off") +
  theme_void() + theme(plot.background = element_rect(fill = "white", colour = NA), plot.margin = margin(4, 40, 10, 40))

# ---- 5. second element: the labelled summits ranked -------------------------------------------------
bars <- st_drop_geometry(peaks) |>
  mutate(range_f = factor(range, levels = rev(range)))
key <- tibble(xmin = c(1000, 1500, 2000), xmax = c(1500, 2000, 3000), f = names(pal))
lol <- ggplot(bars, aes(y = range_f)) +
  geom_rect(data = key, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = f),
            inherit.aes = FALSE, alpha = 0.22, show.legend = FALSE) +
  scale_fill_manual(values = pal) +
  geom_vline(xintercept = z_lar, colour = M30$soft, linewidth = 0.3, linetype = "22") +
  annotate("text", x = z_lar + 40, y = 8.75, label = sprintf("Larissa, %d m", round(z_lar)), hjust = 0,
           family = "Fira Sans Condensed", size = 2.6, colour = M30$soft) +
  geom_segment(aes(x = 0, xend = elev, yend = range_f), colour = M30$ink, linewidth = 0.35) +
  geom_point(aes(x = elev), shape = 24, size = 2.3, fill = M30$ink, colour = "white", stroke = 0.4) +
  geom_text(aes(x = elev + 110, label = paste0(peak, "  ", format(round(elev), big.mark = ","), " m")),
            hjust = 0, family = "Fira Sans Condensed", size = 2.9, colour = M30$ink) +
  scale_x_continuous(limits = c(0, 4100), breaks = c(0, 1000, 2000, 3000),
                     labels = c("0", "1,000", "2,000", "3,000 m"), expand = c(0, 0)) +
  scale_y_discrete(expand = expansion(add = c(0.6, 1))) +
  labs(x = NULL, y = NULL) + coord_cartesian(clip = "off") +
  theme_minimal(base_family = "Fira Sans Condensed", base_size = 9) +
  theme(panel.grid = element_blank(),
        axis.text.y = element_text(colour = ACC, face = "bold", size = 7.5, hjust = 1),
        axis.text.x = element_text(colour = M30$soft, size = 7.5),
        axis.ticks.x = element_line(colour = M30$line, linewidth = 0.3), axis.ticks.length.x = unit(2, "pt"),
        plot.title = element_text(family = "Fira Sans", face = "bold", size = 9.5, colour = M30$ink),
        plot.subtitle = element_text(size = 8, colour = M30$soft, margin = margin(0, 0, 4, 0)),
        plot.background = element_rect(fill = "white", colour = NA)) +
  labs(title = "The highest summit of each wall",
       subtitle = sprintf("Mytikas stands %s m above the plain at Larissa", format(round(rise, -1), big.mark = ",")))

# hypsometric strip: share of Thessaly per 100 m band
hyp <- tibble(z = pmin(v, 2899)) |> mutate(band = floor(z / 100) * 100) |> count(band) |>
  mutate(share = n / sum(n), col = cut(band, c(-Inf, 1000, 1500, 2000, Inf), right = FALSE, labels = c("0", names(pal))))
hypp <- ggplot(hyp, aes(band + 50, share, fill = col)) +
  geom_col(width = 90, show.legend = FALSE) +
  scale_fill_manual(values = c(`0` = "#B9B9B9", pal)) +
  annotate("text", x = 1250, y = max(hyp$share) * 0.33, hjust = 0, family = "Fira Sans Condensed", size = 2.7,
           colour = ACC, label = sprintf("%d%% of the land\nis above 1,000 m", round(100 * share1000))) +
  annotate("text", x = 260, y = max(hyp$share) * 0.88, hjust = 0, vjust = 1, family = "Fira Sans Condensed",
           size = 2.7, colour = M30$soft, label = sprintf("%d%% lies below 200 m", round(100 * share200))) +
  scale_x_continuous(limits = c(0, 3000), breaks = c(0, 1000, 2000, 3000),
                     labels = c("0", "1,000", "2,000", "3,000 m"), expand = c(0, 0)) +
  scale_y_continuous(labels = \(s) paste0(round(100 * s), "%"), expand = expansion(mult = c(0, 0.05))) +
  labs(x = NULL, y = NULL, title = "How high the land is",
       subtitle = "Share of mainland Thessaly in each 100 m band") +
  theme_minimal(base_family = "Fira Sans Condensed", base_size = 9) +
  theme(panel.grid = element_blank(), panel.grid.major.y = element_line(colour = M30$line, linewidth = 0.2),
        axis.text = element_text(colour = M30$soft, size = 7.5),
        plot.title = element_text(family = "Fira Sans", face = "bold", size = 9.5, colour = M30$ink),
        plot.subtitle = element_text(size = 8, colour = M30$soft, margin = margin(0, 0, 4, 0)),
        plot.background = element_rect(fill = "white", colour = NA))

# ---- 6. assemble ---------------------------------------------------------------------------------
title <- "A sixth of Thessaly stands above 1,000 m,<br>a ring of mountains around a flat plain"
sub <- sprintf(paste0(
  "%d%% of the region lies below 200 m. Land above 1,000 m (%d%% of the area) is ",
  "<b style='color:#B26E4B'>coloured</b>, darker every 500 m: it sits on the rim. ",
  "Triangles mark the highest mapped summit of each range, height as tagged in OpenStreetMap."),
  round(100 * share200), round(100 * share1000))
src <- paste0("Copernicus GLO-90 DEM (ESA/Airbus) · peaks and heights © OpenStreetMap contributors (Geofabrik 2026-10-28, ",
              "natural=peak / mountain_range, ele tag) · border GADM/GISCO. Mytikas lies just across the regional border; ",
              "Ossa's height is the ele tag of its OSM range node")

tagline <- sprintf(paste0("<span style='font-family:\"Fira Sans Condensed\";font-weight:normal;font-size:11pt;color:%s;",
  "letter-spacing:2px'>#30DAYMAPCHALLENGE 2026 &nbsp;·&nbsp; DAY %02d &nbsp;·&nbsp; <b style='color:%s'>PROMPTING ONLY</b>",
  "</span><br>"), M30$soft, DAY, ACC)
p <- (map / (lol | hypp)) + plot_layout(heights = c(2.45, 1)) +
  plot_annotation(
    title = paste0(tagline, title), subtitle = sub,
    caption = paste0("<b>Data</b> ", src, " &nbsp;·&nbsp; Made by prompting only (", N_PROMPTS, " prompts)",
                     " &nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2"),
    theme = theme_m30() + theme(plot.title = element_markdown(size = 28, lineheight = 1.1, margin = margin(0, 0, 10, 0)),
                                 plot.subtitle = element_textbox_simple(size = 12, colour = M30$soft, lineheight = 1.3, margin = margin(0, 0, 12, 0)),
                                 plot.margin = margin(22, 26, 16, 26)))

m30_save(p, DAY, SLUG, w = 8, h = 10)
