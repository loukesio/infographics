# day02 — Lines: the Pineios river system
# Every river reach of HydroRIVERS inside mainland Thessaly. Reaches that end in the Pineios are blue, line width =
# long-term average discharge; reaches that drain elsewhere (Lake Karla, Pagasetic Gulf, Aliakmonas, Acheloos, Spercheios)
# are grey. The main stem is traced from the mouth upstream, always following the reach with the largest upstream area.
#
# Data
#   * HydroRIVERS v1.0 Europe (HydroSHEDS, Lehner & Grill 2013; Linke et al. 2019), CC BY 4.0
#     https://www.hydrosheds.org/products/hydrorivers
#     file https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_eu_shp.zip
#     fields: MAIN_RIV (id of the most downstream reach = basin), DIS_AV_CMS (average discharge, modelled),
#     UPLAND_SKM, CATCH_SKM (area draining into each reach), LENGTH_KM
#   * River names for the labels: OpenStreetMap (Geofabrik Greece extract 2026-10-28, ODbL), waterway = river
#   * Region border: Eurostat GISCO NUTS 2021 (via m30_base.R)
#
# Caveats
#   * HydroRIVERS keeps only reaches with >= 10 km² upstream area or >= 0.1 m³/s; small streams and the irrigation
#     canals and ditches of the plain are not in it. Discharge is modelled (WaterGAP), natural flow, no withdrawals.
#   * Basin area inside Thessaly = sum of the reach catchments (CATCH_SKM) whose reach midpoint lies inside the border.
#     Land with no reach (small coastal slopes) is counted as "other".
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(geomtextpath); library(shadowtext) })

DIR <- file.path(M30_CACHE, "osm_days", "hydrorivers"); dir.create(DIR, showWarnings = FALSE, recursive = TRUE)
ACC <- "#1F5F8B"

# ---- 1. data ----
zip <- file.path(DIR, "HydroRIVERS_v10_eu_shp.zip")
if (!file.exists(zip)) download.file("https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_eu_shp.zip",
                                     zip, mode = "wb")
shp <- file.path(DIR, "HydroRIVERS_v10_eu_shp", "HydroRIVERS_v10_eu.shp")
if (!file.exists(shp)) unzip(zip, exdir = DIR)
riv <- read_sf(shp, wkt_filter = "POLYGON((20.8 38.8, 24.4 38.8, 24.4 40.4, 20.8 40.4, 20.8 38.8))") |>
  st_transform(CRS_GR)

reg <- m30_region(TRUE)
gr  <- m30_greece()
mid <- suppressWarnings(st_point_on_surface(riv))
riv$inside <- lengths(st_intersects(mid, reg)) > 0

# Pineios = the basin with the most reaches inside Thessaly; check its mouth is the Aegean outlet near Tempi
pin_id <- riv |> st_drop_geometry() |> filter(inside) |> count(MAIN_RIV, sort = TRUE) |> slice(1) |> pull(MAIN_RIV)
riv <- riv |> mutate(pineios = MAIN_RIV == pin_id)
mouth <- riv |> filter(HYRIV_ID == pin_id)
message(sprintf("Pineios basin id %d: upstream area at the mouth %.0f km², mean discharge %.1f m³/s",
                pin_id, mouth$UPLAND_SKM, mouth$DIS_AV_CMS))

# main stem: walk upstream from the mouth along the largest upstream area
up <- split(st_drop_geometry(riv)[, c("HYRIV_ID", "UPLAND_SKM")], riv$NEXT_DOWN)
stem <- pin_id; cur <- pin_id
repeat {
  u <- up[[as.character(cur)]]; if (is.null(u)) break
  cur <- u$HYRIV_ID[which.max(u$UPLAND_SKM)]; stem <- c(stem, cur)
}
riv <- riv |> mutate(stem = HYRIV_ID %in% stem)

# ---- 2. numbers ----
area_reg <- as.numeric(st_area(reg)) / 1e6
basins <- riv |> st_drop_geometry() |> filter(inside) |> group_by(MAIN_RIV) |>
  summarise(km2 = sum(CATCH_SKM), km = sum(LENGTH_KM), .groups = "drop") |> arrange(desc(km2))
pin <- basins |> filter(MAIN_RIV == pin_id)
share <- pin$km2 / area_reg
len_pin_all <- sum(riv$LENGTH_KM[riv$pineios])
len_stem <- sum(riv$LENGTH_KM[riv$stem])
message(sprintf("Mainland Thessaly %.0f km²; Pineios basin inside it %.0f km² = %.1f%%", area_reg, pin$km2, 100 * share))
message(sprintf("Pineios system: %d reaches, %.0f km of river in total; main stem %.0f km", sum(riv$pineios),
                len_pin_all, len_stem))
