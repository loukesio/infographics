# Day 08 · Utopia — Lake Karla (ancient Boibeis): the lake that was, the lake they want back
# Lake Karla was drained in 1957–62 for farmland; a smaller lake was re-created from 2010 (filled 2018) in the
# lowest part of the old bed. This map draws the old lake at its documented record size (about 180 km², winter 1920–21) as the
# basin outline from today's terrain that holds that area, against today's reservoir (OpenStreetMap) and the water that Storm Daniel brought back in September 2023.
#
# Data
#   * Old lake sizes: Municipality of Rigas Feraios, «Λίμνη Κάρλα» (history page): surface "60.000–180.000 περίπου
#     στρέμματα", largest extent "περίπου 180.000 στρέμματα" in winter 1920–21 (Pineios floods); drainage works
#     from 1956, final drainage 1962. https://www.rigas-feraios.gr/επισκεπτες/ιστορία/λίμνη-κάρλα/
#   * Re-created lake design area 38 km², mean depth ~2 m: Kagalou & Latinopoulos (2026), Frontiers in
#     Environmental Science, doi:10.3389/fenvs.2026.1903658
#   * Today's lake: OpenStreetMap relation 12301781 «Λίμνη Κάρλα» (Geofabrik extract 2026-10-28, ODbL)
#   * Storm Daniel flood: Copernicus EMS EMSR692 observed flood extent, union 6–22 Sep 2023 (raster cached by day 26,
#     rebuilt here if missing). © EU, Copernicus EMS
#   * Terrain: Copernicus GLO-90 DEM (via m30_base.R)
#
# Caveats (also on the chart)
#   * No citable shoreline elevation for the old lake was found. The outlines are DERIVED: the level in today's
#     DEM whose connected basin (seeded in today's lake) has the documented area. The bed has been farmed and has
#     subsided since 1962, and GLO-90 is a 90 m surface model with today's reservoir as a flat 45 m surface, so
#     the shapes are an approximation of the old lake, not a surveyed shoreline.
#   * The 2023 flood count is only the EMS flood pixels inside the Karla basin (connected land below 60 m).
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(shadowtext); library(patchwork) })

# ---- 1. data -----------------------------------------------------------------------------------------
view4 <- st_bbox(c(xmin = 22.50, xmax = 23.00, ymin = 39.37, ymax = 39.69), crs = 4326)
vbox <- st_as_sfc(view4) |> st_transform(CRS_GR) |> st_sf()
view <- st_bbox(vbox)
karla <- m30_osm("multipolygons", "name = 'Λίμνη Κάρλα'", clip = vbox) |> st_union() |> st_sf(geometry = _)
karla_km2 <- as.numeric(st_area(karla)) / 1e6
dem <- m30_dem(crop = NULL) |> crop(vect(st_buffer(vbox, 3000)))
seed <- st_coordinates(st_point_on_surface(karla))

# connected area below level h, seeded inside today's lake
basin_at <- function(h) {
  m <- dem <= h; m[m == 0] <- NA
  pp <- patches(m, directions = 8)
  id <- pp[cellFromXY(pp, seed)][1, 1]
  pp == id
}
area_at <- function(h) global(basin_at(h), "sum", na.rm = TRUE)[1, 1] * prod(res(dem)) / 1e6
level_for <- function(target) uniroot(\(h) area_at(h) - target, c(45.01, 60), tol = .02)$root
h_hi <- level_for(180)
# (the 60 km2 low water cannot be drawn: today's DEM already holds 67 km2 at the reservoir's flat 45 m surface)
to_poly <- function(h) basin_at(h) |> classify(cbind(0, NA)) |> as.polygons() |> st_as_sf() |>
  st_union() |> st_sf(geometry = _) |> smoothr::smooth(method = "ksmooth", smoothness = 2) |> st_make_valid()
lake_hi <- to_poly(h_hi)
message(sprintf("Old lake: 180 km2 is held below %.1f m (today's DEM); today's lake (OSM) %.1f km2", h_hi, karla_km2))
message(sprintf("Today's lake = %.0f%% of the 1920–21 high water (%.1f times smaller)", 100 * karla_km2 / 180, 180 / karla_km2))

