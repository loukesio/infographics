# Day 13 · Interactions — an interactive map of Thessaly with five layers you can switch on and off
# Output 1: 30daymap/out/day13_interactions.html  (leaflet, self-contained; base tiles CARTO Positron, no token)
# Output 2: 30daymap/out/day13_interactions.png   (headless-Chrome screenshot via webshot2, framed with the series look)
#
# Data
#   Kontur Population Greece 2023-11-01 (400 m H3 cells, CC BY 4.0)
#     https://data.humdata.org/dataset/kontur-population-greece   -> data/kontur/kontur_population_GR_20231101.gpkg
#     summed here to H3 resolution 6 (~36 km² hexagons) with h3jsr
#   OpenStreetMap waterway=river, Geofabrik Greece extract 2026-10-28 (ODbL) — via m30_osm()
#   GBIF occurrences of IUCN CR/EN/VU species in Thessaly, fetched 2026-10-10 by scripts/00_fetch_gbif_thessaly.R
#     -> data/gbif_thessaly_threatened.csv (https://api.gbif.org/v1/occurrence/search)
#   Municipalities: GADM 4.1 level 3 (25 Kallikratis municipalities) · towns: m30_towns
# Caveats
#   * GBIF records show where people looked, not only where species live. Records with coordinate
#     uncertainty > 10 km and the EBCC bird atlas are dropped (as in t13).
#   * OSM "river" tags include some seasonal streams; km are clipped to the region incl. Sporades.
#   * Kontur is a modelled population grid (GHSL + buildings), not the census.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(leaflet); library(htmlwidgets); library(h3jsr) })

# ---- 1. data ----
reg   <- m30_region(FALSE)
muni  <- m30_municipalities()
reg84 <- st_transform(reg, 4326)

# population: Kontur 400 m cells inside Thessaly
kon <- read_sf("data/kontur/kontur_population_GR_20231101.gpkg") |> st_transform(CRS_GR)
kc  <- st_centroid(st_geometry(kon))
inside <- lengths(st_intersects(kc, reg)) > 0
kon <- kon[inside, ]; kc <- kc[inside]
pop_total <- sum(kon$population)
area_km2  <- as.numeric(st_area(reg)) / 1e6
# finding: the smallest share of land that holds half of the people (densest 400 m cells first)
cell_km2 <- mean(as.numeric(st_area(kon))) / 1e6
o <- sort(kon$population, decreasing = TRUE)
n_half <- which(cumsum(o) >= pop_total / 2)[1]
half_share <- n_half * cell_km2 / area_km2
message(sprintf("Population %s on %.0f km²; half of it lives in %d cells = %.0f km² = %.1f %% of the land",
                format(pop_total, big.mark = ","), area_km2, n_half, n_half * cell_km2, 100 * half_share))

# population per municipality (cell centroids)
mi <- st_intersects(kc, muni) |> map_int(\(i) if (length(i)) i[1] else NA_integer_)
muni$pop <- tapply(kon$population, factor(mi, seq_len(nrow(muni))), sum) |> as.numeric() |> replace_na(0)
muni$km2 <- as.numeric(st_area(muni)) / 1e6

# hexagons at H3 res 6 for the map
hex <- kon |> st_drop_geometry() |> mutate(h6 = get_parent(h3, res = 6, simple = TRUE)) |>
  group_by(h6) |> summarise(pop = sum(population), .groups = "drop")
hex_sf <- cell_to_polygon(hex$h6, simple = FALSE) |> st_as_sf() |> rename(h6 = h3_address)
hex_sf <- left_join(hex_sf, hex, by = "h6") |> st_transform(4326)
hex_sf$km2 <- as.numeric(st_area(st_transform(hex_sf, CRS_GR))) / 1e6
hex_sf$dens <- hex_sf$pop / hex_sf$km2
message(sprintf("%d populated H3-6 hexagons", nrow(hex_sf)))

# rivers
riv <- m30_osm("lines", "waterway = 'river'")
riv <- st_intersection(riv, reg) |> st_collection_extract("LINESTRING")
riv_km <- sum(as.numeric(st_length(riv))) / 1000
riv84 <- riv |> mutate(name = coalesce(name, "unnamed river")) |> select(name) |>
  st_transform(4326) |> st_simplify(dTolerance = 0.0004)
