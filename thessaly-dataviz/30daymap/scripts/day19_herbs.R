# Day 19 · Smell — Thessaly's aromatic herbs: where oregano, thyme, sage, mountain tea, savory, mint and lavender
# have been recorded. #30DayMapChallenge 2026, Thessaly series.
#
# Data
#   * GBIF occurrence API, one query per genus (taxonKey from https://api.gbif.org/v1/species/match):
#     Origanum 2926611, Thymus 2926960, Salvia 2926981, Sideritis 2926685, Satureja 2926882, Mentha 2927173,
#     Lavandula 2927302. https://api.gbif.org/v1/occurrence/search?taxonKey=<key>&geometry=<bbox>
#     Retrieved on the run date, cached in 30daymap/cache/gbif/day19_<genus>.rds, clipped to NUTS-2 EL61.
#     Main datasets: Herbarium Berolinense (Berlin, CC0), Lund University botanical collection (CC BY-NC),
#     iNaturalist research-grade (CC BY-NC), Herbarium Willing (Berlin), ETH/University of Zurich herbaria.
#   * Elevation: Copernicus GLO-90 DEM (via m30_dem()). Border: Eurostat GISCO NUTS 2021.
# Caveats
#   * Records show where botanists and app users looked, not where the herbs grow most. Most records are old
#     herbarium sheets from collecting trips to the mountains (Olympus, Pindos, Pelion), which biases them upward.
#   * Pl@ntNet "automatically identified" records are dropped (machine IDs). Coordinate uncertainty > 10 km dropped.
#   * Salvia includes rosemary (Salvia rosmarinus), often planted. Satureja and Lavandula are merged (few records).
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(jsonlite) })

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
cols <- c("key", "species", "genus", "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters",
          "year", "datasetKey", "datasetName", "basisOfRecord", "recordedBy")
G <- c(Origanum = 2926611, Thymus = 2926960, Salvia = 2926981, Sideritis = 2926685, Satureja = 2926882,
       Mentha = 2927173, Lavandula = 2927302)
raw <- imap(G, \(k, g) gbif_fetch(paste0("taxonKey=", k), paste0("day19_", tolower(g)), cols) |> mutate(genus_q = g)) |>
  bind_rows() |> distinct(key, .keep_all = TRUE)
PLANTNET <- "14d5676a-2c54-4f94-9023-1e8dcd822aa0"
reg <- m30_region(FALSE)
h <- raw |> st_as_sf(coords = c("decimalLongitude", "decimalLatitude"), crs = 4326, remove = FALSE) |> st_transform(CRS_GR)
h <- h[lengths(st_intersects(h, reg)) > 0, ]
n_in <- nrow(h)
h <- h |> filter(datasetKey != PLANTNET, is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 10000)

LAB <- c(Thymus = "Thyme", Salvia = "Sage", Mentha = "Mint", Sideritis = "Mountain tea", Origanum = "Oregano",
         Other = "Savory & lavender")
h <- h |> mutate(g = if_else(genus_q %in% c("Satureja", "Lavandula"), "Other", genus_q))

dem <- m30_dem(crop = NULL)
h$elev <- pmax(terra::extract(dem, vect(h))$elev, 0)
h <- filter(h, !is.na(elev))
land_hi <- global(mask(m30_dem(crop = reg, buffer = 0), vect(reg)) > 500, "mean", na.rm = TRUE)[[1]]

gs <- h |> st_drop_geometry() |> group_by(g) |>
  summarise(n = n(), sp = n_distinct(species, na.rm = TRUE), hi = mean(elev > 500), med = median(elev),
            .groups = "drop") |> arrange(desc(n)) |> mutate(lab = LAB[g])