# Storm Daniel: EMS flood pixels in the Karla basin (connected land below 60 m)
fr <- file.path(M30_CACHE, "emsr692", "flood_union_20m.tif")
if (!file.exists(fr)) source("30daymap/scripts/day26_water_daniel_flood.R")
basin60 <- basin_at(60) |> classify(cbind(0, NA)) |> as.polygons() |> st_as_sf()
fl <- rast(fr) |> crop(vect(vbox)) |> mask(vect(basin60))
fl_km2 <- global(fl, "sum", na.rm = TRUE)[1, 1] * 400 / 1e6
fpoly <- aggregate(fl, 3, fun = "max", na.rm = TRUE) |> as.polygons() |> st_as_sf() |> st_union() |>
  st_sf(geometry = _) |> smoothr::fill_holes(units::set_units(2, km^2)) |>
  smoothr::drop_crumbs(units::set_units(1, km^2))           # outline of the 2023 water, for drawing only
message(sprintf("Daniel 2023: %.0f km2 flooded inside the Karla basin (EMS union 6–22 Sep)", fl_km2))

hs  <- m30_hillshade(dem)
hsd <- as.data.frame(hs, xy = TRUE, na.rm = TRUE)
el  <- as.data.frame(dem, xy = TRUE, na.rm = TRUE) |> filter(elev > 0.5)   # sea (0 m) stays white
sea <- as.polygons(classify(dem, cbind(-Inf, 0.5, 1), others = NA)) |> st_as_sf() |> st_union() |> st_sf(geometry = _) |>
  smoothr::smooth(method = "ksmooth", smoothness = 3) |> st_buffer(60)        # Aegean, smoothed 90 m edge

vill <- m30_osm("points", "place IN ('town','village') AND name IN ('Στεφανοβίκειο','Κανάλια','Κεραμίδι','Καλαμάκι','Βελεστίνο','Ριζόμυλος')",
                clip = vbox) |>
  mutate(en = c(`Στεφανοβίκειο` = "Stefanovikio", `Κανάλια` = "Kanalia", `Κεραμίδι` = "Keramidi", `Καλαμάκι` = "Kalamaki",
                `Βελεστίνο` = "Velestino", `Ριζόμυλος` = "Rizomylos")[name]) |>
  distinct(en, .keep_all = TRUE)
vill <- vill |> mutate(x = st_coordinates(vill)[, 1], y = st_coordinates(vill)[, 2])
message("Villages found in OSM: ", paste(vill$en, collapse = ", "))

dlab <- tribble(~lab, ~lon, ~lat, ~col,
                "the old lake\n(1920–21 high)", 22.585, 39.465, "#4F7FA3",
                "Karla\ntoday", 22.835, 39.490, "white") |>
  st_as_sf(coords = c("lon", "lat"), crs = 4326) |> st_transform(CRS_GR)
dlab <- dlab |> mutate(x = st_coordinates(dlab)[, 1], y = st_coordinates(dlab)[, 2])   # positions checked on the render
ol <- st_coordinates(st_transform(st_sfc(st_point(c(22.705, 39.535)), crs = 4326), CRS_GR))[1, ]   # leader end, inside old lake

