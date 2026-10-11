# Escalating drought in Thessaly — small multiples, years x regional units
# Style after Scientific American's "Escalating Drought" (Nov 2021)
#
# Data: ERA5 reanalysis via the free Open-Meteo archive API (no key needed)
#   daily precipitation + FAO reference evapotranspiration, 1981–today, on a 0.25° grid over Thessaly
# Drought index: a simple non-parametric SPEI-3 (3-month water balance P − ET0, ranked against
#   the same calendar month in all years and turned into a z-score). Categories follow the
#   US Drought Monitor style: D0 abnormally dry … D4 exceptional.
#
# Run locally (needs internet). First run downloads ~40 grid points and caches them in data/era5_thessaly.rds

library(tidyverse)
library(jsonlite)
library(ggtext)

start <- "1981-01-01"
end   <- as.character(Sys.Date() - 10)

# ---- 1. grid over Thessaly + regional unit of each point ---------------------------------
# approximate: each grid point is assigned to the nearest regional-unit capital
capitals <- tribble(
  ~unit,      ~clon, ~clat,
  "Larissa",  22.42, 39.64,
  "Magnesia", 22.94, 39.36,
  "Trikala",  21.77, 39.55,
  "Karditsa", 21.92, 39.36
)
grid <- expand_grid(lon = seq(21.25, 23.25, 0.25), lat = seq(39.0, 40.0, 0.25)) |>
  # keep land points inside a rough Thessaly outline (drop Aegean sea / Epirus / Macedonia corners)
  filter(!(lon >= 23.0 & lat <= 39.1), !(lon >= 23.1 & lat >= 39.5),
         !(lon <= 21.4 & lat >= 39.75), !(lat >= 40.0 & lon >= 22.6)) |>
  rowwise() |>
  mutate(unit = capitals$unit[which.min((capitals$clon - lon)^2 + (capitals$clat - lat)^2)]) |>
  ungroup()

# ---- 2. download (cached) ------------------------------------------------------------------
cache <- "data/era5_thessaly.rds"
if (!file.exists(cache)) {
  # one JSON per grid point, so a rate-limited run (HTTP 429 on the free tier) can resume
  dir.create("data/era5_drought", showWarnings = FALSE)
  get_point <- function(lon, lat) {
    f <- sprintf("data/era5_drought/p_%.2f_%.2f.json", lon, lat)
    if (!file.exists(f)) {
      url <- paste0("https://archive-api.open-meteo.com/v1/archive?latitude=", lat, "&longitude=", lon,
                    "&start_date=", start, "&end_date=", end,
                    "&daily=precipitation_sum,et0_fao_evapotranspiration&timezone=Europe%2FAthens")
      for (try in 1:10) {
        ok <- tryCatch({ download.file(url, f, quiet = TRUE); TRUE }, error = function(e) FALSE)
        if (ok && !grepl('"error"', readLines(f, n = 1, warn = FALSE))) break
        unlink(f); message("  retry ", try); Sys.sleep(45 * try)
      }
      if (!file.exists(f)) stop("Open-Meteo kept refusing ", f, " — rerun later, cache is kept")
      Sys.sleep(3)
    }
    out <- fromJSON(f)
    tibble(lon = lon, lat = lat, date = as.Date(out$daily$time),
           p = out$daily$precipitation_sum, et0 = out$daily$et0_fao_evapotranspiration)
  }
  raw <- map2(grid$lon, grid$lat, \(x, y) { message("point ", x, ", ", y); get_point(x, y) }) |> list_rbind()
  saveRDS(raw, cache)
}
raw <- readRDS(cache)

# ---- 3. drought index ---------------------------------------------------------------------
cats <- c("Abnormally dry", "Moderate drought", "Severe drought", "Extreme drought", "Exceptional drought")

spei <- raw |>
  mutate(month = floor_date(date, "month")) |>
  summarise(wb = sum(p - et0, na.rm = TRUE), .by = c(lon, lat, month)) |>
  arrange(lon, lat, month) |>
  group_by(lon, lat) |>
  mutate(wb3 = wb + lag(wb) + lag(wb, 2)) |>                  # 3-month water balance
  group_by(lon, lat, m = month(month)) |>
  mutate(z = qnorm((rank(wb3, na.last = "keep") - 0.44) / (sum(!is.na(wb3)) + 0.12))) |>  # Gringorten plotting position
  ungroup() |>
  filter(!is.na(z)) |>
  mutate(cat = cut(z, c(-Inf, -2, -1.6, -1.3, -0.8, -0.5, Inf),
                   labels = c(rev(cats), "none"), right = TRUE)) |>
  left_join(grid, by = c("lon", "lat")) |>
  filter(!is.na(unit))

