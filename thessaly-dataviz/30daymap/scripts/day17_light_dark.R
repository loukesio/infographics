# Day 17 · Light & dark — Thessaly one hour before the shortest day's sunset
# The relief lit by the real sun of 21 December 2025 at 16:09 Greek time (one hour before sunset at Larissa). The sun
# stands low in the south-west, so the north-east faces of Olympus, Ossa, Pelion and the Pindus ridges, and every
# valley behind a ridge, are already dark. Finding: share of mainland Thessaly's land in shadow at that moment.
#
# Data
#   * Copernicus GLO-90 DEM (ESA / Airbus, 2021), https://copernicus-dem-90m.s3.amazonaws.com/ via m30_dem()
#   * Sun position: NOAA Solar Calculator formulas (Meeus), implemented below, incl. atmospheric refraction
#     https://gml.noaa.gov/grad/solcalc/calcdetails.html — printed with message()
#   * Region border: Eurostat GISCO NUTS 2021 (EL61), mainland part
#
# How the shadow is computed
#   * Self-shadow: slope faces turned away from the sun (cosine of the incidence angle <= 0).
#   * Cast shadow: for every cell, march 30 km towards the sun on the 90 m grid (nearest cell) and check whether any
#     terrain rises above the sun ray (earth curvature with refraction k = 1/7 included). A cell is "in shadow" if
#     either is true. The DEM extends 20 km beyond the border, so ridges just outside Thessaly cast shadows too.
#
# Caveats
#   * Bare terrain, one sun position for the whole region (computed at Larissa; across Thessaly the sun differs by
#     < 1 degree). Clouds, haze, trees and buildings are ignored.
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages(library(shadowtext))

# ---- 1. sun position (NOAA) ----------------------------------------------------------------------
noaa_sun <- function(t_utc, lat, lon) {
  jd <- as.numeric(t_utc) / 86400 + 2440587.5
  jc <- (jd - 2451545) / 36525
  L0 <- (280.46646 + jc * (36000.76983 + jc * 0.0003032)) %% 360
  M  <- 357.52911 + jc * (35999.05029 - 0.0001537 * jc)
  e  <- 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc)
  rad <- pi / 180
  C  <- sin(M * rad) * (1.914602 - jc * (0.004817 + 0.000014 * jc)) + sin(2 * M * rad) * (0.019993 - 0.000101 * jc) +
        sin(3 * M * rad) * 0.000289
  tl <- L0 + C
  om <- 125.04 - 1934.136 * jc
  lam <- tl - 0.00569 - 0.00478 * sin(om * rad)
  eps0 <- 23 + (26 + ((21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813)))) / 60) / 60
  eps <- eps0 + 0.00256 * cos(om * rad)
  decl <- asin(sin(eps * rad) * sin(lam * rad)) / rad
  y <- tan(eps / 2 * rad)^2
  eqt <- 4 / rad * (y * sin(2 * L0 * rad) - 2 * e * sin(M * rad) + 4 * e * y * sin(M * rad) * cos(2 * L0 * rad) -
                    0.5 * y^2 * sin(4 * L0 * rad) - 1.25 * e^2 * sin(2 * M * rad))
  mins <- (as.numeric(t_utc) %% 86400) / 60
  tst <- (mins + eqt + 4 * lon) %% 1440
  ha <- ifelse(tst / 4 < 0, tst / 4 + 180, tst / 4 - 180)
  zen <- acos(sin(lat * rad) * sin(decl * rad) + cos(lat * rad) * cos(decl * rad) * cos(ha * rad)) / rad
  alt <- 90 - zen
  # refraction
  refr <- ifelse(alt > 85, 0, ifelse(alt > 5, 58.1 / tan(alt * rad) - 0.07 / tan(alt * rad)^3 + 0.000086 / tan(alt * rad)^5,
           ifelse(alt > -0.575, 1735 + alt * (-518.2 + alt * (103.4 + alt * (-12.79 + alt * 0.711))), -20.772 / tan(alt * rad)))) / 3600
  az <- ifelse(ha > 0, (acos(((sin(lat * rad) * cos(zen * rad)) - sin(decl * rad)) / (cos(lat * rad) * sin(zen * rad))) / rad + 180) %% 360,
               (540 - acos(((sin(lat * rad) * cos(zen * rad)) - sin(decl * rad)) / (cos(lat * rad) * sin(zen * rad))) / rad) %% 360)
  data.frame(t = t_utc, alt_geom = alt, alt = alt + refr, az = az, decl = decl, eqt = eqt)
}
LAT <- 39.6390; LON <- 22.4191                                       # Larissa centre (m30_towns)
day <- seq(as.POSIXct("2025-12-21 00:00", tz = "UTC"), by = "1 min", length.out = 1440)
sun <- noaa_sun(day, LAT, LON)
t_rise <- day[min(which(sun$alt_geom > -0.833))]; t_set <- day[max(which(sun$alt_geom > -0.833))]
t0  <- t_set - 3600
s0  <- noaa_sun(t0, LAT, LON)
loc <- function(t) format(t, "%H:%M", tz = "Europe/Athens")
message(sprintf("Larissa 2025-12-21: sunrise %s, sunset %s (EET). Moment %s EET = %s UTC: altitude %.2f deg (apparent), azimuth %.1f deg",
                loc(t_rise), loc(t_set), loc(t0), format(t0, "%H:%M", tz = "UTC"), s0$alt, s0$az))

