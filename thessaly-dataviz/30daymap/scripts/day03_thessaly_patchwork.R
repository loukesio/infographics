# day03 — Polygons: Thessaly's patchwork
# Every land-use / land-cover polygon that OpenStreetMap volunteers have drawn in mainland Thessaly, grouped in six
# classes, as a mosaic. Ranked bars give each class's share of the mapped area.
#
# Data
#   * OpenStreetMap, Geofabrik Greece extract 2026-10-28 (ODbL, © OpenStreetMap contributors), layer multipolygons,
#     already in 30daymap/cache/thessaly_osm.gpkg (see m30_base.R). https://download.geofabrik.de/europe/greece.html
#   * Region border: Eurostat GISCO NUTS 2021 (EL61), mainland only.
#
# Classes (OSM tags)
#   Fields               landuse = farmland, greenhouse_horticulture
#   Orchards & vineyards landuse = orchard, vineyard, plant_nursery
#   Forest               landuse = forest, natural = wood
#   Scrub, heath & rock  natural = scrub, heath, bare_rock, scree, fell
#   Grass & meadow       landuse = meadow, grass, village_green; natural = grassland
#   Built-up             landuse = residential, industrial, commercial, retail, farmyard, quarry, construction,
#                        military, railway, landfill, cemetery, brownfield
#   Water (lakes, reservoirs) is drawn for orientation but is not a class.
#
# Caveats
#   * OSM polygons overlap (a forest relation over fields, a village over farmland). Shares are computed on a 25 m
#     grid where the more specific class wins: Built-up > Orchards > Fields > Grass > Scrub > Forest.
#   * "Mapped" means somebody drew it. Gaps are not empty land; they are land nobody has tagged yet.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext) })
DIR <- file.path(M30_CACHE, "osm_days"); dir.create(DIR, showWarnings = FALSE, recursive = TRUE)

# ---- 1. data ----
reg <- m30_region(TRUE)
classes <- tribble(
  ~class,                 ~prio, ~col,      ~sql,
  "Forest",               1, "#6F8466", "landuse = 'forest' OR \"natural\" = 'wood'",
  "Scrub, heath & rock",  2, "#B7B08A", "\"natural\" IN ('scrub','heath','bare_rock','scree','fell')",
  "Grass & meadow",       3, "#D3D6A6", "landuse IN ('meadow','grass','village_green') OR \"natural\" = 'grassland'",
  "Fields",               4, "#E7D2A2", "landuse IN ('farmland','greenhouse_horticulture')",
  "Orchards & vineyards", 5, "#B5603F", "landuse IN ('orchard','vineyard','plant_nursery')",
  "Built-up",             6, "#57514B", paste0("landuse IN ('residential','industrial','commercial','retail','farmyard',",
                                               "'quarry','construction','military','railway','landfill','cemetery','brownfield')"))
cache <- file.path(DIR, "day03_landuse.gpkg")
if (!file.exists(cache)) {
  lu <- map2_dfr(classes$class, classes$sql, \(cl, q) {
    x <- m30_osm("multipolygons", q, clip = reg) |> select(osm_id, osm_way_id, landuse, natural)
    message(sprintf("  %-22s %6d polygons", cl, nrow(x))); mutate(x, class = cl)
  })
  lu <- st_make_valid(lu)
  write_sf(lu, cache)
}
lu <- read_sf(cache) |> left_join(select(classes, class, prio), by = "class") |> arrange(prio)
water <- m30_osm("multipolygons", "\"natural\" = 'water' OR landuse = 'reservoir'", clip = reg)
water <- water[as.numeric(st_area(water)) > 2e5, ]

# ---- 2. shares on a 25 m grid, most specific class on top ----
tmpl <- rast(ext(vect(reg)), resolution = 25, crs = paste0("EPSG:", CRS_GR))
grid_f <- file.path(DIR, "day03_grid25.tif")
if (!file.exists(grid_f)) {
  layers <- map(classes$prio, \(p) {
    v <- vect(filter(lu, prio == p))
    rasterize(v, tmpl, field = p, background = 0)
  })
  g <- app(rast(layers), max)                     # highest priority wins
  g <- mask(g, vect(reg))
  writeRaster(g, grid_f, overwrite = TRUE, datatype = "INT1U")
}
g <- rast(grid_f)
tab <- freq(g) |> as_tibble() |> rename(prio = value, n = count)
cell_km2 <- prod(res(g)) / 1e6
area_reg <- as.numeric(st_area(reg)) / 1e6
shares <- classes |> select(class, prio, col) |> left_join(tab, by = "prio") |>
  mutate(km2 = n * cell_km2, share_mapped = km2 / sum(km2), share_region = km2 / area_reg) |>
  arrange(desc(km2))
mapped_km2 <- sum(shares$km2)
message(sprintf("Region %.0f km²; mapped land use %.0f km² = %.1f%% of the region", area_reg, mapped_km2,
                100 * mapped_km2 / area_reg))
walk(seq_len(nrow(shares)), \(i) message(sprintf("  %-22s %7.0f km²  %5.1f%% of mapped  %5.1f%% of region",
  shares$class[i], shares$km2[i], 100 * shares$share_mapped[i], 100 * shares$share_region[i])))
dir.create("30daymap/data", showWarnings = FALSE)
write.csv(select(shares, class, km2, share_mapped, share_region), "30daymap/data/day03_landuse_shares.csv",
          row.names = FALSE)

