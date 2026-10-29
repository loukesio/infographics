# Day 16 · Collaborative map — iNaturalist research-grade observations in Thessaly: how many people built this map
# #30DayMapChallenge 2026, Thessaly series.
#
# Data
#   * GBIF occurrence API, dataset "iNaturalist Research-grade Observations"
#     (datasetKey 50c9509d-22c7-4a22-a47d-8c48425ef4a7, https://www.gbif.org/dataset/50c9509d-22c7-4a22-a47d-8c48425ef4a7),
#     bbox 21.1–24.4 E / 38.9–40.25 N, clipped to NUTS-2 EL61 (incl. Sporades). Retrieved on the run date, cached in
#     30daymap/cache/gbif/day16_inat.rds. Licence of the records: CC0 / CC BY / CC BY-NC (per observer).
#   * Border: Eurostat GISCO NUTS 2021. Towns: m30_towns.
# Method
#   * 5 km hexagons; colour = number of distinct observers (GBIF field recordedBy) who made an observation there.
# Caveats
#   * Only "research grade" observations (identity agreed by the community) reach GBIF; casual records are missing.
#   * recordedBy is the observer's iNaturalist display name; one person with two accounts counts twice.
#   * Obscured observations (threatened species) are shifted by iNaturalist up to ~20 km; uncertainty > 10 km dropped.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(jsonlite); library(shadowtext) })

# ---- 1. data -------------------------------------------------------------------------------------
gbif_fetch <- function(query, cache, cols) {
  f <- file.path(M30_CACHE, "gbif", paste0(cache, ".rds"))
  if (file.exists(f)) return(readRDS(f))
  dir.create(dirname(f), showWarnings = FALSE, recursive = TRUE)
  bbox <- "POLYGON((21.1 38.9,24.4 38.9,24.4 40.25,21.1 40.25,21.1 38.9))"
  out <- list(); off <- 0
  repeat {
    url <- paste0("https://api.gbif.org/v1/occurrence/search?hasCoordinate=true&hasGeospatialIssue=false&",
                  query, "&geometry=", URLencode(bbox, reserved = TRUE), "&limit=300&offset=", off)
    j <- NULL
    for (a in 1:4) { j <- tryCatch(fromJSON(url, flatten = TRUE), error = \(e) NULL); if (!is.null(j)) break; Sys.sleep(5 * a) }
    if (is.null(j)) stop("GBIF request failed at offset ", off)
    if (!length(j$results)) break
    r <- j$results; for (cc in setdiff(cols, names(r))) r[[cc]] <- NA
    out[[length(out) + 1]] <- r[, cols]
    off <- off + 300
    if (isTRUE(j$endOfRecords)) break
    Sys.sleep(.3)
  }
  x <- bind_rows(out) |> distinct(key, .keep_all = TRUE)
  x$retrieved <- as.character(Sys.Date())
  saveRDS(x, f); x
}
cols <- c("key", "species", "kingdom", "class", "decimalLatitude", "decimalLongitude",
          "coordinateUncertaintyInMeters", "year", "month", "recordedBy")
