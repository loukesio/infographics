# Day 12 · Power — "1,644 solar parks, 22 km² of panels"
# Every solar park mapped in OpenStreetMap (amber dot, area to scale), the 400 kV and 150 kV transmission lines
# (glowing), substations, wind turbines and the big hydro plants, on a dark hillshade.
#
# Data   : OpenStreetMap, Geofabrik Greece extract 2026-10-28 (© OpenStreetMap contributors, ODbL)
#          https://download.geofabrik.de/europe/greece.html — read from 30daymap/cache/thessaly_osm.gpkg
#          power=plant / power=generator (closed ways + multipolygons; plant:source / generator:source),
#          power=line|minor_line|cable with voltage, power=substation, wind generators (points).
#          Copernicus GLO-90 DEM (hillshade) · Eurostat GISCO NUTS 2021 EL61 (mainland) · GADM 4.1 units
# Method : solar site = OSM solar plant polygon, plus solar generator polygons that do not touch any plant
#          (stand-alone rooftop/field arrays). Area = area of the union of those polygons (EGSA87).
#          Line lengths are clipped to the region border.
# Caveats: OSM is volunteer-mapped. Solar parks in Greece have been traced well from imagery, but small rooftop
#          systems are mostly missing and new parks appear with delay; 1,416 of 1,431 plants carry no capacity tag,
#          so no MW total is given. Medium-voltage (20 kV) distribution is almost unmapped. Sporades excluded.

source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext); library(ggfx) })
DIR <- file.path(M30_CACHE, "day12"); dir.create(DIR, showWarnings = FALSE)
tg <- function(x, k) unname(vapply(x$other_tags, \(s) {   # read one key from the hstore text
  if (is.na(s)) return(NA_character_)
  m <- regmatches(s, regexpr(sprintf('"%s"=>"[^"]*"', k), s))
  if (length(m)) sub('.*=>"(.*)"', "\\1", m) else NA_character_ }, ""))

# ---- 1. data ----
reg <- m30_region(TRUE)
f <- file.path(DIR, "power.rds")
if (!file.exists(f)) {
  cl <- m30_osm("lines", "hstore_get_value(other_tags,'power') IN ('plant','generator')", reg)
  cl <- cl[vapply(st_geometry(cl), nrow, 1L) >= 4, ]
  cp <- st_sf(st_drop_geometry(cl), geometry = st_cast(st_geometry(cl), "POLYGON")) |> st_make_valid()
  mp <- m30_osm("multipolygons", "hstore_get_value(other_tags,'power') IN ('plant','generator')", reg)
  mp <- st_sf(st_drop_geometry(mp), geometry = st_geometry(mp))
  sites <- bind_rows(cp, mp) |>
    mutate(power = tg(pick(everything()), "power"),
           src = coalesce(tg(pick(everything()), "plant:source"), tg(pick(everything()), "generator:source")),
           out = coalesce(tg(pick(everything()), "plant:output:electricity"),
                          tg(pick(everything()), "generator:output:electricity"))) |>
    select(osm_id, osm_way_id, name, power, src, out)
  lines <- m30_osm("lines", "hstore_get_value(other_tags,'power') IN ('line','minor_line','cable')", reg) |>
    mutate(volt = tg(pick(everything()), "voltage")) |> select(osm_id, volt)
  pts <- function(x) st_sf(name = x$name, geometry = st_geometry(suppressWarnings(st_centroid(x))))
  subs <- rbind(pts(m30_osm("lines", "hstore_get_value(other_tags,'power') = 'substation'", reg)),
                pts(m30_osm("multipolygons", "hstore_get_value(other_tags,'power') = 'substation'", reg)),
                pts(m30_osm("points", "hstore_get_value(other_tags,'power') = 'substation'", reg)))
  wind <- m30_osm("points", "hstore_get_value(other_tags,'generator:source') = 'wind'", reg)
  lakes <- m30_osm("multipolygons", "natural = 'water'", reg)
  lakes <- lakes[as.numeric(st_area(lakes)) > 1.5e6, ]
  saveRDS(list(sites = sites, lines = lines, subs = subs, wind = wind, lakes = lakes), f)
}
o <- lapply(readRDS(f), \(x) st_sf(st_drop_geometry(x), geometry = st_geometry(x)))   # one geometry name
invisible(list2env(o, environment()))

