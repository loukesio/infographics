# Day 11 · Sound — where Thessaly has been recorded: every GBIF occurrence that comes with a sound file
# #30DayMapChallenge 2026, Thessaly series.
#
# Data
#   * GBIF occurrence API, mediaType = Sound, inside Thessaly (bbox query, then clipped to NUTS-2 EL61 incl. Sporades).
#     https://api.gbif.org/v1/occurrence/search?mediaType=Sound&geometry=<bbox>   (retrieved on the run date, cached in
#     30daymap/cache/gbif/day11_sound.rds). The datasets returned are mostly xeno-canto (Orthoptera, Chiroptera, birds,
#     soundscapes; CC BY-NC 4.0), plus ZFMK DORSA (Orthoptera sound archive, Bonn; CC BY 4.0) and iNaturalist.
#   * Border: Eurostat GISCO NUTS 2021.
# Caveats
#   * The map shows where recordists went (often one expert on one trip), not where the animals are loudest.
#   * Old archive recordings (DORSA) can have coarse coordinates; records with uncertainty > 10 km are dropped.
#   * xeno-canto bird recordings are only partly in GBIF, so birds are under-represented compared with xeno-canto itself.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(jsonlite); library(shadowtext) })

# ---- 1. data: GBIF search API, paged, cached --------------------------------------------------------
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
cols <- c("key", "species", "scientificName", "vernacularName", "class", "order", "family", "decimalLatitude",
          "decimalLongitude", "coordinateUncertaintyInMeters", "year", "datasetKey", "datasetName", "recordedBy")
raw <- gbif_fetch("mediaType=Sound", "day11_sound", cols)
reg <- m30_region(FALSE)
snd <- raw |> st_as_sf(coords = c("decimalLongitude", "decimalLatitude"), crs = 4326, remove = FALSE) |>
  st_transform(CRS_GR)
snd <- snd[lengths(st_intersects(snd, reg)) > 0, ]
message(sprintf("%d sound records in bbox, %d inside Thessaly", nrow(raw), nrow(snd)))
# dataset titles from https://api.gbif.org/v1/dataset/<key> (xeno-canto records come without datasetName)
DS <- c("ecce3417-d4fd-4fab-9009-09ad3f3f62b3" = "xeno-canto Orthoptera", "6bd8ad26-218d-4657-8549-c30d69356664" = "xeno-canto Chiroptera",
        "72309d40-0c1f-47d6-8008-33e687b7df7a" = "ZFMK DORSA", "50c9509d-22c7-4a22-a47d-8c48425ef4a7" = "iNaturalist",
        "b1047888-ae52-4179-9dd5-5448ea342a24" = "xeno-canto birds", "ff571aeb-46bf-45c4-ad2c-af4d68315765" = "xeno-canto soundscapes")
snd$dataset <- coalesce(DS[snd$datasetKey], snd$datasetName, "other")
print(count(st_drop_geometry(snd), dataset, sort = TRUE))
snd <- snd |> filter(is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 10000) |>
  mutate(group = case_when(order == "Orthoptera" ~ "Grasshoppers & crickets",
                           order == "Chiroptera" ~ "Bats",
                           class == "Aves" ~ "Birds",
                           class == "Amphibia" ~ "Frogs & toads",
                           TRUE ~ "Other & soundscapes"),
         group = factor(group, c("Grasshoppers & crickets", "Bats", "Birds", "Frogs & toads", "Other & soundscapes")))
n_rec <- nrow(snd); n_sp <- n_distinct(na.omit(snd$species))
n_rec_people <- n_distinct(na.omit(snd$recordedBy))
top_rec <- snd |> st_drop_geometry() |> filter(!is.na(recordedBy)) |> count(recordedBy, sort = TRUE) |> slice(1)
top_rec_grp <- snd |> st_drop_geometry() |> filter(recordedBy == top_rec$recordedBy) |> count(group, sort = TRUE)
print(top_rec); print(top_rec_grp)
ds_tab <- snd |> st_drop_geometry() |> count(dataset, sort = TRUE)
grp <- snd |> st_drop_geometry() |> count(group) |> mutate(sh = n / sum(n))
message(sprintf("%d recordings (uncertainty <= 10 km), %d species, %d recordists", n_rec, n_sp, n_rec_people))
print(grp)
ll <- st_coordinates(st_transform(snd, 4326))
write.csv(snd |> st_drop_geometry() |> transmute(key, species, group, dataset, year, recordedBy,
                                                 lon = round(ll[, 1], 4), lat = round(ll[, 2], 4)),
          "30daymap/data/day11_sound.csv", row.names = FALSE)

# ---- 2. glyphs: each recording site = concentric rings, more rings = more recordings ---------------
pal <- c("Grasshoppers & crickets" = "#6A8D2F", "Bats" = "#3B3B8F", "Birds" = "#C77D1A",
         "Frogs & toads" = "#2E8C8C", "Other & soundscapes" = "#9A9A9A")
pal <- pal[levels(droplevels(snd$group))]
accent <- "#3B3B8F"
# group recordings at the same spot (1 km grid) and group
sites <- snd |> mutate(gx = round(st_coordinates(geometry)[, 1] / 1000), gy = round(st_coordinates(geometry)[, 2] / 1000)) |>
  st_drop_geometry() |> group_by(gx, gy, group) |> summarise(n = n(), .groups = "drop") |>
  mutate(x = gx * 1000, y = gy * 1000)