# Deep offsets in the GBIF search API get very slow (> 2 min per page beyond ~20,000), so the download is split by
# year (largest year ~7,000 records) and each year is cached on its own: rerun to resume.
INAT <- "datasetKey=50c9509d-22c7-4a22-a47d-8c48425ef4a7"
f_all <- file.path(M30_CACHE, "gbif", "day16_inat.rds")
if (!file.exists(f_all)) {
  bbox <- "POLYGON((21.1 38.9,24.4 38.9,24.4 40.25,21.1 40.25,21.1 38.9))"
  fac <- fromJSON(paste0("https://api.gbif.org/v1/occurrence/search?hasCoordinate=true&hasGeospatialIssue=false&", INAT,
                         "&geometry=", URLencode(bbox, reserved = TRUE), "&limit=0&facet=year&facetLimit=200"))
  yrs <- as.integer(fac$facets$counts[[1]]$name)
  dir.create(file.path(M30_CACHE, "gbif", "day16_inat"), showWarnings = FALSE, recursive = TRUE)
  raw <- map(sort(yrs), \(y) { message("year ", y); gbif_fetch(paste0(INAT, "&year=", y), file.path("day16_inat", y), cols) }) |>
    bind_rows() |> distinct(key, .keep_all = TRUE)
  stopifnot(abs(nrow(raw) - sum(fac$facets$counts[[1]]$count)) < 50)
  saveRDS(raw, f_all)
}
raw <- readRDS(f_all)
reg <- m30_region(FALSE)
ob <- raw |> st_as_sf(coords = c("decimalLongitude", "decimalLatitude"), crs = 4326, remove = FALSE) |> st_transform(CRS_GR)
ob <- ob[lengths(st_intersects(ob, reg)) > 0, ]
n_in <- nrow(ob)
ob <- ob |> filter(is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 10000)
n_obs <- nrow(ob); n_people <- n_distinct(na.omit(ob$recordedBy)); n_sp <- n_distinct(na.omit(ob$species))
by_person <- ob |> st_drop_geometry() |> filter(!is.na(recordedBy)) |> count(recordedBy, sort = TRUE)
top10_sh <- sum(by_person$n[1:10]) / sum(by_person$n)
one_obs <- mean(by_person$n == 1)
half_k <- which(cumsum(by_person$n) >= sum(by_person$n) / 2)[1]
yr <- ob |> st_drop_geometry() |> filter(!is.na(year)) |> group_by(year) |>
  summarise(obs = n(), people = n_distinct(recordedBy), .groups = "drop")
message(sprintf(paste0("%d in bbox, %d inside Thessaly, %d kept; %d observers, %d species; top 10 observers = %.0f%%; ",
                       "%.0f%% of observers made one observation; %d observers made half of all"),
                nrow(raw), n_in, n_obs, n_people, n_sp, 100 * top10_sh, 100 * one_obs, half_k))
print(tail(yr, 12))

# ---- 2. hexagons: distinct observers per 5 km hex -------------------------------------------------
hex <- st_make_grid(reg, cellsize = 5000, square = FALSE) |> st_as_sf() |> rename(geometry = x)
hex <- hex[lengths(st_intersects(hex, reg)) > 0, ]
ii <- st_intersects(hex, ob)
hex$obs <- lengths(ii)
hex$people <- map_int(ii, \(i) n_distinct(ob$recordedBy[i], na.rm = TRUE))
sh_hex_seen <- mean(hex$obs > 0)
message(sprintf("%d hexagons, %.0f%% have at least one observation; max %d observers in one hexagon",
                nrow(hex), 100 * sh_hex_seen, max(hex$people)))
hc <- st_coordinates(st_transform(st_centroid(hex), 4326))
write.csv(hex |> st_drop_geometry() |> mutate(lon = round(hc[, 1], 4), lat = round(hc[, 2], 4)) |> filter(obs > 0),
          "30daymap/data/day16_inat_hex5km.csv", row.names = FALSE)
write.csv(yr, "30daymap/data/day16_inat_years.csv", row.names = FALSE)
brks <- c(0, 1, 3, 10, 30, 100, Inf)
labs_b <- c("1", "2–3", "4–10", "11–30", "31–100", "> 100")
hex <- hex |> mutate(pb = cut(people, brks, labs_b, right = TRUE))
pal <- c("#E7E4F3", "#C3BCE3", "#958AD0", "#6650B5", "#432C8F", "#22145A"); names(pal) <- labs_b
accent <- "#6650B5"
bb <- st_bbox(reg)
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Kalambaka"))
txy <- st_coordinates(towns); towns$x <- txy[, 1]; towns$y <- txy[, 2]

map <- ggplot() +
  geom_sf(data = reg, fill = M30$land, colour = NA) +
  geom_sf(data = filter(hex, people > 0), aes(fill = pb), colour = "white", linewidth = .15) +
  scale_fill_manual(values = pal, name = "People who observed in each 5 km hexagon", drop = FALSE) +
  guides(fill = guide_legend(nrow = 1, title.position = "top", label.position = "bottom",
                             keywidth = unit(30, "pt"), keyheight = unit(7, "pt"))) +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.7, stroke = .5) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", fontface = "bold", size = 3.1,
                  colour = M30$ink, bg.colour = "white", bg.r = .15, nudge_y = 4500) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, expand = FALSE, clip = "off")