# share of each unit's grid points in each category or worse (cumulative, like the US Drought Monitor)
share <- spei |>
  mutate(level = as.integer(factor(cat, levels = c("none", cats))) - 1) |>   # 0 = none … 5 = D4
  summarise(n = n(),
            d0 = mean(level >= 1), d1 = mean(level >= 2), d2 = mean(level >= 3),
            d3 = mean(level >= 4), d4 = mean(level >= 5),
            .by = c(unit, month)) |>
  pivot_longer(d0:d4, names_to = "lev", values_to = "pct") |>
  mutate(cat = factor(cats[as.integer(str_sub(lev, 2)) + 1], levels = cats),
         year = year(month), mo = month(month))

# ---- 4. plot -----------------------------------------------------------------------------
pal <- c("Abnormally dry" = "#F4C7A1", "Moderate drought" = "#EE8A5B", "Severe drought" = "#D7301F",
         "Extreme drought" = "#8E1D4B", "Exceptional drought" = "#3B0F2E")

share <- share |> mutate(unit = factor(unit, c("Trikala", "Karditsa", "Larissa", "Magnesia")))
worst <- share |> filter(cat == "Severe drought") |>
  summarise(pct = mean(pct), .by = year) |> slice_max(pct, n = 3)

p <- ggplot(share, aes(xmin = mo - 1, xmax = mo, ymin = 0, ymax = pct, fill = cat)) +
  annotate("rect", xmin = 0, xmax = 12, ymin = 0, ymax = 1, fill = "#EEF0F2") +
  geom_rect() +                                      # drawn in order D0 -> D4, so darker sits on top
  facet_grid(year ~ unit, switch = "y") +
  scale_fill_manual(values = pal, name = NULL) +
  scale_x_continuous(expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  guides(fill = guide_legend(nrow = 1, override.aes = list(colour = NA))) +
  labs(
    title = "Drought in Thessaly",   # change to your finding once you have seen the real data
    subtitle = glue::glue(
      "Share of each regional unit in drought, month by month since {year(min(share$month))}. ",
      "Each small panel is one year (January → December); the taller and darker the colour, the more land is in drought.<br>",
      "Driest years by area in severe drought or worse: <b>{paste(sort(worst$year), collapse = ', ')}</b>."),
    caption = "Drought index: 3-month standardised water balance (precipitation minus reference evapotranspiration, non-parametric SPEI-3) on a 0.25° grid,<br>points assigned to the nearest regional-unit capital. Data: ERA5 reanalysis (Copernicus/ECMWF) via Open-Meteo · Chart: Loukas Theodosiou · style after Scientific American"
  ) +
  theme_void(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    panel.spacing.x = unit(6, "pt"), panel.spacing.y = unit(2.5, "pt"),
    strip.text.x = element_text(family = "Oswald", size = 12, colour = "#1F2933", margin = margin(b = 4)),
    strip.text.y.left = element_text(size = 7.5, colour = "#495057", angle = 0, hjust = 1, margin = margin(r = 4)),
    legend.position = "top", legend.justification = "left",
    legend.text = element_text(size = 9, colour = "#495057"), legend.key.size = unit(10, "pt"),
    plot.title = element_text(family = "Playfair Display", face = "bold", size = 30, hjust = 0.5,
                              colour = "#1F2933", margin = margin(b = 6)),
    plot.subtitle = element_textbox_simple(size = 10.5, colour = "#495057", lineheight = 1.35,
                                           margin = margin(4, 0, 10, 0)),
    plot.caption = element_textbox_simple(size = 7.5, colour = "#ADB5BD", lineheight = 1.3,
                                          margin = margin(t = 10)),
    plot.margin = margin(24, 24, 14, 24)
  )

ggsave("out/t7_thessaly_drought.png", p, width = 8, height = 13, dpi = 220, device = ragg::agg_png)
