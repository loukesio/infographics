# Day 18 · NULL — "36% of Thessaly has no resident at all"
# Kontur keeps only hexagons with at least one person. Everything else is NULL: land where no 400 m hexagon holds
# a single resident. Here the NULL land is hatched, the inhabited hexagons are left blank-ish, and a strip below
# shows how the NULL share rises with altitude.
#
# Data   : Kontur Population Greece 2023-11-01, 400 m H3 hexagons (HDX, CC BY 4.0)
#          https://data.humdata.org/dataset/kontur-population-greece
#          Copernicus GLO-90 DEM (ESA / Copernicus, via AWS open data) for elevation bands (m30_dem)
#          OpenStreetMap peaks (natural=peak; Geofabrik extract 2026-10-28, ODbL) for 5 mountain labels
#          Eurostat GISCO NUTS 2021 EL61 mainland border
# Method : NULL land = region polygon minus the union of all Kontur hexagons touching it (vector areas, EGSA87).
#          Elevation bands: the NULL polygon rasterised on the 90 m DEM grid; share of DEM cells per band.
# Caveats: Kontur population is modelled (GHSL + Facebook HRSL + Microsoft buildings, scaled to official totals),
#          so very small hamlets or seasonal shepherds' huts may be missed or smeared. 400 m hexagons on the
#          border are counted whole when they touch the region. "No resident" ≠ "no use": fields, forests, pasture.

source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext) })
DIR <- file.path(M30_CACHE, "day18"); dir.create(DIR, showWarnings = FALSE)

# ---- 1. data ----
reg <- m30_region(TRUE)
pop <- read_sf("data/kontur/kontur_population_GR_20231101.gpkg") |> st_transform(CRS_GR)
pop <- pop[lengths(st_intersects(pop, reg)) > 0, ]
empty <- st_difference(st_geometry(reg), st_union(pop)) |> st_sf(geometry = _)
a_reg <- as.numeric(st_area(reg)) / 1e6; a_emp <- as.numeric(st_area(empty)) / 1e6
sh <- a_emp / a_reg
message(sprintf("FINDING: %.1f%% of mainland Thessaly (%s of %s km2) has no resident in any 400 m hexagon; %d hexagons, %s people",
                100 * sh, format(round(a_emp), big.mark = ","), format(round(a_reg), big.mark = ","), nrow(pop),
                format(sum(pop$population), big.mark = ",")))

# ---- 2. NULL share by elevation band ----
dem <- mask(m30_dem(), vect(reg))
nul <- rasterize(vect(empty), dem, field = 1, background = 0) |> mask(vect(reg))
br <- c(-Inf, 200, 500, 1000, 1500, Inf)
bl <- c("below 200 m", "200–500 m", "500–1,000 m", "1,000–1,500 m", "above 1,500 m")
band <- tibble(elev = values(dem)[, 1], null = values(nul)[, 1]) |> filter(!is.na(elev), !is.na(null)) |>
  mutate(band = factor(cut(elev, br, labels = bl), bl)) |>
  group_by(band) |> summarise(km2 = n() * 0.0081, null = mean(null)) |>
  mutate(land_sh = km2 / sum(km2))
print(band)
write.csv(band, "30daymap/data/day18_null_by_elevation.csv", row.names = FALSE)
message(sprintf("FINDING: NULL share below 200 m = %.0f%%, above 1,500 m = %.0f%%", 100 * band$null[1], 100 * band$null[5]))

up200 <- with(band, sum((km2 * null)[-1]) / sum(km2 * null))
message(sprintf("FINDING: %.0f%% of NULL land lies above 200 m", 100 * up200))

# ---- 3. hatch for the NULL land ----
bb <- st_bbox(reg); sp <- 650                        # one hairline every 650 m, at 45 degrees
off <- seq(bb["xmin"] - (bb["ymax"] - bb["ymin"]), bb["xmax"], by = sp)
hl <- lapply(off, \(o) st_linestring(rbind(c(o, bb["ymin"]), c(o + (bb["ymax"] - bb["ymin"]), bb["ymax"]))))
hatch <- st_sfc(hl, crs = CRS_GR) |> st_intersection(st_geometry(empty)) |> st_sf(geometry = _)

