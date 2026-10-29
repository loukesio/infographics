# Day 22 · Projections — One Thessaly, nine maps, nine different sizes
# The same outline of the Region of Thessaly (with the Sporades) drawn in nine map projections at ONE common scale,
# each with the area it implies when you measure it flat on that map. The dashed grey ghost is the true shape
# (Lambert azimuthal equal-area centred on Larissa). Finding: the spread of areas against the true ellipsoidal area.
#
# Data
#   * Region border: Eurostat GISCO NUTS 2021 1:1M (EL61), https://gisco-services.ec.europa.eu/distribution/v2/nuts/
#   * Globe: Natural Earth 1:110m countries (public domain) via rnaturalearth
#   * Projection definitions: EPSG registry / PROJ (Greek Grid EGSA87 EPSG:2100, UTM 34N EPSG:32634, UTM 31N EPSG:32631,
#     Web Mercator EPSG:3857, World Equidistant Cylindrical EPSG:4087, Mollweide ESRI:54009, LAEA and orthographic
#     centred on Larissa, orthographic seen from 0° N 50° W)
#
# How
#   * True area: geodesic area on the WGS84 ellipsoid, terra::expanse() on lon/lat (GeographicLib).
#   * Map area: planar area of the projected polygon (sf::st_area with a projected CRS).
#
# Caveats
#   * The 1:1M border is generalised; areas are of that outline (the official area of Thessaly is ~14,036 km²).
#   * Mollweide in PROJ uses a sphere with the WGS84 semi-major axis, hence +0.1% though it is "equal-area".
source("30daymap/R/m30_base.R")

# ---- 1. data -------------------------------------------------------------------------------------
th <- st_transform(m30_region(FALSE), 4326)
true_km2 <- expanse(vect(th), unit = "km")
LAR <- c(22.4191, 39.6390)
pj <- tribble(
  ~id, ~name,                           ~code,         ~crs,
  1, "Greek Grid (EGSA87)",             "EPSG:2100",   "EPSG:2100",
  2, "UTM zone 34N",                    "EPSG:32634",  "EPSG:32634",
  3, "UTM zone 31N (wrong zone)",       "EPSG:32631",  "EPSG:32631",
  4, "Web Mercator",                    "EPSG:3857",   "EPSG:3857",
  5, "Equidistant cylindrical",         "EPSG:4087",   "EPSG:4087",
  6, "Mollweide",                       "ESRI:54009",  "ESRI:54009",
  7, "Lambert azimuthal, on Larissa",   "+proj=laea",  sprintf("+proj=laea +lat_0=%.4f +lon_0=%.4f +datum=WGS84", LAR[2], LAR[1]),
  8, "Orthographic, from 50° W", "+proj=ortho", "+proj=ortho +lat_0=0 +lon_0=-50 +datum=WGS84",
  9, "Orthographic, on Larissa",        "+proj=ortho", sprintf("+proj=ortho +lat_0=%.4f +lon_0=%.4f +datum=WGS84", LAR[2], LAR[1])
)
# shape in each projection, shifted so its centroid sits at 0,0 (same metres for every panel)
shape_in <- function(crs) {
  g <- st_geometry(st_transform(th, crs)); c0 <- st_coordinates(st_centroid(g))
  (g - c0) |> st_set_crs(NA)
}
shapes <- pj |> mutate(geometry = map(crs, \(c) shape_in(c)[[1]]) |> st_sfc(),
                       km2 = map_dbl(crs, \(c) as.numeric(st_area(st_transform(th, c))) / 1e6),
                       diff = km2 / true_km2 - 1) |> st_as_sf()
ghost <- shape_in(pj$crs[7])
message(sprintf("True (ellipsoidal) area: %.0f km2", true_km2))
print(st_drop_geometry(shapes)[, c("name", "code", "km2", "diff")])

# ---- 2. small multiples --------------------------------------------------------------------------
ACC <- "#1F6F8B"; HOT <- "#B4442C"
fmt_pct <- function(d) ifelse(abs(d) < 0.0005, "±0.0%", sprintf("%+.1f%%", 100 * d))
shapes <- shapes |> mutate(
  col = ifelse(abs(diff) > 0.02, HOT, ACC),
  strip = sprintf("<span style='font-family:Oswald;font-size:12.5pt;color:%s'>%s</span><br>
<span style='color:%s'>%s · %s km² · <b style='color:%s'>%s</b></span>",
                  M30$ink, name, M30$soft, code, format(round(km2), big.mark = ","), col, fmt_pct(diff)),
  strip = factor(strip, strip))
ghosts <- shapes |> st_drop_geometry() |> select(strip) |> mutate(geometry = rep(ghost, nrow(shapes))) |> st_as_sf()

# globe locator inside the last panel (scaled down, not to scale with the shapes)
ortho <- pj$crs[9]; R <- 6378137; gs <- 40000 / R; goff <- c(128000, 42000)
world <- rnaturalearth::ne_countries(scale = 110, returnclass = "sf") |> st_geometry()
circ <- st_buffer(st_sfc(st_point(c(0, 0))), R)
sf_use_s2(TRUE)                                       # clip to the visible hemisphere on the sphere first
cap <- st_buffer(st_sfc(st_point(LAR), crs = 4326), 9.9e6)
vis <- s2::s2_geog_from_wkb(st_as_binary(world), check = FALSE) |> s2::s2_rebuild() |> s2::s2_union_agg() |>
  s2::s2_intersection(cap) |> st_as_sfc()