rings <- sites |> mutate(nr = pmin(1 + floor(log2(n)), 6)) |> uncount(nr, .id = "r") |>
  mutate(size = 1 + (r - 1) * 1.35, alpha = pmax(1 - (r - 1) * .14, .3))

units <- m30_units(FALSE); bb <- st_bbox(reg)
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Kalambaka"))
txy <- st_coordinates(towns); towns$x <- txy[, 1]; towns$y <- txy[, 2]

map <- ggplot() +
  geom_sf(data = reg, fill = M30$land, colour = NA) +
  geom_sf(data = units, fill = NA, colour = "white", linewidth = .6) +
  geom_point(data = arrange(rings, desc(r)), aes(x, y, colour = group, size = size, alpha = alpha),
             shape = 1, stroke = .45) +
  geom_point(data = sites, aes(x, y, colour = group), size = .6) +
  scale_size_identity() + scale_alpha_identity() +
  scale_colour_manual(values = pal, guide = "none") +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.6, stroke = .5) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", size = 3,
                  colour = M30$ink, bg.colour = "white", bg.r = .15, nudge_y = -4300) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, expand = FALSE, clip = "off")

# ---- 3. strip: most-recorded species ---------------------------------------------------------------
top <- snd |> st_drop_geometry() |> filter(!is.na(species)) |> count(species, group, sort = TRUE) |>
  slice_head(n = 12) |> mutate(species = forcats::fct_rev(forcats::fct_inorder(species)))
strip <- ggplot(top, aes(n, species, fill = group)) +
  geom_col(width = .66) +
  geom_text(aes(label = n), hjust = 0, nudge_x = 1, family = "Fira Sans Condensed", size = 3, colour = M30$soft) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, .12))) +
  labs(title = "The 12 most-recorded species") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.y = element_text(family = "Fira Sans Condensed", face = "italic", size = 9.5, colour = M30$ink,
                                   hjust = 1, margin = margin(r = 4)),
        plot.title = element_text(face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 6)))
key <- grp |> filter(group %in% names(pal)) |> arrange(n) |> mutate(group = factor(group, group))
keyp <- ggplot(key, aes(n, group, fill = group)) +
  geom_col(width = .66) +
  geom_text(aes(label = sprintf("%d  (%d%%)", n, round(100 * sh))), hjust = 0, nudge_x = 6,
            family = "Fira Sans Condensed", size = 3, colour = M30$soft) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_x_continuous(expand = expansion(mult = c(0, .35))) +
  labs(title = "Recordings by who is singing") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.y = element_text(family = "Fira Sans Condensed", size = 9.5, colour = M30$ink,
                                   hjust = 1, margin = margin(r = 4), face = "bold"),
        plot.title = element_text(face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 6)))

# ---- 4. assemble -----------------------------------------------------------------------------------
lead <- grp |> slice_max(n, n = 1)
map <- map + m30_labs(11, "Sound", accent = accent,
  title = sprintf("Thessaly on tape: %s recordings,<br>%s of them grasshoppers", format(n_rec, big.mark = ","),
                  if (abs(lead$sh - .5) < .05) "half" else paste0(round(100 * lead$sh), "%")),
  subtitle = sprintf(paste0(
    "Every sound recording from Thessaly shared on GBIF: %s recordings of %d species by %d recordists, 1980–%d. ",
    "Each set of rings is a recording spot; more rings, more recordings (1, 2–3, 4–7 …). ",
    "Half are grasshoppers and bush-crickets (%d%%), then birds (%d%%) and bats (%d%%). ",
    "One recordist, %s, made %d of them."),
    format(n_rec, big.mark = ","), n_sp, n_rec_people, max(snd$year, na.rm = TRUE),
    round(100 * grp$sh[grp$group == "Grasshoppers & crickets"]), round(100 * grp$sh[grp$group == "Birds"]),
    round(100 * grp$sh[grp$group == "Bats"]), top_rec$recordedBy, top_rec$n)) +
  labs(caption = NULL) + theme_m30() + theme(plot.margin = margin(30, 36, 4, 36))
cap <- paste0(
    "<b>Data</b> GBIF.org occurrence API, mediaType = Sound, retrieved ", raw$retrieved[1],
    ": ", paste(sprintf("%s %d", ds_tab$dataset, ds_tab$n), collapse = ", "),
    " (xeno-canto CC BY-NC 4.0, DORSA CC BY 4.0) · coordinate uncertainty ≤ 10 km · border Eurostat GISCO NUTS 2021 &nbsp;·&nbsp; the map shows where ",
    "recordists went, not where animals sing most &nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2")
keyp  <- keyp  + theme(plot.margin = margin(10, 10, 0, 36))
strip <- strip + theme(plot.margin = margin(10, 36, 0, 20))
p <- (map / free(keyp | strip)) + plot_layout(heights = c(1.9, 1)) +
  plot_annotation(caption = cap, theme = theme(
    plot.caption = element_textbox_simple(family = "Fira Sans", size = 13 * .68, colour = M30$soft, lineheight = 1.25,
                                          margin = margin(14, 0, 0, 0)),
    plot.margin = margin(0, 0, 22, 0), plot.background = element_rect(fill = "white", colour = NA)))
m30_save(p, 11, "sound", w = 8, h = 10)