message(sprintf("%d OSM river segments, %.0f km", nrow(riv), riv_km))

# GBIF threatened species (fine coordinates only, as in t13)
gb <- read.csv("data/gbif_thessaly_threatened.csv") |>
  filter(is.na(coordinateUncertaintyInMeters) | coordinateUncertaintyInMeters <= 10000,
         is.na(datasetName) | !grepl("Atlas", datasetName)) |>
  mutate(cat = factor(iucnRedListCategory, c("CR", "EN", "VU")))
message(sprintf("%d GBIF records, %d species", nrow(gb), n_distinct(gb$species)))

tw84 <- st_transform(m30_towns, 4326)
muni84 <- st_transform(muni, 4326) |> st_simplify(dTolerance = 0.0005)

# ---- 2. leaflet ----
ink <- M30$ink; acc <- "#2F5D8A"
pal_pop <- colorBin(c("#F1EEF6", "#C9C4E0", "#9C93C7", "#6B5BA8", "#3F2A80"),
                    domain = hex_sf$dens, bins = c(0, 10, 25, 50, 200, Inf), na.color = "transparent")
pal_cat <- colorFactor(c("#B3241F", "#E07B39", "#D9BD6A"), levels = c("CR", "EN", "VU"))
fmt <- function(x) format(round(x), big.mark = ",", trim = TRUE)
font <- "font-family:'Fira Sans',Helvetica,Arial,sans-serif;"

m <- leaflet(options = leafletOptions(zoomSnap = 0.25, zoomDelta = 0.5)) |>
  addProviderTiles(providers$Esri.WorldGrayCanvas, group = "Base",
                   options = providerTileOptions(opacity = 0.8)) |>
  addProviderTiles(providers$Esri.WorldShadedRelief, group = "Relief (Esri)",
                   options = providerTileOptions(opacity = 0.45)) |>
  addPolygons(data = hex_sf, group = "People (Kontur 2023)", fillColor = ~pal_pop(dens), fillOpacity = 0.75,
              color = "white", weight = 0.4,
              popup = ~sprintf("<div style=\"%s\"><b>%s people</b><br>%.0f per km² · hexagon of %.0f km²</div>",
                               font, fmt(pop), dens, km2),
              highlightOptions = highlightOptions(weight = 1.5, color = ink, bringToFront = TRUE)) |>
  addPolygons(data = muni84, group = "Municipalities", fill = TRUE, fillOpacity = 0, color = "#555555",
              weight = 0.8, dashArray = "3 3",
              popup = ~sprintf("<div style=\"%s\"><b>%s</b> (%s)<br>%s people · %s km²<br>%.0f people per km²</div>",
                               font, municipality, unit, fmt(pop), fmt(km2), pop / km2)) |>
  addPolylines(data = riv84, group = "Rivers (OSM)", color = acc, weight = 1.4, opacity = 0.85,
               popup = ~sprintf("<div style=\"%s\">%s</div>", font, name),
               highlightOptions = highlightOptions(weight = 4, color = "#0B3A66")) |>
  addCircleMarkers(data = gb, lng = ~decimalLongitude, lat = ~decimalLatitude, group = "Threatened species (GBIF)",
                   radius = 3.2, stroke = TRUE, color = "white", weight = 0.6, fillColor = ~pal_cat(cat),
                   fillOpacity = 0.95,
                   popup = ~sprintf("<div style=\"%s\"><i>%s</i><br>IUCN <b>%s</b> · %s · %s<br><span style='color:#888'>%s</span></div>",
                                    font, species, cat, class, year, datasetName)) |>
  addCircleMarkers(data = tw84, group = "Towns", radius = 5, color = ink, weight = 1.5, fillColor = "white",
                   fillOpacity = 1, popup = ~sprintf("<div style=\"%s\"><b>%s</b> · %s</div>", font, name, name_gr),
                   label = ~name, labelOptions = labelOptions(noHide = TRUE, direction = "right", textOnly = TRUE,
                     style = list("font-family" = "'Fira Sans Condensed',sans-serif", "font-size" = "13px",
                                  "font-weight" = "600", "color" = ink,
                                  "text-shadow" = "0 0 3px #fff,0 0 3px #fff,0 0 3px #fff"))) |>
  addLegend("bottomright", colors = c("#F1EEF6", "#C9C4E0", "#9C93C7", "#6B5BA8", "#3F2A80"),
            labels = c("< 10", "10–25", "25–50", "50–200", "> 200"), title = "People per km²",
            opacity = 0.9, group = "People (Kontur 2023)") |>
  addLegend("bottomleft", pal = pal_cat, values = c("CR", "EN", "VU"), opacity = 1,
            title = "IUCN category", group = "Threatened species (GBIF)") |>
  addLayersControl(overlayGroups = c("People (Kontur 2023)", "Municipalities", "Rivers (OSM)",
                                     "Threatened species (GBIF)", "Towns", "Relief (Esri)"),
                   options = layersControlOptions(collapsed = FALSE)) |>
  hideGroup("Relief (Esri)") |>
  addScaleBar("bottomleft", options = scaleBarOptions(imperial = FALSE)) |>
  fitBounds(21.15, 38.98, 23.95, 40.12)