# ---- 2. numbers ----
sol  <- filter(sites, src == "solar")
pl   <- filter(sol, power == "plant")
lone <- filter(sol, power == "generator") |> (\(g) g[lengths(st_intersects(g, pl)) == 0, ])()
solar <- bind_rows(pl, lone)
solar$ha <- as.numeric(st_area(solar)) / 1e4
area_km2 <- as.numeric(st_area(st_union(solar))) / 1e6
lin <- st_intersection(lines, st_geometry(reg)) |> mutate(km = as.numeric(st_length(geometry)) / 1000)
km <- lin |> st_drop_geometry() |> group_by(volt) |> summarise(km = sum(km))
print(km)
km400 <- sum(km$km[which(km$volt == "400000")]); km150 <- sum(km$km[which(km$volt == "150000")])
hydro <- filter(sites, src == "hydro")
message(sprintf("FINDING: %d solar sites mapped (%d plants + %d stand-alone arrays), %.1f km2 (%.0f ha), median %.1f ha, largest %.0f ha",
                nrow(solar), nrow(pl), nrow(lone), area_km2, area_km2 * 100, median(solar$ha), max(solar$ha)))
message(sprintf("FINDING: 400 kV %.0f km, 150 kV %.0f km; %d substations; %d wind turbines; hydro: %s",
                km400, km150, nrow(subs), nrow(wind),
                paste(hydro$name, hydro$out, collapse = "; ")))

# solar per regional unit
units <- m30_units(TRUE)
cen <- suppressWarnings(st_centroid(solar))
solar$unit <- units$name[st_nearest_feature(cen, units)]
byu <- solar |> st_drop_geometry() |> group_by(unit) |> summarise(n = n(), ha = sum(ha)) |> arrange(desc(ha))
print(byu)
write.csv(byu, "30daymap/data/day12_solar_by_unit.csv", row.names = FALSE)

# ---- 3. map ----
SUN <- "#FFB627"; GRID <- "#E9F1F7"; BG <- M30$night
dem <- m30_dem() |> aggregate(3) |> mask(vect(st_buffer(reg, 1000)))
hs  <- m30_hillshade(dem) |> mask(vect(reg))
bb  <- st_bbox(reg)
solar_pt <- tibble(ha = solar$ha, x = st_coordinates(cen)[, 1], y = st_coordinates(cen)[, 2]) |> arrange(ha)
hyd_lab <- hydro |> filter(name %in% c("ΥΗΣ Πλαστήρα", "Φράγμα Τεχνητής Λίμνης Σμοκόβου",
                                       "Υδροηλεκτρικός σταθμός Γλύστρας")) |>
  st_centroid() |> mutate(lab = case_when(grepl("Πλαστ", name) ~ "Plastiras hydro\n129.9 MW",
                                          grepl("Σμοκ", name) ~ "Smokovo\n10.4 MW",
                                          TRUE ~ "Glystra hydro\n90 MW"))
hyd_lab$x <- st_coordinates(hyd_lab)[, 1]; hyd_lab$y <- st_coordinates(hyd_lab)[, 2]
hyd_lab <- hyd_lab |> mutate(
  nx = x + case_when(grepl("Πλαστ", name) ~ -9000, grepl("Σμοκ", name) ~ 14000, TRUE ~ 6000),
  ny = y + case_when(grepl("Πλαστ", name) ~ -15000, grepl("Σμοκ", name) ~ -6000, TRUE ~ -14000))
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Farsala")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])
wind$x <- st_coordinates(wind)[, 1]; wind$y <- st_coordinates(wind)[, 2]

