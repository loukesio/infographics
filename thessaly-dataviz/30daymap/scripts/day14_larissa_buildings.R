# day14 — A Borgesian map: Larissa, footprint by footprint
# "On Exactitude in Science" (Borges, 1946): the map so exact it becomes the size of the empire, and is left in tatters.
# Every building footprint in OpenStreetMap within a 8 × 7 km frame around the centre of Larissa, in black ink.
# Where OSM says people live (landuse = residential) but no building has been drawn, 100 m squares are shaded:
# the parts of the map still "in tatters".
#
# Data
#   * OpenStreetMap, Geofabrik Greece extract 2026-10-28 (ODbL, © OpenStreetMap contributors): multipolygons with
#     building = *, and landuse = residential. Cached in 30daymap/cache/thessaly_osm.gpkg.
#   * Quote: Jorge Luis Borges, "Del rigor en la ciencia" (1946), English tr. Andrew Hurley, Collected Fictions (1998).
#
# Caveats
#   * A blank in OSM is not an empty lot: it is a block nobody has traced yet. Counts are of mapped footprints only.
#   * "Tatters" = 100 m cells whose centre lies in residential land use and that touch no building polygon.
source("30daymap/R/m30_base.R")
# gridtext cannot read a family name with spaces inside a <span style>, so register a one-word alias
systemfonts::register_variant("CormorantQ", "Cormorant Garamond", weight = "normal")
INK <- "#1A1A1A"; TATTER <- "#E9DFCC"; ACC <- "#8C6A3F"

# ---- 1. data ----
ctr <- m30_towns |> filter(name == "Larissa"); cx <- st_coordinates(ctr)
W <- 8000; H <- 7000
fr <- st_as_sfc(st_bbox(c(xmin = cx[1] - W / 2, xmax = cx[1] + W / 2, ymin = cx[2] - H / 2 - 300,
                          ymax = cx[2] + H / 2 - 300), crs = st_crs(CRS_GR)))
b <- m30_osm("multipolygons", "building IS NOT NULL", clip = fr)
res <- m30_osm("multipolygons", "landuse = 'residential'", clip = fr) |> st_make_valid()
streets <- m30_osm("lines", paste0("highway IN ('primary','secondary','tertiary','residential','unclassified',",
                                   "'living_street','pedestrian','trunk','motorway')"), clip = fr)
river <- m30_osm("lines", "waterway = 'river'", clip = fr)

n_b <- nrow(b); fp_km2 <- sum(as.numeric(st_area(b))) / 1e6
frame_km2 <- W * H / 1e6
message(sprintf("%s buildings mapped in the %.0f km² frame, footprint %.2f km² (%.1f%% of the frame)",
                format(n_b, big.mark = ","), frame_km2, fp_km2, 100 * fp_km2 / frame_km2))
message("Most common building tags: ", paste(names(sort(table(b$building), decreasing = TRUE))[1:5], collapse = ", "))

# ---- 2. tatters: residential 100 m cells without any building ----
cells <- st_make_grid(fr, cellsize = 100) |> st_sf(geometry = _)
cen <- suppressWarnings(st_centroid(cells))
cells <- cells[lengths(st_intersects(cen, st_union(res))) > 0, ]
cells$has_b <- lengths(st_intersects(cells, b)) > 0
tat <- filter(cells, !has_b)
share_tat <- nrow(tat) / nrow(cells)
message(sprintf("Residential 100 m cells: %d; with no mapped building: %d (%.1f%%)", nrow(cells), nrow(tat),
                100 * share_tat))

# ---- 3. poster ----
fb <- st_bbox(fr)
quote <- paste0("“…a Map of the Empire whose size was that of the Empire, and which coincided point for point with it.”")
p <- ggplot() +
  geom_sf(data = tat, fill = TATTER, colour = NA) +
  geom_sf(data = river, colour = "#B9C9D3", linewidth = 0.9) +
  geom_sf(data = streets, colour = "#DADADA", linewidth = 0.15) +
  geom_sf(data = b, fill = INK, colour = NA) +
  geom_sf(data = fr, fill = NA, colour = INK, linewidth = 0.3) +
  coord_sf(datum = NA, expand = FALSE, xlim = fb[c(1, 3)], ylim = fb[c(2, 4)]) +
  theme_m30() +
  m30_labs(14, "A Borgesian map",
    title = if (share_tat > 0.45 && share_tat < 0.55) "The map of Larissa is still half in tatters" else
      sprintf("%.0f%% of Larissa's map is still in tatters", 100 * share_tat),
    subtitle = sprintf(paste0(
      "<span style='font-family:CormorantQ;font-size:18pt;color:#1A1A1A'>%s</span><br>",
      "<span style='font-size:10pt'>Jorge Luis Borges, On Exactitude in Science (1946)</span><br><br>",
      "All %s building footprints OpenStreetMap volunteers have traced in an %d × %d km frame around the centre, ",
      "%.1f km² of roofs. The old town by the Pineios is drawn house by house; in <b style='color:%s'>%.0f%% of the ",
      "residential blocks</b> (100 m squares, shaded) not a single building has been drawn yet."),
      quote, format(n_b, big.mark = ","), W / 1000, H / 1000, fp_km2, ACC, 100 * share_tat),
    source = "© OpenStreetMap contributors, Geofabrik extract 2026-10-28 (ODbL): building = *, landuse = residential, streets and river for orientation",
    accent = ACC,
    extra = "Borges quote tr. Andrew Hurley (Collected Fictions, 1998)") +
  theme(plot.title = element_markdown(family = "Cormorant Garamond", face = "bold", size = 33))
m30_save(p, 14, "larissa_buildings", 8, 10)