# ---- 3. bottom: people per year, and the long tail of observers ------------------------------------
yr2 <- filter(yr, year >= 2010)
yp <- ggplot(yr2, aes(year, people)) +
  geom_col(fill = accent, width = .72) +
  geom_text(data = slice_max(yr2, people, n = 1), aes(label = people), vjust = -.5, family = "Fira Sans Condensed",
            size = 3, colour = M30$ink) +
  scale_x_continuous(breaks = seq(2010, 2026, 4), expand = expansion(add = .5)) +
  scale_y_continuous(expand = expansion(mult = c(0, .15))) +
  labs(title = sprintf("Observers per year (%d up to %s)", max(yr$year), format(as.Date(raw$retrieved[1]), "%d %b"))) +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.x = element_text(family = "Fira Sans Condensed", size = 9, colour = M30$soft, margin = margin(t = 3)),
        axis.line.x = element_line(colour = M30$mute, linewidth = .3),
        plot.title = element_text(face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 6)),
        plot.margin = margin(8, 14, 0, 36))
tail_d <- by_person |> mutate(rank = row_number(), cum = cumsum(n) / sum(n))
tp <- ggplot(tail_d, aes(rank, cum)) +
  geom_area(fill = "#E7E4F3") + geom_line(colour = accent, linewidth = .6) +
  annotate("point", x = half_k, y = .5, colour = M30$ink, size = 1.6) +
  annotate("text", x = half_k, y = .5, hjust = -.08, vjust = 1.3, family = "Fira Sans Condensed", size = 3,
           colour = M30$ink, label = sprintf("%d people made half\nof all observations", half_k), lineheight = .95) +
  scale_x_log10(breaks = c(1, 10, 100, 1000), labels = \(x) format(x, big.mark = ","), expand = expansion(mult = c(0, .02))) +
  scale_y_continuous(labels = scales::percent, breaks = c(0, .5, 1), expand = expansion(mult = c(0, .05))) +
  labs(title = "Share of observations made by the top N observers") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text = element_text(family = "Fira Sans Condensed", size = 9, colour = M30$soft, margin = margin(3, 3, 3, 3)),
        axis.line.x = element_line(colour = M30$mute, linewidth = .3),
        plot.title = element_text(face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 6)),
        plot.margin = margin(8, 36, 0, 14))

# ---- 4. assemble ---------------------------------------------------------------------------------
map <- map + m30_labs(16, "Collaborative map", accent = accent,
  title = sprintf("%s people built this map,<br>%d of them did half the work", format(n_people, big.mark = ","), half_k),
  subtitle = sprintf(paste0(
    "%s research-grade iNaturalist observations of %s species in Thessaly, each one checked by other users. ",
    "The darker a hexagon, the more people photographed wildlife there. Meteora, Volos, Pelion and the Sporades are well covered; ",
    "%d%% of the 5 km hexagons, mostly on the farmed plain, have none. The ten keenest observers made %d%% of all records."),
    format(n_obs, big.mark = ","), format(n_sp, big.mark = ","), round(100 * (1 - sh_hex_seen)), round(100 * top10_sh))) +
  labs(caption = NULL) + theme_m30() +
  theme(plot.margin = margin(30, 36, 4, 36), legend.position = "inside", legend.position.inside = c(1, 1),
        legend.justification = c(1, 1))
cap <- paste0("<b>Data</b> iNaturalist research-grade observations via GBIF.org (datasetKey 50c9509d…), retrieved ",
  raw$retrieved[1], ", coordinate uncertainty ≤ 10 km · observers counted by the recordedBy name · records CC0 / CC BY / CC BY-NC · ",
  "border Eurostat GISCO NUTS 2021 &nbsp;·&nbsp; thanks to every iNaturalist observer and identifier ",
  "&nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2")
p <- (map / free(yp | tp)) + plot_layout(heights = c(2.6, 1)) +
  plot_annotation(caption = cap, theme = theme(
    plot.caption = element_textbox_simple(family = "Fira Sans", size = 13 * .68, colour = M30$soft, lineheight = 1.25,
                                          margin = margin(14, 0, 0, 0)),
    plot.margin = margin(0, 0, 22, 0), plot.background = element_rect(fill = "white", colour = NA)))
m30_save(p, 16, "inaturalist", w = 8, h = 10)