# quiet legend styling in the page (Fira Sans if installed, else Helvetica)
m <- m |> htmlwidgets::prependContent(htmltools::tags$head(
  htmltools::tags$style(htmltools::HTML(
    ".leaflet-container{background:#fff;font-family:'Fira Sans',Helvetica,sans-serif}
     .leaflet-control-layers,.info.legend{font-family:'Fira Sans',sans-serif;font-size:12px;color:#1E1E1E;
       border-radius:2px;box-shadow:none;border:1px solid #D9D9D9}
     .info.legend{background:rgba(255,255,255,.92)}"))))
m$sizingPolicy$defaultWidth <- "100%"; m$sizingPolicy$defaultHeight <- "100vh"

html <- file.path(normalizePath(M30_OUT), "day13_interactions.html")
saveWidget(m, html, selfcontained = TRUE, title = "Thessaly · five layers · #30DayMapChallenge Day 13")
unlink(file.path(M30_OUT, "day13_interactions_files"), recursive = TRUE)
message("saved ", html)

# ---- 3. screenshot (headless Chrome via webshot2) ----
shot <- file.path(M30_CACHE, "day13", "screenshot.png")
dir.create(dirname(shot), showWarnings = FALSE, recursive = TRUE)
webshot2::webshot(paste0("file://", html), shot, vwidth = 1100, vheight = 860, zoom = 2, delay = 6)

# ---- 4. frame it in the series look ----
img <- magick::image_read(shot)
ii  <- magick::image_info(img)
ras <- as.raster(img)
p <- ggplot() +
  annotation_raster(ras, xmin = 0, xmax = ii$width, ymin = 0, ymax = ii$height) +
  annotate("rect", xmin = 0, xmax = ii$width, ymin = 0, ymax = ii$height, fill = NA, colour = M30$line,
           linewidth = 0.3) +
  coord_fixed(xlim = c(0, ii$width), ylim = c(0, ii$height), expand = FALSE) +
  m30_labs(13, "Interactions",
           title = sprintf("Half of Thessaly's people live<br>on %.1f %% of its land", 100 * half_share),
           subtitle = sprintf(paste0(
             "Five layers to switch on and off: %s people in hexagons (darker = denser), %d municipalities, ",
             "%s km of rivers, %s records of %d threatened species, %d towns. Click any shape for its numbers ",
             "in the live map (day13_interactions.html)."),
             fmt(pop_total), nrow(muni), fmt(riv_km), fmt(nrow(gb)), n_distinct(gb$species), nrow(m30_towns)),
           source = paste("Kontur Population 2023 (CC BY) · © OpenStreetMap contributors (Geofabrik 2026-10-28) ·",
                          "GBIF.org occurrences 2026-10-10 (IUCN CR/EN/VU) · GADM 4.1 · tiles © Esri"),
           accent = acc,
           extra = "Half the people = densest 400 m cells adding up to 50 %. GBIF shows where people looked, not only where species live. Built with leaflet + htmlwidgets, screenshot with headless Chrome") +
  theme_m30() + theme(plot.title = element_markdown(margin = margin(26, 0, 14, 0)))
m30_save(p, 13, "interactions", w = 8, h = 8.6)
