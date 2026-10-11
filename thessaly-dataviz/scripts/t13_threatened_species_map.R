# t13 — Where threatened species have been recorded in Thessaly
# Hex-bin map of GBIF occurrence records of globally threatened species (IUCN CR / EN / VU)
# + strip of the most-recorded species. Data: scripts/00_fetch_gbif_thessaly.R -> data/gbif_thessaly_threatened.csv
# Boundaries: Eurostat GISCO NUTS-3 2021 (EL611 Karditsa-Trikala, EL612 Larisa, EL613 Magnisia-Sporades)
#
# Honest caveats printed on the chart:
#   * GBIF records show where people looked (iNaturalist, bird atlases), not only where species live.
#   * Categories are the global IUCN Red List as served by GBIF, not the Greek Red Data Book (2009), which has no
#     open occurrence layer. A few GBIF category matches are odd (e.g. Oxalis corniculata flagged CR) — see caption.
#   * Coarse records (uncertainty > 10 km, e.g. 50-km bird-atlas squares) are dropped before binning.
suppressPackageStartupMessages({ library(tidyverse); library(sf); library(ggtext); library(patchwork) })

d <- read.csv("data/gbif_thessaly_threatened.csv")
fine <- d |>
  filter(is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 10000,
         is.na(datasetName) | !grepl("Atlas", datasetName)) |>
  mutate(cat = factor(iucnRedListCategory, c("CR", "EN", "VU")),
         group = case_when(class == "Aves" ~ "Birds",
                           class %in% c("Magnoliopsida", "Liliopsida", "Lycopodiopsida", "Polypodiopsida", "Pinopsida") ~ "Plants",
                           class %in% c("Testudines", "Amphibia", "Squamata") ~ "Reptiles & amphibians",
                           class %in% c("Insecta", "Arachnida", "Gastropoda", "Bivalvia", "Malacostraca") ~ "Invertebrates",
                           class == "Mammalia" ~ "Mammals",
                           class %in% c("Actinopterygii", "Elasmobranchii") | is.na(class) ~ "Fish & other",
                           TRUE ~ "Other"))
message(sprintf("%d of %d records kept (fine coordinates), %d species", nrow(fine), nrow(d), n_distinct(fine$species)))

# ---- geography ----------------------------------------------------------------------------------
crs_gr <- 2100
n3 <- read_sf("data/kontur/nuts3_2021.geojson") |> filter(substr(NUTS_ID, 1, 4) == "EL61") |> st_transform(crs_gr)
th <- st_union(n3)
pts <- st_as_sf(fine, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326) |> st_transform(crs_gr)
hex <- st_make_grid(th, cellsize = 7000, square = FALSE) |> st_as_sf() |> rename(geometry = x)
hex <- hex[lengths(st_intersects(hex, th)) > 0, ] |> mutate(id = row_number())
hex$n <- lengths(st_intersects(hex, pts))
hex$sp <- map_int(st_intersects(hex, pts), \(i) n_distinct(fine$species[i]))
hex <- hex |> mutate(nb = cut(n, c(-1, 0, 2, 5, 15, 40, Inf), labels = c("0", "1–2", "3–5", "6–15", "16–40", "> 40")))
cities <- tribble(~name, ~lon, ~lat, "Larissa", 22.4191, 39.6390, "Volos", 22.9425, 39.3622,
                  "Trikala", 21.7681, 39.5556, "Karditsa", 21.9222, 39.3650) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |> st_transform(crs_gr)
# hotspot call-outs (checked: top hexagons and their dominant species, see commit notes)
spots <- tribble(~name, ~lon, ~lat, ~dx, ~dy,
                 "Lake Karla\nducks & waders",            22.84, 39.52,  14000,  16000,
                 "Meteora\nEgyptian vulture, tortoise",   21.61, 39.71,   4000,  18000,
                 "Pelion\nfire salamander, spring snail", 23.08, 39.41,  20000,  -2000,
                 "Pineios at Larissa\nendemic fish",      22.30, 39.78,  10000,  14000,
                 "Olympus foothills\nendemic plants",     22.17, 40.05,  12000,   8000) |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326, remove = FALSE) |> st_transform(crs_gr)
sx <- st_coordinates(spots); spots <- spots |> mutate(x = sx[, 1], y = sx[, 2])

pal <- c("0" = "#F3F1EC", "1–2" = "#DCE7D2", "3–5" = "#A9CBA0", "6–15" = "#5E9E72", "16–40" = "#2A6B55", "> 40" = "#0F3D33")
catcol <- c(CR = "#B3241F", EN = "#E07B39", VU = "#D9BD6A")