h <- h |> mutate(g = factor(g, gs$g), lab = factor(LAB[as.character(g)], gs$lab))
gs <- gs |> mutate(lab = factor(lab, gs$lab))
n_rec <- nrow(h); sh_hi <- mean(h$elev > 500)
ds <- h |> st_drop_geometry() |> mutate(ds = case_when(
  datasetKey %in% c("85714c48-f762-11e1-a439-00145eb45e9a", "85727f1e-f762-11e1-a439-00145eb45e9a") ~ "Berlin herbarium (B)",
  datasetKey == "aab0cf80-0c64-11dd-84d1-b8a03c50a862" ~ "Lund herbarium (LD)",
  datasetKey == "50c9509d-22c7-4a22-a47d-8c48425ef4a7" ~ "iNaturalist",
  TRUE ~ "other")) |> count(ds, sort = TRUE)
sh_herb <- mean(h$basisOfRecord == "PRESERVED_SPECIMEN")
message(sprintf("%d records inside Thessaly, %d kept; %.0f%% above 500 m (land above 500 m: %.0f%%); %.0f%% herbarium specimens",
                n_in, n_rec, 100 * sh_hi, 100 * land_hi, 100 * sh_herb))
print(gs); print(ds)
ll <- st_coordinates(st_transform(h, 4326))
write.csv(h |> st_drop_geometry() |> transmute(key, genus = genus_q, species, year, basisOfRecord, datasetKey,
                                                lon = round(ll[, 1], 4), lat = round(ll[, 2], 4), elev = round(elev)),
          "30daymap/data/day19_herbs.csv", row.names = FALSE)

# ---- 2. small multiples --------------------------------------------------------------------------
pal <- c(Thyme = "#CC79A7", Sage = "#0072B2", Mint = "#009E73", `Mountain tea` = "#E69F00", Oregano = "#D55E00",
         `Savory & lavender` = "#56B4E9")
accent <- "#7A4B9A"
hs <- m30_hillshade(aggregate(m30_dem(crop = reg, buffer = 0), 4)) |> mask(vect(reg))
mtn <- aggregate(m30_dem(crop = reg, buffer = 0), 4) |> mask(vect(reg))
mtn <- classify(mtn, cbind(-Inf, 500, NA))         # land above 500 m, drawn as a pale tint
bb <- st_bbox(reg)
gl <- gs |> mutate(txt = sprintf("<b style='color:%s'>%s</b> <span style='color:%s'>&nbsp;%d records · %d%% above 500 m</span>",
                                 pal[as.character(lab)], lab, M30$soft, n, round(100 * hi)))
strip_lab <- setNames(gl$txt, as.character(gl$lab))

maps <- ggplot() +
  geom_sf(data = reg, fill = "#F4F2EE", colour = NA) +
  geom_spatraster(data = mtn, aes(fill = after_stat(ifelse(is.na(value), NA, "hi"))), maxcell = 5e5) +
  scale_fill_manual(values = c(hi = "#E4DFD6"), na.value = NA, guide = "none") +
  geom_sf(data = h, aes(colour = lab), size = .9, alpha = .85) +
  scale_colour_manual(values = pal, guide = "none") +
  facet_wrap(~lab, ncol = 2, labeller = as_labeller(strip_lab)) +
  coord_sf(crs = CRS_GR, expand = FALSE, datum = NA) +
  theme_void(base_family = "Fira Sans") +
  theme(strip.text = ggtext::element_markdown(family = "Fira Sans Condensed", size = 9.6, hjust = 0, margin = margin(0, 0, 3, 0)),
        panel.spacing.x = unit(14, "pt"), panel.spacing.y = unit(10, "pt"), strip.clip = "off")