# ---- 3. map ----
bb <- st_bbox(st_buffer(reg, 4000))
H <- bb["ymax"] - bb["ymin"]; W <- bb["xmax"] - bb["xmin"]
ylim <- c(bb["ymin"] - 0.42 * H, bb["ymax"])
frame <- st_as_sfc(st_bbox(c(xmin = bb[["xmin"]] - 5e4, ymin = ylim[[1]] - 5e4, xmax = bb[["xmax"]] + 5e4,
                             ymax = bb[["ymax"]] + 5e4), crs = st_crs(CRS_GR)))
outside <- st_difference(frame, st_geometry(reg))           # white mask hides polygons crossing the border
pal <- setNames(classes$col, classes$class)
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa"))
tx <- st_coordinates(towns); towns <- towns |> mutate(x = tx[, 1], y = tx[, 2])

m <- ggplot() +
  geom_sf(data = reg, fill = "#F4F2ED", colour = NA) +
  geom_sf(data = lu, aes(fill = class), colour = NA) +
  geom_sf(data = water, fill = "#A9C6D3", colour = NA) +
  geom_sf(data = outside, fill = "white", colour = NA) +
  geom_sf(data = reg, fill = NA, colour = "#8A857C", linewidth = 0.3) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", fontface = "bold",
                  size = 3.3, colour = M30$ink, bg.colour = "white", bg.r = 0.16) +
  scale_fill_manual(values = pal, guide = "none") +
  annotate("text", x = bb["xmin"] + 0.70 * W, y = ylim[[1]] + 0.29 * H,
           label = sprintf("%.0f%%", 100 * (1 - mapped_km2 / area_reg)), hjust = 0, vjust = 1,
           family = "Oswald", fontface = "bold", size = 15, colour = "#C9C3B6") +
  annotate("text", x = bb["xmin"] + 0.70 * W, y = ylim[[1]] + 0.16 * H,
           label = "of mainland Thessaly has\nno land-use polygon yet.\nOSM is a map in progress.",
           hjust = 0, vjust = 1, family = "Fira Sans Condensed", size = 3.4, colour = M30$soft, lineheight = 1) +
  coord_sf(xlim = bb[c(1, 3)], ylim = ylim, expand = FALSE, datum = NA) +
  theme_m30()

# ---- 4. ranked bars of the mapped area ----
sb <- shares |> mutate(class = factor(class, rev(class)),
                       lab = sprintf("<span style='font-family:Oswald;font-size:13pt;color:#1E1E1E'>%s</span><span style='font-size:8.5pt;color:#9A9A9A'> &nbsp;·&nbsp; %s km²</span>",
                                     ifelse(share_mapped < 0.01, "<1%", sprintf("%.0f%%", 100 * share_mapped)),
                                     format(round(km2, -1), big.mark = ",")))
bars <- ggplot(sb, aes(share_mapped, class)) +
  geom_col(aes(fill = class), width = 0.68) +
  ggtext::geom_richtext(aes(label = lab), hjust = 0, nudge_x = 0.008, family = "Fira Sans Condensed",
                        fill = NA, label.colour = NA, label.padding = unit(0, "pt")) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_x_continuous(limits = c(0, max(sb$share_mapped) * 1.55), expand = c(0, 0)) +
  labs(title = "SHARE OF THE MAPPED AREA") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.y = element_text(family = "Fira Sans Condensed", size = 10.5, colour = M30$ink, hjust = 1,
                                   margin = margin(r = 6)),
        plot.title = element_text(family = "Fira Sans Condensed", size = 9, colour = M30$soft,
                                  margin = margin(b = 6)),
        plot.title.position = "plot")

# ---- 5. titles ----
top <- shares$class[1]; s1 <- shares$share_mapped[1]
frac_word <- function(s) if (s > 0.45 && s < 0.55) "Half" else if (s > 0.30 && s < 0.36) "A third" else
  if (s > 0.36 && s < 0.42) "Two fifths" else if (s > 0.55 && s < 0.62) "Three fifths" else sprintf("%.0f%%", 100 * s)
title <- sprintf("%s of mapped Thessaly is %s", frac_word(s1), tolower(top))
p <- m + inset_element(bars, left = 0.02, bottom = 0.0, right = 0.62, top = 0.27, align_to = "panel") +
  plot_annotation(theme = theme(plot.background = element_rect(fill = "white", colour = NA)))
p[[1]] <- p[[1]] + m30_labs(3, "Polygons", title,
  subtitle = sprintf(paste0(
    "Every land-use polygon that OpenStreetMap volunteers have drawn in mainland Thessaly: %s km², %.0f%% of the region. ",
    "The plain is a quilt of <b style='color:#B08B3E'>fields</b>, dotted with <b style='color:#B5603F'>orchards</b> ",
    "and villages; <b style='color:#6F8466'>forest</b> and <b style='color:#9A9370'>scrub</b> cover the mountain rim. ",
    "Pale gaps are land nobody has mapped yet."),
    format(round(mapped_km2, -2), big.mark = ","), 100 * mapped_km2 / area_reg),
  source = "© OpenStreetMap contributors, Geofabrik extract 2026-10-28 (ODbL), landuse/natural polygons; border Eurostat NUTS 2021",
  accent = "#B5603F",
  extra = "Overlaps resolved on a 25 m grid, most specific class on top")
m30_save(p, 3, "thessaly_patchwork", 8, 10)