# ---- 2. plot -----------------------------------------------------------------------------------------
c_hi <- "#CFE3EE"; c_lo <- "#8DBAD6"; c_now <- "#0D4F8B"; c_fl <- "#2C8C99"
map <- ggplot() +
  geom_raster(data = el, aes(x, y, fill = elev), show.legend = FALSE) +
  scale_fill_gradient(low = "#F6F3EE", high = "#C8C0B4", limits = c(40, 1200), oob = scales::squish) +
  ggnewscale::new_scale_fill() +
  geom_raster(data = hsd, aes(x, y, alpha = 1 - shade), fill = "#3A3530", show.legend = FALSE) +
  scale_alpha(range = c(0, .5)) +
  geom_sf(data = sea, fill = "white", colour = NA) +
  geom_sf(data = lake_hi, fill = c_hi, colour = "#7FA9C4", linewidth = .35, alpha = .9) +
  geom_sf(data = karla, fill = c_now, colour = NA) +
  geom_sf(data = fpoly, fill = NA, colour = c_fl, linewidth = .45, linetype = "22") +
  geom_point(data = vill, aes(x, y), shape = 21, fill = "white", colour = M30$ink, size = 1.5, stroke = .45) +
  geom_shadowtext(data = vill, aes(x, y, label = en), family = "Fira Sans Condensed", size = 3.2, colour = M30$ink,
                  bg.colour = "white", bg.r = .12, nudge_y = 1300) +
  annotate("segment", x = dlab$x[1] + 1500, y = dlab$y[1] + 1500, xend = ol[1], yend = ol[2], colour = "#4F7FA3", linewidth = .3) +
  geom_text(data = dlab, aes(x, y, label = lab, colour = I(col)), family = "Fira Sans Condensed", fontface = "bold",
            size = 3.3, lineheight = .9) +
  annotate("text", x = view["xmax"] - 2500, y = view["ymax"] - 3000, label = "AEGEAN", family = "Fira Sans Condensed",
           size = 3.2, colour = "#7FA9C4", hjust = 1) +
  coord_sf(crs = CRS_GR, xlim = view[c(1, 3)], ylim = view[c(2, 4)], expand = FALSE) +
  m30_scalebar(5, bbox = view) +
  theme_m30() + theme(plot.margin = margin(18, 30, 0, 30),
                      plot.title = element_markdown(margin = margin(26, 0, 16, 0)))

bars <- tribble(
  ~what,                                         ~km2,      ~col,
  "Old lake, high water of winter 1920–21",      180,       c_hi,
  "Water in the basin after Storm Daniel, 2023", fl_km2,    c_fl,
  "Re-created lake, as designed",                38,        "#5C86AE",
  "Lake Karla today (OpenStreetMap)",            karla_km2, c_now) |>
  mutate(what = factor(what, rev(what)))
strip <- ggplot(bars, aes(km2, what)) +
  geom_col(aes(fill = I(col)), width = .42) +
  geom_text(aes(x = 0, label = what), hjust = 0, vjust = -1.25, family = "Fira Sans Condensed", size = 3.4, colour = M30$ink) +
  geom_text(aes(label = paste0(round(km2), " km²")), hjust = -.12, family = "Oswald", size = 3.9, colour = M30$ink) +
  scale_x_continuous(expand = expansion(mult = c(0, .12))) +
  scale_y_discrete(expand = expansion(add = c(.4, .9))) +
  theme_m30() + theme(plot.margin = margin(10, 30, 0, 30))

map <- map + m30_labs(8, "Utopia",
  title = sprintf("Karla came back at a fifth of its size"),
  subtitle = sprintf(paste0(
    "Lake Boibeis, later Karla, covered 60 to 180 km² until it was drained in 1962. ",
    "The <b style='color:%s'>re-created lake</b> fills %.0f km² of the old bed. <b style='color:#6E9CBE'>Pale blue</b> is the old lake ",
    "at its record high of winter 1920–21, drawn from today's terrain at the level that holds 180 km² (%.1f m). ",
    "In September 2023 Storm Daniel briefly brought back %.0f km² of water (<b style='color:%s'>dashed</b>)."),
    c_now, karla_km2, h_hi, fl_km2, c_fl), accent = c_now) + labs(caption = NULL)
strip <- strip + labs(caption = m30_labs(8, "x", "x", source = paste0(
  "Municipality of Rigas Feraios, history of Lake Karla (old lake 60–180 km²) · Kagalou & Latinopoulos 2026, Frontiers in Env. Science ",
  "(design 38 km²) · OpenStreetMap 2026 · Copernicus EMS EMSR692 (2023) · Copernicus GLO-90 DEM"),
  extra = "Old shorelines are derived from today's DEM, not surveyed: the drained bed has been farmed and has sunk since 1962")$caption)
p <- map / strip + plot_layout(heights = c(3.4, 1))
m30_save(p, 8, "utopia_karla", w = 8, h = 10)