# ---- 2. shadows ----------------------------------------------------------------------------------
dem <- m30_dem(crop = NULL)
reg <- m30_region(TRUE)
z <- as.matrix(dem, wide = TRUE); z[is.na(z)] <- 0
res <- 90; alt <- s0$alt * pi / 180; az <- s0$az * pi / 180
dcol <- sin(az); drow <- -cos(az)                                     # towards the sun, in matrix rows/cols
nr <- nrow(z); nc <- ncol(z)
horizon <- matrix(-Inf, nr, nc)
for (k in 1:round(30000 / res)) {
  d <- k * res; ro <- round(k * drow); co <- round(k * dcol)
  rs <- max(1, 1 - ro):min(nr, nr - ro); cs <- max(1, 1 - co):min(nc, nc - co)
  drop <- d * tan(alt) + d^2 / (2 * 6371000) * (1 - 1/7)
  sh <- matrix(-Inf, nr, nc); sh[rs, cs] <- z[rs + ro, cs + co] - drop
  horizon <- pmax(horizon, sh)
}
cast <- dem; values(cast) <- as.vector(t(horizon > z))
sl <- terrain(dem, "slope", unit = "radians"); asp <- terrain(dem, "aspect", unit = "radians")
cosi <- cos(sl) * sin(alt) + sin(sl) * cos(alt) * cos(az - asp)
self <- cosi <= 0
dark <- (cast | self)
land <- mask(rasterize(vect(reg), dem), dem > 0, maskvalues = FALSE)
n  <- global(land, "sum", na.rm = TRUE)[1, 1]
f_dark <- global(dark * land, "sum", na.rm = TRUE)[1, 1] / n
f_self <- global(self * land, "sum", na.rm = TRUE)[1, 1] / n
f_cast <- global((cast & !self) * land, "sum", na.rm = TRUE)[1, 1] / n
message(sprintf("Mainland land in shadow: %.1f%% (self-shadowed faces %.1f%%, cast shadow only %.1f%%), %.0f of %.0f km2",
                100 * f_dark, 100 * f_self, 100 * f_cast, f_dark * n * 0.0081, n * 0.0081))

# ---- 3. map layers -------------------------------------------------------------------------------
INK0 <- M30$night; WARM <- "#F2A65A"
bb <- st_bbox(st_buffer(reg, 3000))
win <- ext(bb[c(1, 3, 2, 4)])
lum <- ifel(dark, 0, cosi) |> crop(win)
lum <- mask(lum, crop(dem, win) > 0, maskvalues = FALSE)               # sea stays background
inr <- rasterize(vect(reg), lum)
ldf <- c(lum, inr) |> setNames(c("lum", "inreg")) |> as.data.frame(xy = TRUE) |> filter(!is.na(lum)) |>
  mutate(inreg = !is.na(inreg))
sunpal <- c("#120E0C", "#3B2416", "#7A4520", "#C26E2E", "#F2A65A", "#FFE0A6")

wgs <- function(lon, lat) st_sfc(st_point(c(lon, lat)), crs = 4326) |> st_transform(CRS_GR) |> st_coordinates()
mtn <- tribble(~lab, ~lon, ~lat,
  "OLYMPUS", 22.3586, 40.0856, "OSSA", 22.685, 39.796, "PELION", 23.046, 39.438, "PINDUS", 21.201, 39.527) |>
  rowwise() |> mutate(x = wgs(lon, lat)[1], y = wgs(lon, lat)[2]) |> ungroup() |>
  mutate(x = x + c(-9000, 9000, 9000, 6000), y = y + c(-4000, 4500, 6000, 17000))
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2])

# sun arrow in the south-west corner, pointing the way the light travels
ax <- bb["xmin"] + 22000; ay <- bb["ymin"] + 20000; L <- 16000
sun_arrow <- list(
  annotate("segment", x = ax, y = ay, xend = ax - L * sin(az), yend = ay - L * cos(az),
           colour = WARM, linewidth = .7, arrow = arrow(length = unit(6, "pt"), type = "closed")),
  annotate("point", x = ax, y = ay, colour = WARM, size = 4.2),
  annotate("point", x = ax, y = ay, colour = "#FFE0A6", size = 2),
  annotate("text", x = ax, y = ay - 5500, label = sprintf("sun %.1f° above horizon\nazimuth %.0f° (south-west)", s0$alt, s0$az),
           family = "Fira Sans Condensed", size = 3, colour = M30$night_ink, lineheight = .95, vjust = 1))

# ---- 4. strip: the sun's height through the day, in map coordinates -----------------------------
W <- bb["xmax"] - bb["xmin"]
dd <- sun |> filter(t >= t_rise, t <= t_set) |>
  mutate(fx = as.numeric(t - t_rise) / as.numeric(t_set - t_rise, units = "secs") * W + bb["xmin"],
         fy = bb["ymin"] - 40000 + alt * 900)