# ---- 4. labels: five massifs, at their highest named OSM peak ----
pk <- m30_osm("points", "hstore_get_value(other_tags,'natural')='peak' AND name IS NOT NULL", reg)
massif <- tribble(~name, ~en, ~dx, ~dy, ~hj,
  "Σκολιό", "OLYMPUS", 5000, 2500, 0,
  "Μπρισίμι", "PINDUS", 6000, 0, 0,
  "Καράβα (Αγράφων)", "AGRAFA", 7000, -4000, 0,
  "Πουριανός Σταυρός", "PELION", 4000, 0, 0,
  "Γερακοβούνι (Όθρυς)", "OTHRYS", 0, -7000, 0.5)
lab <- pk |> filter(name %in% massif$name) |> distinct(name, .keep_all = TRUE) |> left_join(massif, by = "name")
lab$x <- st_coordinates(lab)[, 1]; lab$y <- st_coordinates(lab)[, 2]
stopifnot(nrow(lab) == 5)
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])

ACC <- "#6B3A5E"
pm <- ggplot() +
  geom_sf(data = reg, fill = "white", colour = NA) +
  geom_sf(data = empty, fill = "#F1E8EE", colour = NA) +
  geom_sf(data = hatch, colour = ACC, linewidth = 0.13) +
  geom_sf(data = reg, fill = NA, colour = M30$ink, linewidth = 0.3) +
  geom_point(data = lab, aes(x, y), shape = 17, size = 1.4, colour = M30$ink) +
  geom_shadowtext(data = lab, aes(x + dx, y + dy, label = en, hjust = hj), family = "Fira Mono", size = 3.1,
                  colour = M30$ink, bg.colour = "white", bg.r = 0.2) +
  geom_shadowtext(data = towns, aes(x, y, label = name), family = "Fira Sans Condensed", 
                  size = 3.2, colour = M30$soft, bg.colour = "white", bg.r = 0.2) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, datum = NA, expand = FALSE,
           xlim = c(bb["xmin"] - 3000, bb["xmax"] + 3000), ylim = c(bb["ymin"] - 3000, bb["ymax"] + 3000))

# ---- 5. strip: NULL share per elevation band ----
pb <- ggplot(band, aes(y = band)) +
  geom_col(aes(x = 1), fill = "#EFECE7", width = 0.62) +
  geom_col(aes(x = null), fill = ACC, width = 0.62) +
  geom_text(aes(x = null, label = sprintf("%.0f%%", 100 * null)), hjust = -0.15, family = "Fira Mono",
            size = 3.3, colour = ifelse(band$null > 0.9, "white", M30$ink),
            nudge_x = ifelse(band$null > 0.9, -0.1, 0)) +
  geom_text(aes(x = -0.02, label = band), hjust = 1, family = "Fira Sans Condensed", size = 3.3, colour = M30$ink) +
  geom_text(aes(x = 1.02, label = sprintf("%s km² of land", format(round(km2, -1), big.mark = ","))), hjust = 0,
            family = "Fira Sans Condensed", size = 2.9, colour = M30$soft) +
  annotate("text", x = -0.2, y = 5.75, label = "SHARE OF LAND WITH NO RESIDENT, BY ALTITUDE", hjust = 0, family = "Oswald", size = 3.8,
           colour = M30$ink) +
  scale_y_discrete(limits = rev(bl)) +
  scale_x_continuous(limits = c(-0.2, 1.24), expand = c(0, 0)) +
  coord_cartesian(clip = "off", ylim = c(0.6, 5.9)) + theme_void()

L <- m30_labs(18, "NULL",
  title = sprintf("%d%% of Thessaly has no resident at all", round(100 * sh)),
  subtitle = sprintf(paste0(
    "Kontur counts people in 400 m hexagons and simply leaves out the ones where nobody lives. ",
    "That missing land is <b style='color:%s'>hatched</b>: %s km², %.0f%% of it above 200 m. White is land with at least one resident."),
    ACC, format(round(a_emp, -1), big.mark = ","), 100 * up200),
  source = paste("Kontur Population 2023, 400 m H3 hexagons (HDX, CC BY) · Copernicus GLO-90 DEM ·",
                 "OpenStreetMap peaks (ODbL) · Eurostat GISCO NUTS 2021, mainland Thessaly"),
  accent = ACC)
cap <- L$caption; L$caption <- NULL
p <- (pm + L + theme_m30() + theme(plot.title = element_markdown(family = "Oswald", size = 13 * 2.6, colour = M30$ink, margin = margin(26, 0, 14, 0)))) / (pb + labs(caption = cap) + theme_m30() + theme(plot.margin = margin(4, 36, 22, 36))) +
  plot_layout(heights = c(3.3, 1))
m30_save(p, 18, "null", 8, 10)