map <- ggplot() +
  geom_sf(data = hex, aes(fill = nb), colour = "white", linewidth = .25) +
  geom_sf(data = n3, fill = NA, colour = "#191713", linewidth = .35) +
  geom_segment(data = spots, aes(x = x, y = y, xend = x + dx, yend = y + dy), colour = "#4a463d", linewidth = .3) +
  geom_text(data = spots, aes(x = x + dx, y = y + dy, label = name, hjust = ifelse(dx < 0, 1, 0),
                              vjust = ifelse(dy < 0, 1.1, -0.1)),
            family = "Fira Sans Condensed", size = 3, colour = "#4a463d", lineheight = .9) +
  geom_sf(data = cities, shape = 21, fill = "white", colour = "#191713", size = 2.2, stroke = .7) +
  geom_sf_text(data = cities, aes(label = name), family = "Fira Sans Condensed", size = 3.6, colour = "#191713",
               nudge_y = -5500, fontface = "bold") +
  scale_fill_manual(values = pal, name = "Records of threatened species per 7 km hexagon", drop = FALSE) +
  guides(fill = guide_legend(nrow = 1, title.position = "top", label.position = "bottom",
                             keywidth = unit(26, "pt"), keyheight = unit(8, "pt"))) +
  coord_sf(expand = FALSE, clip = "off") +
  theme_void(base_family = "Fira Sans") +
  theme(legend.position = "bottom", legend.justification = "left",
        legend.title = element_text(size = 9.5, colour = "#4a463d"),
        legend.text = element_text(size = 9, colour = "#4a463d"),
        plot.margin = margin(10, 10, 0, 0))

top <- fine |> count(species, cat, group, sort = TRUE) |> slice_head(n = 18) |>
  mutate(species = fct_rev(fct_inorder(species)), lab = paste0(n, "  ·  ", group))
strip <- ggplot(top, aes(n, species, fill = cat)) +
  geom_col(width = .7) +
  geom_text(aes(label = lab), hjust = -0.12, family = "Fira Sans Condensed", size = 3, colour = "#4a463d") +
  scale_fill_manual(values = catcol, labels = c(CR = "Critically endangered", EN = "Endangered", VU = "Vulnerable"),
                    name = NULL, drop = FALSE) +
  scale_x_continuous(expand = expansion(mult = c(0, .45))) +
  scale_y_discrete(expand = expansion(add = .6)) +
  labs(title = "The 18 most-recorded species") +
  theme_minimal(base_family = "Fira Sans") +
  theme(panel.grid = element_blank(), axis.title = element_blank(), axis.text.x = element_blank(),
        axis.text.y = element_text(family = "Fira Sans Condensed", size = 9.4, colour = "#191713", face = "italic"),
        legend.position = "top", legend.justification = "left", legend.text = element_text(size = 9, colour = "#4a463d"),
        legend.key.size = unit(9, "pt"),
        plot.title = element_text(family = "Oswald", size = 14, colour = "#191713", margin = margin(b = 2)),
        plot.margin = margin(10, 0, 0, 14))

n_sp <- n_distinct(fine$species); n_cr <- n_distinct(fine$species[fine$cat == "CR"])
top10 <- round(100 * sum(sort(hex$n, decreasing = TRUE)[1:10]) / sum(hex$n))
p <- (map + strip + plot_layout(widths = c(1.6, 1))) +
  plot_annotation(
    title = "Where Thessaly's threatened species have been seen",
    subtitle = glue::glue(
      "{format(nrow(fine), big.mark = ',')} records of {n_sp} species on the IUCN Red List (global categories CR, EN, VU) in GBIF, ",
      "{n_cr} of them critically endangered. Three places dominate: Lake Karla with its ducks and waders, ",
      "Meteora with the Egyptian vulture and Hermann's tortoise, and Mount Pelion with the fire salamander and a tiny spring snail. ",
      "The ten busiest hexagons hold {top10}% of all records.<br>",
      "<b>Read with care:</b> the map shows where observers looked (iNaturalist users, birders, museum collections), not only where the species live."),
    caption = glue::glue(
      "Data: GBIF occurrence API, retrieved {format(Sys.Date(), '%d %b %Y')}, iucnRedListCategory = CR/EN/VU, coordinate uncertainty ≤ 10 km ",
      "({nrow(d) - nrow(fine)} coarse records dropped, mostly 50 km squares of the EBCC breeding-bird atlas). ",
      "Categories are the global IUCN Red List as served by GBIF, not the Red Data Book of Greece (2009), which has no open occurrence data; ",
      "a few GBIF matches look doubtful (e.g. Oxalis corniculata as CR). Boundaries: Eurostat NUTS 2021. Chart: Loukas Theodosiou"),
    theme = theme(
      plot.background = element_rect(fill = "white", colour = NA),
      plot.title = element_text(family = "Oswald", face = "bold", size = 28, colour = "#191713", margin = margin(b = 6)),
      plot.subtitle = element_textbox_simple(size = 10.5, colour = "#4a463d", lineheight = 1.35, margin = margin(b = 10)),
      plot.caption = element_textbox_simple(size = 7.6, colour = "#8b8474", lineheight = 1.3, margin = margin(t = 12)),
      plot.margin = margin(22, 24, 16, 24)))
ggsave("out/t13_threatened_species_map.png", p, width = 14, height = 9, dpi = 200, device = ragg::agg_png, bg = "white")
message("Done: out/t13_threatened_species_map.png")
