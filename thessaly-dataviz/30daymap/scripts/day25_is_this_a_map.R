# Day 25 · Is this a map? — Thessaly's land cover as a Voronoi treemap in the shape of Thessaly
# A chart that is also a map: the outline and the four regional units are real, but inside each unit the land is
# re-cut into one cell per land-cover class, and each cell's area is that class's real area in the unit
# (ESA WorldCover 2021, 10 m pixels counted per unit). Built with Loukas's own package ggvmap (vmap_region()).
#
# Data
#   * ESA WorldCover 10 m 2021 v200, tiles N39E021 + N36E021, © ESA WorldCover project 2022 / Contains modified
#     Copernicus Sentinel data (2021) processed by ESA WorldCover consortium, CC BY 4.0.
#     https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_N39E021_Map.tif
#     Cached in 30daymap/cache/worldcover/; pixel counts per unit kept in 30daymap/data/day25_worldcover_units.csv
#   * Regional units: dissolved from GADM 4.1 municipalities (m30_units(), mainland, Sporades excluded)
#
# Caveats
#   * Pixel counts in EPSG:4326 (pixel area varies < 2 % across Thessaly's latitudes; shares only).
#   * WorldCover "tree cover" = any canopy ≥ 10 %: it includes oak scrub, olive groves and orchards.
#   * Wetland (class 90, 0.03 %) is merged into Water. Cell positions inside a unit are arbitrary (Voronoi
#     iterations), only cell areas carry data.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(ggvmap); library(shadowtext); library(patchwork) })

# ---- 1. data: WorldCover pixel counts per regional unit ----------------------------------------------
wdir <- file.path(M30_CACHE, "worldcover"); dir.create(wdir, showWarnings = FALSE)
tiles <- c("N39E021", "N36E021")
tf <- file.path(wdir, sprintf("ESA_WorldCover_10m_2021_v200_%s_Map.tif", tiles))
walk2(tiles, tf, \(t, f) if (!file.exists(f)) download.file(sprintf(
  "https://esa-worldcover.s3.eu-central-1.amazonaws.com/v200/2021/map/ESA_WorldCover_10m_2021_v200_%s_Map.tif", t),
  f, mode = "wb", quiet = TRUE))
units <- m30_units()
cf <- "30daymap/data/day25_worldcover_units.csv"
if (!file.exists(cf)) {                       # ~5 min: crosstab of 10 m classes x regional units
  u4 <- st_transform(units, 4326)
  w  <- crop(vrt(tf), ext(vect(u4)) + 0.01)
  ct <- crosstab(c(w, rasterize(vect(u4), w, field = "name")), long = TRUE)
  names(ct) <- c("code", "unit", "pixels"); write.csv(ct, cf, row.names = FALSE)
}
cls <- c(`10` = "Tree cover", `20` = "Shrubland", `30` = "Grassland", `40` = "Cropland", `50` = "Built-up",
         `60` = "Bare ground", `80` = "Water", `90` = "Water")
d <- read.csv(cf) |> mutate(class = cls[as.character(code)]) |>
  group_by(unit, class) |> summarise(pixels = sum(pixels), .groups = "drop") |>
  mutate(share_th = pixels / sum(pixels)) |>
  group_by(unit) |> mutate(share_unit = pixels / sum(pixels)) |> ungroup()
tot <- d |> group_by(class) |> summarise(share = sum(share_th), .groups = "drop") |> arrange(-share)
message("Thessaly (mainland) land cover, WorldCover 2021: ",
        paste(sprintf("%s %.1f%%", tot$class, 100 * tot$share), collapse = "; "))
message("Cropland share by unit: ", d |> filter(class == "Cropland") |>
          with(paste(sprintf("%s %.0f%%", unit, 100 * share_unit), collapse = "; ")))

# ---- 2. Voronoi treemap inside each regional unit (ggvmap::vmap_region) -------------------------------
ord <- c("Cropland", "Tree cover", "Grassland", "Shrubland", "Built-up", "Water", "Bare ground")
units_s <- units |> st_simplify(dTolerance = 150) |> st_make_valid()   # the fitted outlines, also drawn
fits <- map(units$name, \(nm) {
  dd <- d |> filter(unit == nm) |> mutate(class = factor(class, ord)) |> arrange(class)
  poly <- units_s |> filter(name == nm)
  vm <- vmap_region(dd$pixels, poly, labels = as.character(dd$class), seed = 25, max_iter = 2000)
  message(sprintf("%s: %d iterations, convergence %.2f%%, converged %s", nm, vm$iterations,
                  100 * vm$convergence, vm$converged))
  list(df = vm_as_df(vm) |> mutate(unit = nm),
       cen = vm_centroids(vm, inside = TRUE) |> mutate(unit = nm))
})
cells <- map_dfr(fits, "df") |> left_join(d |> select(unit, label = class, share_unit, share_th),
                                          by = c("unit", "label"))
# label point = the point deepest inside each cell (pole of inaccessibility on a 1 km grid)
cell_sf <- cells |> group_by(unit, cell, label, share_unit, share_th) |>
  summarise(geometry = list(st_polygon(map(split(seq_along(x), ring), \(i) rbind(cbind(x[i], y[i]), c(x[i[1]], y[i[1]]))))), .groups = "drop") |>
  mutate(geometry = st_sfc(geometry, crs = CRS_GR)) |> st_as_sf() |> st_make_valid()
cen <- cell_sf |> mutate(pt = map(geometry, \(g) {
  g <- st_sfc(g, crs = CRS_GR)
  gp <- st_make_grid(g, cellsize = 1000, what = "centers"); gp <- gp[st_intersects(gp, g, sparse = FALSE)[, 1]]
  if (!length(gp)) return(st_coordinates(st_point_on_surface(g))[1, 1:2])
  st_coordinates(gp[which.max(st_distance(gp, st_boundary(g)))])[1, 1:2]
})) |> st_drop_geometry() |> mutate(cx = map_dbl(pt, 1), cy = map_dbl(pt, 2))

