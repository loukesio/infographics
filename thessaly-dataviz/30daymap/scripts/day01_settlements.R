# Day 01 · Points — every settlement of Thessaly as a dot, coloured by its elevation
# #30DayMapChallenge 2026, Thessaly series.
#
# Data
#   * Settlements: OpenStreetMap, nodes with place = city / town / village / hamlet, Geofabrik Greece extract
#     of 2026-10-28 (https://download.geofabrik.de/europe/greece.html), ODbL. Read via m30_osm().
#   * Elevation: Copernicus GLO-90 DEM (https://registry.opendata.aws/copernicus-dem/), sampled at each node.
#   * Border: Eurostat GISCO NUTS 2021 (EL61), incl. the Sporades.
# Caveats
#   * OSM place tags are set by mappers: "village" vs "hamlet" is not an official class, and a few abandoned
#     villages may still be tagged. The count is not the ELSTAT list of local communities.
#   * Elevation is the 90 m DEM cell under the node (the node is usually the village square).
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork); library(shadowtext) })

hstore_en <- function(x) sub('.*"name:en"=>"([^"]*)".*', "\\1", ifelse(grepl('"name:en"=>', x), x, NA))

# ---- 1. data -------------------------------------------------------------------------------------
reg  <- m30_region(FALSE)
pl   <- m30_osm("points", "place IN ('city','town','village','hamlet')", clip = reg)
dem  <- m30_dem(crop = NULL)
pl$elev <- terra::extract(dem, vect(pl))$elev
pl <- pl |> filter(!is.na(elev)) |> mutate(elev = pmax(elev, 0),
  kind = factor(place, c("city", "town", "village", "hamlet")),
  name_en = hstore_en(other_tags))

n_all  <- nrow(pl)
sh500  <- mean(pl$elev > 500)
n500   <- sum(pl$elev > 500)
med    <- median(pl$elev)
hi     <- pl |> slice_max(elev, n = 1)
sh_vh  <- pl |> st_drop_geometry() |> filter(kind %in% c("village", "hamlet")) |> summarise(mean(elev > 500)) |> pull()
message(sprintf("%d settlements; %d (%.1f%%) above 500 m; median %.0f m; villages+hamlets above 500 m: %.1f%%; highest: %s %.0f m",
                n_all, n500, 100 * sh500, med, 100 * sh_vh, hi$name_en %||% hi$name, hi$elev))
ll <- st_coordinates(st_transform(pl, 4326))
write.csv(pl |> st_drop_geometry() |> transmute(osm_id, name, name_en, place, lon = round(ll[, 1], 5),
                                                lat = round(ll[, 2], 5), elev = round(elev)),
          "30daymap/data/day01_settlements.csv", row.names = FALSE)

# ---- 2. colours: one sequential ramp, plain = pale, mountain = dark ---------------------------------
brks <- c(0, 100, 250, 500, 750, 1000, Inf)
labs_b <- c("0–100", "100–250", "250–500", "500–750", "750–1,000", "> 1,000 m")
pal  <- c("#E9DFC9", "#D2BC8F", "#B9925A", "#8C5A2E", "#5C3418", "#2E1A0C")
names(pal) <- labs_b
pl <- pl |> mutate(band = cut(elev, brks, labs_b, include.lowest = TRUE, right = FALSE))
accent <- "#8C5A2E"

# faint relief under the dots (hillshade, light)
hs <- m30_hillshade(aggregate(m30_dem(crop = reg, buffer = 0), 3)) |> mask(vect(reg))
bb <- st_bbox(reg)

# towns to label: the four capitals + two mountain places from the data
lab_towns <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Kalambaka", "Elassona"))
xy <- st_coordinates(lab_towns); lab_towns <- lab_towns |> mutate(x = xy[, 1], y = xy[, 2])

# ---- 3. map --------------------------------------------------------------------------------------
map <- ggplot() +
  geom_spatraster(data = hs, aes(fill = after_stat(value)), maxcell = 2e6, show.legend = FALSE) +
  scale_fill_gradient(low = "#C4BDB0", high = "#FFFFFF", na.value = NA) +
  ggnewscale::new_scale_fill() +
  geom_sf(data = reg, fill = NA, colour = M30$mute, linewidth = .25) +
  geom_sf(data = arrange(pl, elev), aes(fill = band, size = kind), shape = 21, colour = "white", stroke = .18) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_size_manual(values = c(city = 3.4, town = 2.3, village = 1.55, hamlet = 1.05), guide = "none") +
  geom_shadowtext(data = lab_towns, aes(x, y, label = name), family = "Fira Sans Condensed", fontface = "bold",
                  size = 3.3, colour = M30$ink, bg.colour = "white", bg.r = .18, nudge_y = 4200) +
  m30_scalebar(20, bbox = bb) +
  coord_sf(crs = CRS_GR, expand = FALSE, clip = "off")