l400 <- filter(lin, volt == "400000"); l150 <- filter(lin, volt != "400000" | is.na(volt))
pm <- ggplot() +
  geom_sf(data = reg, fill = "#171B22", colour = NA) +
  geom_spatraster(data = hs, alpha = 0.55, maxcell = 3e6) +
  scale_fill_gradient(low = "#0B0D11", high = "#2A2F38", na.value = NA, guide = "none") +
  geom_sf(data = lakes, fill = "#1F3A52", colour = NA) +
  geom_sf(data = reg, fill = NA, colour = "#3A3F48", linewidth = 0.3) +
  with_outer_glow(geom_sf(data = l150, colour = GRID, linewidth = 0.25, alpha = 0.7), colour = "#7FB8E0",
                  sigma = 6, expand = 1) +
  with_outer_glow(geom_sf(data = l400, colour = GRID, linewidth = 0.55), colour = "#7FB8E0", sigma = 10,
                  expand = 2) +
  geom_point(data = subs |> mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2]),
             aes(x, y), shape = 22, size = 1.3, fill = BG, colour = GRID, stroke = 0.4) +
  with_outer_glow(geom_point(data = solar_pt, aes(x, y, size = ha), colour = SUN, alpha = 0.9, stroke = 0),
                  colour = SUN, sigma = 5, expand = 0.5) +
  scale_size_area(max_size = 6, guide = "none") +
  geom_point(data = wind, aes(x, y), shape = 3, size = 0.9, colour = "#C9D6DF", stroke = 0.4) +
  geom_point(data = hyd_lab, aes(x, y), shape = 21, size = 2.4, fill = "#5FA8D3", colour = BG, stroke = 0.5) +
  geom_segment(data = hyd_lab, aes(x, y, xend = nx, yend = ny), colour = "#5FA8D3", linewidth = 0.25) +
  geom_text(data = hyd_lab, aes(nx, ny, label = lab), family = "Fira Sans Condensed", size = 2.9, colour = "#9CC8E3",
            lineheight = 0.9, vjust = ifelse(hyd_lab$ny > hyd_lab$y, 0, 1)) +
  geom_shadowtext(data = towns, aes(x, y + 3500, label = name), family = "Fira Sans Condensed", size = 3.1,
                  colour = M30$night_ink, bg.colour = BG, bg.r = 0.15) +
  m30_scalebar(20, bbox = bb, col = M30$night_mute) +
  coord_sf(crs = CRS_GR, datum = NA, expand = FALSE,
           xlim = c(bb["xmin"] - 3000, bb["xmax"] + 3000), ylim = c(bb["ymin"] - 3000, bb["ymax"] + 3000))

# ---- 4. bars: solar area per regional unit ----
byu <- byu |> mutate(unit = factor(unit, rev(unit)))
pb <- ggplot(byu, aes(y = unit)) +
  geom_col(aes(x = ha), fill = SUN, width = 0.55) +
  geom_text(aes(x = ha, label = sprintf("%s ha · %s sites", format(round(ha), big.mark = ","), n)), hjust = -0.06,
            family = "Fira Sans Condensed", size = 3.2, colour = M30$night_ink) +
  geom_text(aes(x = 0, label = unit), hjust = 1.08, family = "Fira Sans Condensed", size = 3.4,
            colour = M30$night_ink) +
  annotate("text", x = -0.2 * max(byu$ha), y = 4.85, label = "MAPPED SOLAR AREA BY REGIONAL UNIT", hjust = 0,
           family = "Oswald", size = 3.7, colour = M30$night_ink) +
  scale_x_continuous(limits = c(-0.2 * max(byu$ha), 1.45 * max(byu$ha)), expand = c(0, 0)) +
  coord_cartesian(clip = "off", ylim = c(0.5, 5)) + theme_void()

L <- m30_labs(12, "Power",
  title = sprintf("%s solar parks, %.0f km² of panels", format(nrow(solar), big.mark = ","), area_km2),
  subtitle = sprintf(paste0(
    "Each <b style='color:%s'>amber dot</b> is a solar site traced in OpenStreetMap, sized by its area (median %.1f ha). ",
    "<b style='color:%s'>Glowing lines</b>: %.0f km of 400 kV and %.0f km of 150 kV grid; squares are substations, ",
    "crosses wind turbines. OSM is mapped by volunteers, so rooftop panels and the newest parks are missing."),
    SUN, median(solar$ha), "#B9DDF2", km400, km150),
  source = "OpenStreetMap contributors, Geofabrik extract 2026-10-28 (ODbL) · Copernicus GLO-90 DEM · Eurostat GISCO NUTS 2021 · GADM 4.1",
  accent = SUN)
cap <- L$caption; L$caption <- NULL
p <- (pm + L + theme_m30(dark = TRUE) + theme(plot.title = element_markdown(family = "Oswald", size = 13 * 2.6,
       colour = M30$night_ink, margin = margin(26, 0, 14, 0)))) /
  (pb + labs(caption = cap) + theme_m30(dark = TRUE) + theme(plot.margin = margin(4, 36, 22, 36))) +
  plot_layout(heights = c(3.9, 1)) +
  plot_annotation(theme = theme(plot.background = element_rect(fill = BG, colour = NA)))
m30_save(p, 12, "power", 8, 9.4, bg = BG)
