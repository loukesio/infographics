# Day 09 · Urban-rural — "Half of Thessaly lives on 1% of its land"
# Every populated 400 m hexagon of Thessaly coloured by the EU/UN Degree of Urbanisation of the 1 km cell it sits in,
# plus a paired bar: share of people vs share of land in cities, towns and rural areas.
#
# Data   : GHSL GHS-SMOD R2023A, epoch 2020, 1 km Mollweide (European Commission JRC, CC BY 4.0) — the
#          Degree of Urbanisation stage-I grid: 30 urban centre, 23/22/21 dense / semi-dense urban cluster / suburban,
#          13/12/11 rural cluster / low / very low density rural, 10 water.
#          https://ghsl.jrc.ec.europa.eu/download.php?ds=smod  (file GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip)
#          Kontur Population Greece 2023-11-01, 400 m H3 hexagons (HDX, CC BY 4.0)
#          https://data.humdata.org/dataset/kontur-population-greece
#          Region border: Eurostat GISCO NUTS 2021 EL61, mainland (via m30_base.R)
# Method : each Kontur hexagon takes the SMOD class of the 1 km cell under its centre. People = sum of hexagon
#          population per class. Land = number of 1 km SMOD cells (centre inside the region) per class, water excluded.
#          Classes grouped as the EU does: City = 30, Towns & suburbs = 21–23, Rural = 11–13.
# Caveats: SMOD is modelled from GHS-POP 2020 + built-up, Kontur is 2023; the two grids do not line up exactly.
#          67 people fall in SMOD water cells and are counted as rural. Sporades excluded.

source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext) })
DIR <- file.path(M30_CACHE, "day09"); dir.create(DIR, showWarnings = FALSE)

# ---- 1. data ----
tif <- file.path(DIR, "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.tif")
if (!file.exists(tif)) {
  z <- file.path(DIR, "smod.zip")
  download.file(paste0("https://jeodpp.jrc.ec.europa.eu/ftp/jrc-opendata/GHSL/GHS_SMOD_GLOBE_R2023A/",
                       "GHS_SMOD_E2020_GLOBE_R2023A_54009_1000/V2-0/GHS_SMOD_E2020_GLOBE_R2023A_54009_1000_V2_0.zip"),
                z, mode = "wb", quiet = TRUE)
  unzip(z, exdir = DIR)
}
smod <- rast(tif)
reg  <- m30_region(TRUE)
regm <- st_transform(reg, crs(smod))
cells <- mask(crop(smod, vect(st_buffer(regm, 3000))), vect(regm))

grp <- function(v) case_when(v == 30 ~ "City", v %in% 21:23 ~ "Towns & suburbs", v %in% 10:13 ~ "Rural")
lv  <- c("City", "Towns & suburbs", "Rural")

pop <- read_sf("data/kontur/kontur_population_GR_20231101.gpkg") |> st_transform(CRS_GR)
cen <- suppressWarnings(st_centroid(pop))
inr <- lengths(st_intersects(cen, reg)) > 0
pop <- pop[inr, ]; cen <- cen[inr, ]
pop$smod  <- terra::extract(smod, vect(st_transform(cen, crs(smod))))[, 2]
pop$class <- factor(grp(pop$smod), lv)

# ---- 2. shares ----
land <- tibble(v = values(cells, na.rm = TRUE)[, 1]) |> filter(v != 10) |>
  count(class = factor(grp(v), lv), name = "km2")
people <- pop |> st_drop_geometry() |> group_by(class) |> summarise(people = sum(population))
sh <- full_join(people, land, by = "class") |>
  mutate(p_sh = people / sum(people), l_sh = km2 / sum(km2))
print(sh)
urb <- sh |> filter(class != "Rural") |> summarise(p = sum(p_sh), l = sum(l_sh))
message(sprintf("FINDING: cities + towns hold %.1f%% of people on %.2f%% of the land (%d of %d km2); %s people total",
                100 * urb$p, 100 * urb$l, sum(sh$km2[1:2]), sum(sh$km2), format(sum(sh$people), big.mark = ",")))
write.csv(sh, "30daymap/data/day09_urban_rural_shares.csv", row.names = FALSE)

# ---- 3. map ----
ACC  <- "#1D4E89"                                   # city
COL  <- c(City = ACC, `Towns & suburbs` = "#79A7D3", Rural = "#E4DAC4")
bb   <- st_bbox(reg)
towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Elassona", "Farsala")) |>
  mutate(x = st_coordinates(geometry)[, 1], y = st_coordinates(geometry)[, 2],
         nx = x + c(9000, 9000, -9000, -9000, 0, 0), ny = y + c(6000, -9000, 6000, -7500, 8000, -7000),
         hj = c(0, 0, 1, 1, 0.5, 0.5))

pm <- ggplot() +
  geom_sf(data = reg, fill = "#FAF8F3", colour = M30$mute, linewidth = 0.25) +
  geom_sf(data = filter(pop, class == "Rural"), fill = COL["Rural"], colour = NA) +
  geom_sf(data = filter(pop, class != "Rural"), aes(fill = class), colour = NA) +
  scale_fill_manual(values = COL, guide = "none") +
  geom_segment(data = towns, aes(x, y, xend = nx, yend = ny * 0 + ny - sign(ny - y) * 1500),
               colour = M30$soft, linewidth = 0.25) +
  geom_shadowtext(data = towns, aes(nx, ny, label = name, hjust = hj), family = "Fira Sans Condensed",
                  size = 3.3, colour = M30$ink, bg.colour = "white", bg.r = 0.12) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, datum = NA, expand = FALSE,
           xlim = c(bb["xmin"] - 3000, bb["xmax"] + 3000), ylim = c(bb["ymin"] - 3000, bb["ymax"] + 3000))