message(sprintf("Other basins inside Thessaly: %d; reaches inside Thessaly %.0f km", nrow(basins) - 1,
                sum(basins$km)))

# ---- 3. names from OSM, matched to the HydroRIVERS reaches ----
name_tab <- tribble(~gr, ~en, "Πηνειός", "Pineios", "Ενιπέας", "Enipeas", "Τιταρήσιος", "Titarisios",
                    "Ληθαίος", "Lithaios")
osm_r <- m30_osm("lines", "waterway = 'river' AND name IN ('Πηνειός','Ενιπέας','Τιταρήσιος','Ληθαίος')", clip = NULL)
pin_r <- riv |> filter(pineios)
lab_lines <- map_dfr(seq_len(nrow(name_tab)), \(i) {
  o <- osm_r |> filter(name == name_tab$gr[i]) |> st_union() |> st_buffer(1500)
  s <- pin_r[lengths(st_intersects(pin_r, o)) > 0, ]
  if (name_tab$en[i] != "Pineios") s <- s |> filter(!stem)
  s <- s |> filter(ORD_STRA >= 2)
  message(sprintf("  %s: %d HydroRIVERS reaches matched to OSM", name_tab$en[i], nrow(s)))
  ln <- st_line_merge(st_cast(st_union(s), "MULTILINESTRING")) |> st_cast("LINESTRING")
  ln <- ln[which.max(st_length(ln))] |> st_simplify(dTolerance = 2500)
  st_sf(name = name_tab$en[i], geometry = ln)
})

# label anchor: a point at fraction f along the line, text angle along the local direction (kept upright)
lab_at <- function(ln, f, name) {
  pts <- st_coordinates(st_line_sample(ln, sample = pmin(pmax(c(f - 0.04, f, f + 0.04), 0), 1)))
  a <- atan2(pts[3, 2] - pts[1, 2], pts[3, 1] - pts[1, 1]) * 180 / pi
  if (a > 90) a <- a - 180
  if (a < -90) a <- a + 180
  tibble(name = name, x = pts[2, 1], y = pts[2, 2], angle = a)
}
lab_pos <- tribble(~name, ~f, ~dx, ~dy,
                   "Pineios", 0.30, 2600, 3600, "Enipeas", 0.55, 2600, 2200, "Titarisios", 0.45, 2400, 2200,
                   "Lithaios", 0.30, 2800, -1500)
labs_r <- pmap_dfr(lab_pos, \(name, f, dx, dy) {
  lab_at(lab_lines$geometry[lab_lines$name == name], f, name) |> mutate(x = x + dx, y = y + dy)
})

karla <- m30_osm("multipolygons", "natural = 'water' AND name LIKE '%Κάρλα%'", clip = reg)
message(sprintf("Lake Karla polygons from OSM: %d", nrow(karla)))

# ---- 4. map + share bar drawn below the region, in map units ----
bb <- st_bbox(st_buffer(reg, 6000))
W <- bb["xmax"] - bb["xmin"]
y0 <- bb["ymin"] - 16000                                     # bar top
bars <- basins |> mutate(group = ifelse(MAIN_RIV == pin_id, "Pineios", "Other")) |>
  group_by(group) |> summarise(km2 = sum(km2), .groups = "drop") |>
  bind_rows(tibble(group = "None", km2 = area_reg - sum(basins$km2))) |>
  mutate(share = km2 / area_reg, group = factor(group, c("Pineios", "Other", "None"))) |>
  arrange(group) |>
  mutate(x1 = bb["xmin"] + W * cumsum(share), x0 = bb["xmin"] + W * lag(cumsum(share), default = 0),
         lab = c(Pineios = "of the land drains to the Pineios", Other = "to Lake Karla, the gulf & other rivers",
                 None = "")[as.character(group)])
message(sprintf("Shares: %s", paste(sprintf("%s %.1f%%", bars$group, 100 * bars$share), collapse = "; ")))
ylim <- c(y0 - 15000, bb["ymax"])

ctx <- st_crop(gr, c(bb["xmin"], ymin = ylim[[1]], bb["xmax"], bb["ymax"]))
ctx <- st_crop(gr, bb)
riv_in <- suppressWarnings(st_intersection(riv, reg))
towns <- m30_towns |> filter(name %in% c("Larissa", "Trikala", "Karditsa", "Volos"))
tx <- st_coordinates(towns); towns <- towns |> mutate(x = tx[, 1], y = tx[, 2])
STEM <- "#0E3F63"