sf_use_s2(FALSE)
vis <- st_transform(vis, ortho) |> st_set_crs(NA) |> st_make_valid()
globe <- list(
  geom_sf(data = st_sf(strip = factor(levels(shapes$strip)[9], levels(shapes$strip)), geometry = circ * gs + goff), fill = "#F2F4F5",
          colour = M30$mute, linewidth = .25, inherit.aes = FALSE),
  geom_sf(data = st_sf(strip = factor(levels(shapes$strip)[9], levels(shapes$strip)), geometry = vis * gs + goff), fill = "#D9D9D9",
          colour = NA, inherit.aes = FALSE),
  geom_sf(data = st_sf(strip = factor(levels(shapes$strip)[9], levels(shapes$strip)), geometry = st_sfc(st_point(c(0, 0))) + goff),
          colour = HOT, size = 1.6, inherit.aes = FALSE))

p1 <- ggplot() +
  geom_sf(data = ghosts, fill = NA, colour = M30$mute, linewidth = .3, linetype = "22") +
  geom_sf(data = shapes, aes(fill = col, colour = col), alpha = .18, linewidth = .45) +
  globe +
  scale_fill_identity() + scale_colour_identity() +
  facet_wrap(~strip, ncol = 3) +
  coord_sf(xlim = c(-185000, 185000), ylim = c(-88000, 92000), expand = FALSE, datum = NA, clip = "off") +
  theme_m30() +
  theme(strip.text = element_textbox_simple(size = 9.3, lineheight = 1.25, margin = margin(0, 0, 4, 0), halign = 0),
        panel.spacing.x = unit(14, "pt"), panel.spacing.y = unit(16, "pt"),
        plot.title = element_markdown(margin = margin(26, 0, 12, 0)),
        plot.subtitle = element_textbox_simple(margin = margin(0, 0, 18, 0)),
        plot.margin = margin(30, 36, 4, 36))

# ---- 3. strip: all areas on one line -------------------------------------------------------------
dots <- st_drop_geometry(shapes) |> arrange(km2) |>
  mutate(lab = recode(name, "UTM zone 31N (wrong zone)" = "UTM 31N", "Equidistant cylindrical" = "Equidistant cyl.",
                      "Orthographic, from 50° W" = "Orthographic from 50° W"))
p2 <- ggplot(dots, aes(km2, 0)) +
  annotate("segment", x = 0, xend = 25000, y = 0, yend = 0, colour = M30$line, linewidth = .5) +
  annotate("segment", x = true_km2, xend = true_km2, y = -.6, yend = .35, colour = M30$ink, linewidth = .4) +
  annotate("text", x = true_km2, y = -.75, label = sprintf("true area %s km²", format(round(true_km2), big.mark = ",")),
           family = "Fira Sans Condensed", fontface = "bold", size = 3.2, colour = M30$ink, vjust = 1) +
  geom_point(aes(colour = col), size = 2.8, alpha = .85) +
  geom_text(data = filter(dots, abs(diff) > .02), aes(label = lab, colour = col), nudge_y = .45, vjust = 0,
            family = "Fira Sans Condensed", fontface = "bold", size = 3.1) +
  annotate("text", x = true_km2 - 500, y = .45, hjust = 1, vjust = 0, label = "five maps within 0.2%",
           family = "Fira Sans Condensed", size = 3.1, colour = ACC) +
  scale_colour_identity() +
  scale_x_continuous(limits = c(0, 25000), breaks = seq(0, 25000, 5000), labels = \(x) paste(format(x, big.mark = ","), "km²"),
                     expand = c(0, 0)) +
  scale_y_continuous(limits = c(-1.4, 1.5)) +
  theme_m30() +
  theme(axis.text.x = element_text(family = "Fira Sans Condensed", size = 8.5, colour = M30$soft),
        axis.ticks.x = element_line(colour = M30$line), axis.ticks.length.x = unit(3, "pt"),
        plot.margin = margin(0, 36, 22, 36))

hi <- shapes[which.max(shapes$km2), ]; lo <- shapes[which.min(shapes$km2), ]
p1 <- p1 + labs(
  tag = m30_labs(22, "Projections", "x", accent = ACC)$tag,
  title = sprintf("Thessaly is %s km². Web Mercator<br>makes it %s, a far-side globe %s",
                  format(round(true_km2, -1), big.mark = ","), format(round(hi$km2, -2), big.mark = ","),
                  format(round(lo$km2, -1), big.mark = ",")),
  subtitle = sprintf(paste0(
    "The same outline of the Region of Thessaly drawn in nine map projections at one common scale, each labelled with the area ",
    "you would measure flat on that map. The <span style='color:%s'>dashed ghost</span> is the true shape. Maps made for Greece, ",
    "or built to keep areas, stay within 0.2%%; <b style='color:%s'>the others are off</b> from %s to %s."),
    M30$mute, HOT, fmt_pct(lo$diff), fmt_pct(hi$diff)))
p2 <- p2 + labs(caption = m30_labs(22, "Projections", "x",
  source = "Eurostat GISCO NUTS 2021 (EL61, 1:1M, with the Sporades) · Natural Earth · PROJ / EPSG registry",
  extra = "true area = geodesic area on the WGS84 ellipsoid (terra::expanse); map area = planar area of the projected outline")$caption)
p <- patchwork::wrap_plots(p1, p2, ncol = 1, heights = c(1, .16)) &
  theme(plot.background = element_rect(fill = M30$paper, colour = NA))
m30_save(p, 22, "projections", w = 9, h = 9.6)