# ---- 4. paired bar: people vs land, ribbons between ----
bars <- sh |> select(class, people = p_sh, land = l_sh) |>
  pivot_longer(c(people, land), names_to = "what", values_to = "share") |>
  mutate(what = factor(what, c("people", "land"))) |> arrange(what, class) |>
  group_by(what) |> mutate(xmax = cumsum(share), xmin = xmax - share) |> ungroup() |>
  mutate(y = ifelse(what == "people", 1, 0), h = 0.16)
rib <- bars |> select(class, what, xmin, xmax, y, h) |>
  pivot_wider(names_from = what, values_from = c(xmin, xmax, y)) |>
  rowwise() |> mutate(poly = list(tibble(
    x = c(xmin_people, xmax_people, xmax_land, xmin_land),
    y = c(y_people - h, y_people - h, y_land + h, y_land + h)))) |>
  ungroup() |> select(class, poly) |> unnest(poly)
lab <- bars |> mutate(
  txt = ifelse(share < 0.01, sprintf("%.1f%% %s", 100 * share, tolower(sub(" &.*", "", class))), sprintf("%d%%", round(100 * share))),
  big = share > 0.06,
  lx = ifelse(big, (xmin + xmax) / 2, xmax + 0.006),
  ly = ifelse(big, y, y + 0.27), col = ifelse(class == "Rural" | !big, M30$ink, "white"))
lab <- filter(lab, !(what == "land" & !big))
small <- filter(sh, class != "Rural")
small_txt <- sprintf("cities %.1f%%  ·  towns & suburbs %.1f%%", 100 * small$l_sh[1], 100 * small$l_sh[2])

pb <- ggplot() +
  geom_polygon(data = rib, aes(x, y, group = class, fill = class), alpha = 0.28) +
  geom_rect(data = bars, aes(xmin = xmin, xmax = xmax, ymin = y - h, ymax = y + h, fill = class), colour = "white",
            linewidth = 0.4) +
  geom_text(data = lab, aes(lx, ly, label = txt, colour = I(col), hjust = ifelse(big, 0.5, 0)),
            family = "Oswald", size = 4.6) +
  annotate("segment", x = 0.004, xend = 0.02, y = -0.17, yend = -0.29, colour = M30$soft, linewidth = 0.25) +
  annotate("text", x = 0.026, y = -0.3, label = small_txt, hjust = 0, family = "Fira Sans Condensed",
           size = 3.4, colour = M30$ink) +
  annotate("text", x = -0.012, y = c(1, 0), label = c("PEOPLE", "LAND"), hjust = 1, family = "Oswald",
           size = 4.2, colour = M30$ink) +
  annotate("text", x = -0.012, y = c(0.86, -0.14),
           label = c(sprintf("%s residents", format(round(sum(sh$people), -3), big.mark = ",")),
                     sprintf("%s km²", format(sum(sh$km2), big.mark = ","))),
           hjust = 1, family = "Fira Sans Condensed", size = 3, colour = M30$soft) +
  # class key along the top bar
  geom_text(data = filter(bars, what == "people"), aes((xmin + xmax) / 2, 1.3, label = class, colour = class),
            family = "Fira Sans Condensed", fontface = "bold", size = 3.5) +
  scale_fill_manual(values = COL, guide = "none") +
  scale_colour_manual(values = c(COL[1:2], Rural = "#A08D66"), guide = "none") +
  scale_x_continuous(limits = c(-0.16, 1.01), expand = c(0, 0)) +
  scale_y_continuous(limits = c(-0.42, 1.42), expand = c(0, 0)) +
  theme_void()

L <- m30_labs(9, "Urban-rural",
    title = sprintf("Half of Thessaly lives on %s of its land", ifelse(round(100 * urb$l) <= 1, "1%",
                                                                       sprintf("%d%%", round(100 * urb$l)))),
    subtitle = sprintf(paste0(
      "Each hexagon is 400 m wide and has at least one resident. Its colour is the EU Degree of Urbanisation of the ",
      "1 km cell beneath it: <b style='color:%s'>city</b>, <b style='color:%s'>town or suburb</b> or ",
      "<b style='color:#A08D66'>rural</b>. Cities and towns hold %.0f%% of the people on %.1f%% of the land."),
      ACC, "#5E8FC0", 100 * urb$p, 100 * urb$l),
    source = paste("GHSL GHS-SMOD R2023A epoch 2020 (European Commission, JRC) · Kontur Population 2023, 400 m H3",
                   "hexagons (HDX, CC BY) · Eurostat GISCO NUTS 2021, mainland Thessaly"),
    accent = ACC)
cap <- L$caption; L$caption <- NULL
p <- (pm + L + theme_m30()) / (pb + labs(caption = cap) + theme_m30() + theme(plot.margin = margin(0, 36, 22, 36))) +
  plot_layout(heights = c(3.1, 1))
m30_save(p, 9, "urban_rural", 8, 10)