m <- ggplot() +
  annotate("rect", xmin = bb["xmin"], xmax = bb["xmax"], ymin = bb["ymin"], ymax = bb["ymax"], fill = "#EEF3F6") +
  geom_sf(data = ctx, fill = "#F4F4F2", colour = NA) +
  geom_sf(data = reg, fill = "white", colour = "#CFCFCF", linewidth = 0.3) +
  geom_sf(data = karla, fill = "#DCE3E8", colour = NA) +
  geom_sf(data = filter(riv_in, !pineios), aes(linewidth = DIS_AV_CMS), colour = "#BCC1C6", lineend = "round") +
  geom_sf(data = filter(riv_in, pineios, !stem), aes(linewidth = DIS_AV_CMS, alpha = DIS_AV_CMS),
          colour = ACC, lineend = "round") +
  geom_sf(data = filter(riv_in, stem), aes(linewidth = DIS_AV_CMS), colour = STEM, lineend = "round") +
  geom_point(data = towns, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.6, stroke = 0.45) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", size = 3,
                  colour = M30$soft, bg.colour = "white", bg.r = 0.18, hjust = 0, nudge_x = 2200, nudge_y = -2600) +
  geom_shadowtext(data = labs_r, aes(x, y, label = name, angle = angle), family = "Fira Sans Condensed",
                  fontface = ifelse(labs_r$name == "Pineios", "bold", "plain"),
                  size = ifelse(labs_r$name == "Pineios", 4.6, 3.5), colour = STEM,
                  bg.colour = "white", bg.r = 0.15) +
  annotate("text", x = st_coordinates(st_centroid(st_union(karla)))[1] + 3500,
           y = st_coordinates(st_centroid(st_union(karla)))[2], label = "Lake\nKarla", hjust = 0,
           family = "Fira Sans Condensed", size = 2.9, colour = "#8E949B", lineheight = 0.9) +
  # share bar
  geom_rect(data = bars, aes(xmin = x0, xmax = x1, ymin = y0 - 7000, ymax = y0), fill =
              c(Pineios = ACC, Other = "#C9CDD2", None = "#ECECEA")[as.character(bars$group)],
            colour = "white", linewidth = 0.6) +
  geom_text(data = filter(bars, group != "None"), aes(x = x0 + 1500, y = y0 - 3500,
            label = sprintf("%.0f%%", 100 * share)), hjust = 0, family = "Oswald", fontface = "bold", size = 4.6,
            colour = ifelse(filter(bars, group != "None")$group == "Pineios", "white", M30$ink)) +
  geom_text(data = filter(bars, group != "None"), aes(x = x0, y = y0 - 9500, label = lab), hjust = 0, vjust = 1,
            family = "Fira Sans Condensed", size = 3.1, colour = M30$soft) +
  annotate("text", x = bb["xmin"], y = y0 + 2200, label = "WHERE THE RAIN OF MAINLAND THESSALY ENDS UP",
           hjust = 0, vjust = 0, family = "Fira Sans Condensed", size = 2.9, colour = M30$soft) +
  scale_linewidth_continuous(range = c(0.12, 2.6), trans = "sqrt", guide = "none") +
  scale_alpha_continuous(range = c(0.45, 1), trans = "log10", guide = "none") +
  m30_scalebar(20, x = bb["xmax"] - 26000, y = bb["ymin"] + 6000, bbox = bb) +
  coord_sf(xlim = bb[c(1, 3)], ylim = ylim, expand = FALSE, datum = NA, crs = CRS_GR, default_crs = CRS_GR) +
  theme_m30() + theme(plot.title = element_markdown(size = 28))

# ---- 5. titles ----
title <- if (share > 0.585 && share < 0.65) "Three fifths of Thessaly drains into one river" else
  sprintf("%.0f%% of Thessaly drains into one river", 100 * share)
p <- m + m30_labs(2, "Lines", title,
           subtitle = sprintf(paste0(
             "Every river in mainland Thessaly, line width by its average flow. The <b style='color:%s'>Pineios</b> ",
             "and its tributaries gather the rain of %s km², %s km of river in all, and leave the plain through ",
             "the Tempi gorge to the Aegean. <span style='color:#8E949B'><b>Grey</b></span> rivers end in Lake Karla, ",
             "the Pagasetic Gulf or beyond the border."),
             STEM, format(round(pin$km2, -2), big.mark = ","), format(round(len_pin_all, -1), big.mark = ",")),
           source = "HydroRIVERS v1.0 Europe (HydroSHEDS; Lehner &amp; Grill 2013), modelled mean discharge · river and lake names © OpenStreetMap contributors (Geofabrik 2026-10-28) · border Eurostat NUTS 2021",
           accent = ACC,
           extra = "Streams with &lt; 10 km² upstream area and irrigation canals are not in HydroRIVERS")
m30_save(p, 2, "pineios_rivers", 8, 10)