# ---- 3. plot ----------------------------------------------------------------------------------------
pal <- c("Cropland" = "#E2B659", "Tree cover" = "#2E5E4E", "Grassland" = "#A7BF8A", "Shrubland" = "#6F7F45",
         "Built-up" = "#C2410C", "Water" = "#4A8BBE", "Bare ground" = "#C9C1B3")
dark <- c("Tree cover", "Shrubland", "Built-up", "Water")
acc <- "#C2410C"
reg <- m30_region()
ul <- cen |> filter(share_unit >= .045) |>
  mutate(lab = ifelse(share_unit >= .12, paste0(label, "\n", round(100 * share_unit), "%"), paste0(round(100 * share_unit), "%")),
         col = ifelse(label %in% dark, "white", M30$ink), sz = ifelse(share_unit >= .12, 3.3, 2.9))
# unit names sit just outside the outline, at a corner of each unit's bounding box (checked on the render)
ubb <- map_dfr(units_s$name, \(nm) as.list(st_bbox(filter(units_s, name == nm))) |> as_tibble() |> mutate(name = nm))
uname <- ubb |> mutate(
  x = case_when(name == "Trikala" ~ xmin, name == "Larissa" ~ (xmin + xmax) / 2, name == "Karditsa" ~ xmin, TRUE ~ xmax),
  y = case_when(name == "Trikala" ~ ymax + 4000, name == "Larissa" ~ ymax + 4000, name == "Karditsa" ~ ymin + 3000, TRUE ~ ymin),
  hj = c(Trikala = 0, Larissa = .5, Karditsa = 1, Magnesia = 1)[name])

map <- ggplot() +
  geom_polygon(data = cells, aes(x, y, group = interaction(unit, cell), subgroup = ring, fill = label),
               rule = "evenodd", colour = "white", linewidth = .45) +
  geom_sf(data = units_s, fill = NA, colour = "white", linewidth = 2.2) +
  geom_sf(data = st_union(units_s), fill = NA, colour = M30$ink, linewidth = .35) +
  geom_text(data = ul, aes(cx, cy, label = lab, colour = I(col), size = I(sz)), family = "Fira Sans Condensed",
            lineheight = .9, fontface = "bold") +
  geom_text(data = uname, aes(x, y, label = toupper(name), hjust = hj), family = "Fira Sans Condensed",
            fontface = "bold", size = 3.6, colour = M30$soft, vjust = 0) +
  scale_fill_manual(values = pal, guide = "none") +
  coord_sf(crs = CRS_GR, clip = "off") +
  theme_m30() + theme(plot.margin = margin(22, 30, 0, 30),
                      plot.title = element_markdown(margin = margin(26, 0, 16, 0)))

bars <- tot |> mutate(class = factor(class, rev(tot$class)),
                      lab = ifelse(share >= .01, sprintf("%.0f%%", 100 * share), sprintf("%.1f%%", 100 * share))) |>
  ggplot(aes(share, class, fill = class)) +
  geom_col(width = .62, show.legend = FALSE) +
  geom_text(aes(label = lab), hjust = -.15, family = "Oswald", size = 3.8, colour = M30$ink) +
  scale_fill_manual(values = pal) +
  scale_x_continuous(expand = expansion(mult = c(0, .12))) +
  labs(title = "All of Thessaly") +
  theme_m30() +
  theme(axis.text.y = element_text(family = "Fira Sans Condensed", size = 10, colour = M30$ink, hjust = 1),
        plot.title = element_markdown(family = "Oswald", face = "plain", size = 13, colour = M30$ink, margin = margin(0, 0, 4, 0)),
        plot.margin = margin(10, 30, 18, 30))

top2 <- tot$share[tot$class %in% c("Tree cover", "Cropland")]
crop_lar <- d |> filter(class == "Cropland", unit == "Larissa") |> pull(share_unit)
map <- map + m30_labs(25, "Is this a map?",
  title = sprintf("Half of Thessaly is trees, a quarter is fields"),
  subtitle = sprintf(paste0(
    "Thessaly and its four regional units, but the inside is a chart: each unit is re-cut into one cell per ",
    "land-cover class, and each cell is as big as the land that class really covers there. ",
    "<b style='color:#2E5E4E'>Tree cover</b> holds %.0f%% of the region, <b style='color:#B8892A'>cropland</b> %.0f%%, ",
    "<b style='color:#7E9A5E'>grassland</b> %.0f%%, and towns and villages (<b style='color:%s'>built-up</b>) only %.1f%%. ",
    "Labels: share of the unit."),
    100 * top2[tot$class[tot$class %in% c("Tree cover", "Cropland")] == "Tree cover"],
    100 * top2[tot$class[tot$class %in% c("Tree cover", "Cropland")] == "Cropland"],
    100 * tot$share[tot$class == "Grassland"], acc, 100 * tot$share[tot$class == "Built-up"]),
  accent = acc) + labs(caption = NULL)
bars <- bars + labs(caption = m30_labs(25, "x", "x", source = paste0(
  "ESA WorldCover 10 m 2021 v200 (CC BY 4.0), pixels counted per regional unit · Units: GADM 4.1 · ",
  "Voronoi treemap with ggvmap::vmap_region(), total cell-area error under 1%"),
  extra = "Tree cover includes oak scrub, olive groves and orchards")$caption)
p <- map / bars + plot_layout(heights = c(3.2, 1))
m30_save(p, 25, "is_this_a_map", w = 8, h = 10)