mk <- dd |> filter(t == t0)
ticks <- tibble(t = seq(as.POSIXct("2025-12-21 07:00", tz = "UTC"), by = "2 hours", length.out = 6)) |>  # 09..19 EET
  mutate(t = t + 0) |> filter(t >= t_rise, t <= t_set) |>
  mutate(fx = as.numeric(t - t_rise) / as.numeric(t_set - t_rise, units = "secs") * W + bb["xmin"])
ybase <- bb["ymin"] - 40000
strip <- list(
  annotate("text", x = bb["xmin"], y = bb["ymin"] - 5000, hjust = 0, vjust = 1, family = "Oswald", size = 4.3,
           colour = M30$night_ink, label = "The sun's height over Larissa, 21 December 2025"),
  annotate("segment", x = bb["xmin"], xend = bb["xmax"], y = ybase, yend = ybase, colour = M30$night_mute, linewidth = .25),
  geom_ribbon(data = dd, aes(fx, ymin = ybase, ymax = fy), fill = WARM, alpha = .10),
  geom_line(data = filter(dd, t <= t0), aes(fx, fy), colour = WARM, linewidth = .8),
  geom_line(data = filter(dd, t >= t0), aes(fx, fy), colour = M30$night_mute, linewidth = .5, linetype = "22"),
  geom_point(data = mk, aes(fx, fy), colour = "#FFE0A6", size = 2.6),
  geom_text(data = mk, aes(fx, fy + 3500, label = sprintf("%s · %.1f° · this map", loc(t0), alt)), hjust = 0.6,
            vjust = 0, family = "Fira Sans Condensed", fontface = "bold", size = 3.2, colour = "#FFE0A6"),
  annotate("text", x = bb["xmin"], y = ybase - 2500, label = paste("sunrise", loc(t_rise)), hjust = 0, vjust = 1,
           family = "Fira Sans Condensed", size = 3, colour = M30$night_mute),
  annotate("text", x = bb["xmax"], y = ybase - 2500, label = paste("sunset", loc(t_set)), hjust = 1, vjust = 1,
           family = "Fira Sans Condensed", size = 3, colour = M30$night_mute),
  annotate("text", x = dd$fx[which.max(dd$alt)], y = max(dd$fy) - 3000,
           label = sprintf("highest at %s: %.1f°", loc(dd$t[which.max(dd$alt)]), max(dd$alt)), vjust = 1, family = "Fira Sans Condensed", size = 3,
           colour = M30$night_mute))

# ---- 5. plot -------------------------------------------------------------------------------------
p <- ggplot() +
  geom_raster(data = filter(ldf, !inreg), aes(x, y, fill = lum), alpha = .38) +
  geom_raster(data = filter(ldf, inreg), aes(x, y, fill = lum)) +
  scale_fill_gradientn(colours = sunpal, values = c(0, .02, .2, .45, .75, 1), limits = c(0, 1), guide = "none") +
  geom_sf(data = reg, fill = NA, colour = alpha(M30$night_ink, .55), linewidth = .3) +
  geom_point(data = towns, aes(x, y), colour = M30$night_ink, size = 1.4) +
  geom_shadowtext(data = towns, aes(x, y - 4000, label = name), family = "Fira Sans Condensed", size = 3.3,
                  colour = M30$night_ink, bg.colour = INK0, bg.r = .15) +
  geom_shadowtext(data = mtn, aes(x, y, label = lab), family = "Fira Sans Condensed", size = 3, colour = WARM,
                  bg.colour = INK0, bg.r = .15) +
  sun_arrow + strip +
  coord_sf(crs = CRS_GR, xlim = bb[c(1, 3)], ylim = c(ybase - 9000, bb["ymax"]), expand = FALSE, clip = "off") +
  theme_m30(dark = TRUE) +
  theme(plot.title = element_markdown(margin = margin(26, 0, 14, 0)),
        plot.subtitle = element_textbox_simple(margin = margin(0, 0, 20, 0))) +
  m30_labs(
    17, "Light & dark",
    title = sprintf("Shortest day, one hour before sunset:<br>%.0f%% of Thessaly already lies in shadow", 100 * f_dark),
    subtitle = sprintf(paste0(
      "The relief lit by the real sun of the winter solstice, 21 December 2025 at %s Greek time, one hour before sunset ",
      "at Larissa. The sun stands just %.1f° above the south-west horizon: slopes facing away from it (%.0f%% of the land) ",
      "and ground behind ridges that block it (another %.0f%%) are dark. Brighter means the slope faces the sun more squarely."),
      loc(t0), s0$alt, 100 * f_self, 100 * f_cast),
    source = "Copernicus GLO-90 DEM (ESA, 2021) · sun position from the NOAA Solar Calculator formulas · Eurostat NUTS 2021",
    accent = WARM,
    extra = "shadow = faces turned from the sun + cast shadows traced 30 km towards the sun on the 90 m grid, earth curvature included")
m30_save(p, 17, "light_dark", w = 8, h = 10, bg = INK0)