# ---- 4. strip: every settlement as a dot, stacked by elevation (a wrapped dot histogram) ----------
# 50 m bins, each bin 4 dots wide, so the stack height = settlements / 4
bw <- 50; wide <- 4
dd <- pl |> st_drop_geometry() |> mutate(bin0 = floor(elev / bw) * bw) |>
  arrange(bin0, elev) |> group_by(bin0) |>
  mutate(k = row_number() - 1, x = bin0 + (k %% wide + .5) * bw / wide, y = k %/% wide + 1) |> ungroup()
ymax <- max(dd$y)
strip <- ggplot(dd, aes(x, y, fill = band)) +
  annotate("rect", xmin = 500, xmax = 1400, ymin = 0.3, ymax = ymax + 1, fill = "#F7F2EA") +
  geom_point(shape = 21, colour = "white", stroke = .12, size = 1.75) +
  geom_segment(aes(x = 500, xend = 500, y = 0.3, yend = ymax + 1), colour = M30$ink, linewidth = .3) +
  annotate("text", x = 520, y = ymax, hjust = 0, vjust = 1, family = "Fira Sans Condensed", size = 3.6,
           colour = M30$ink, lineheight = .95,
           label = sprintf("%d settlements above 500 m\n= %d%% of all", n500, round(100 * sh500))) +
  annotate("text", x = 480, y = ymax, hjust = 1, vjust = 1, family = "Fira Sans Condensed", size = 3.6,
           colour = M30$soft, lineheight = .95,
           label = sprintf("%d on the plain\nand foothills", n_all - n500)) +
  scale_fill_manual(values = pal, guide = "none") +
  scale_x_continuous(breaks = seq(0, 1250, 250), labels = \(x) paste0(format(x, big.mark = ","), " m"),
                     limits = c(0, 1400), expand = expansion(add = c(0, 0))) +
  scale_y_continuous(expand = expansion(add = c(.6, .6))) +
  labs(x = NULL, y = NULL, title = "Every settlement, stacked by the height it sits at (blocks four dots wide, one per 50 m)") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.x = element_text(family = "Fira Sans Condensed", size = 9.5, colour = M30$soft, margin = margin(t = 4)),
        axis.line.x = element_line(colour = M30$mute, linewidth = .3),
        plot.title = element_text(family = "Fira Sans", face = "bold", size = 10.5, colour = M30$ink, margin = margin(b = 8)))

# ---- 5. assemble ---------------------------------------------------------------------------------
title <- if (abs(sh500 - 1/3) <= .04) "Nearly a third of Thessaly's<br>settlements sit above 500 m" else
  sprintf("%d%% of Thessaly's settlements<br>sit above 500 m", round(100 * sh500))
map <- map +
  m30_labs(1, "Points", title = title, accent = accent,
    subtitle = sprintf(paste0(
      "All %s cities, towns, villages and hamlets in OpenStreetMap, coloured by height. ",
      "Pale dots fill the Thessalian plain; dark ones climb into Pindos in the west, Olympus and Ossa in the north ",
      "and Pelion by Volos. Half of all settlements lie below %d m; the highest, the hamlet %s, is at %s m."),
      format(n_all, big.mark = ","), round(med), coalesce(hi$name_en, hi$name), format(round(hi$elev), big.mark = ","))) +
  labs(caption = NULL) + theme_m30() + theme(plot.margin = margin(30, 36, 6, 36))
strip <- strip + labs(caption = paste0(
    "<b>Data</b> OpenStreetMap contributors, place = city/town/village/hamlet (Geofabrik extract 28 Oct 2026, ODbL) · ",
    "elevation Copernicus GLO-90 DEM · border Eurostat GISCO NUTS 2021 &nbsp;·&nbsp; village/hamlet tags are set by ",
    "mappers, not an official list &nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2")) +
  theme(plot.caption = theme_m30()$plot.caption, plot.caption.position = "plot",
        plot.margin = margin(10, 36, 22, 36))
p <- (map / strip) + plot_layout(heights = c(2.6, 1))
m30_save(p, 1, "settlements", w = 8, h = 10)