# ---- 3. elevation strip: records vs land ----------------------------------------------------------
land <- as.data.frame(mask(m30_dem(crop = reg, buffer = 0), vect(reg)), na.rm = TRUE) |> slice_sample(n = 4000)
set.seed(19)
elev_p <- ggplot() +
  annotate("rect", xmin = 500, xmax = Inf, ymin = -Inf, ymax = Inf, fill = "#F4F1EA") +
  geom_violin(data = land, aes(pmax(elev, 0), "All of Thessaly"), fill = "#D9D4CB", colour = NA, scale = "width", width = .8) +
  geom_jitter(data = st_drop_geometry(h), aes(elev, "Herb records", colour = lab), height = .28, width = 0, size = .9, alpha = .8) +
  geom_vline(xintercept = 500, colour = M30$ink, linewidth = .3) +
  annotate("text", x = 520, y = 2.55, hjust = 0, family = "Fira Sans Condensed", size = 3.2, colour = M30$ink,
           label = sprintf("%d%% of herb records lie above 500 m, but only %d%% of the land", round(100 * sh_hi), round(100 * land_hi))) +
  scale_colour_manual(values = pal, guide = "none") +
  scale_x_continuous(breaks = seq(0, 2500, 500), labels = \(x) paste0(format(x, big.mark = ","), " m"), expand = expansion(add = 20)) +
  scale_y_discrete(limits = c("All of Thessaly", "Herb records"), expand = expansion(add = c(.5, .9))) +
  labs(title = "Height of every herb record, against the height of the land") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.x = element_text(family = "Fira Sans Condensed", size = 9, colour = M30$soft, margin = margin(t = 3)),
        axis.text.y = element_text(family = "Fira Sans Condensed", size = 9.5, colour = M30$ink, hjust = 1, margin = margin(r = 6)),
        plot.title = element_text(face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 4)),
        plot.margin = margin(10, 36, 0, 36))

# ---- 4. assemble ---------------------------------------------------------------------------------
top <- gs |> slice(1)
hi_lo <- top                                               # most-recorded genus (it is also the lowest-lying)
hi2 <- gs |> filter(n >= 90, g != top$g) |> arrange(desc(hi)) |> slice(1:2)   # big genera with most records up high
stopifnot(top$hi < land_hi)
maps <- maps + m30_labs(19, "Smell", accent = accent,
  title = sprintf("%s rules the plain,<br>%s and %s the mountains", hi_lo$lab[1], tolower(hi2$lab[1]), tolower(hi2$lab[2])),
  subtitle = sprintf(paste0(
    "%s GBIF records of seven aromatic herb genera. %s is the most recorded (%d), but only %d%% of its records lie above ",
    "500 m; for %s it is %d%% and for %s %d%%, against %d%% of the land (pale tint). ",
    "%d%% are old herbarium sheets. <b>Read with care:</b> records show where people looked, not where herbs grow most."),
    format(n_rec, big.mark = ","), top$lab, top$n, round(100 * top$hi), tolower(hi2$lab[1]), round(100 * hi2$hi[1]),
    tolower(hi2$lab[2]), round(100 * hi2$hi[2]), round(100 * land_hi), round(100 * sh_herb))) +
  labs(caption = NULL) + theme_m30() +
  theme(plot.margin = margin(30, 36, 4, 36),
        strip.text = ggtext::element_markdown(family = "Fira Sans Condensed", size = 9.6, hjust = 0, margin = margin(0, 0, 3, 0)),
        panel.spacing.x = unit(14, "pt"), panel.spacing.y = unit(10, "pt"), strip.clip = "off")
cap <- paste0("<b>Data</b> GBIF.org occurrence API, genera Origanum, Thymus, Salvia, Sideritis, Satureja, Mentha, Lavandula, ",
  "retrieved ", raw$retrieved[1], ": ", paste(sprintf("%s %d", ds$ds, ds$n), collapse = ", "),
  " · Pl@ntNet machine IDs and records with uncertainty > 10 km removed · elevation Copernicus GLO-90 · ",
  "border Eurostat GISCO NUTS 2021 &nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2")
p <- (maps / free(elev_p)) + plot_layout(heights = c(3.4, 1)) +
  plot_annotation(caption = cap, theme = theme(
    plot.caption = element_textbox_simple(family = "Fira Sans", size = 13 * .68, colour = M30$soft, lineheight = 1.25,
                                          margin = margin(14, 0, 0, 0)),
    plot.margin = margin(0, 0, 22, 0), plot.background = element_rect(fill = "white", colour = NA)))
m30_save(p, 19, "herbs", w = 8, h = 10)
