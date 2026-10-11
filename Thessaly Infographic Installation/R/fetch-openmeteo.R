# ── Fetch the real temperature series (ERA5-Land via Open-Meteo) ────────────
# Replaces the provisional model behind panel 17. See HANDOFF.md §3.1.
# Open-Meteo's archive API serves the Copernicus ERA5-Land reanalysis (0.1°)
# without an account. Same data as fetch-era5.R, different door.
#   https://open-meteo.com/en/docs/historical-weather-api
suppressMessages({ library(sf); library(dplyr); library(jsonlite); library(glue) })

LARISSA <- c(lon = 22.4191, lat = 39.6390)
Y0 <- 1960; Y1 <- 2024
dir.create("R/cache", showWarnings = FALSE)

# 1 · Thessaly polygon (NUTS-2 EL61, GISCO) -> regular 0.2° grid of land points
nuts_f <- "R/cache/nuts2_2021.geojson"
if (!file.exists(nuts_f)) download.file(paste0(
  "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/",
  "NUTS_RG_01M_2021_4326_LEVL_2.geojson"), nuts_f, quiet = TRUE)
thess <- read_sf(nuts_f) |> filter(NUTS_ID == "EL61")
grid  <- st_make_grid(thess, cellsize = 0.2, what = "centers") |> st_as_sf()
grid  <- grid[st_intersects(grid, thess, sparse = FALSE)[, 1], ]
pts   <- st_coordinates(grid) |> as.data.frame() |> setNames(c("lon", "lat"))
message(glue("{nrow(pts)} grid points inside Thessaly"))

# 2 · daily ERA5-Land for one point, cached
fetch_point <- function(lon, lat, tag,
                        vars = "temperature_2m_mean,temperature_2m_max,temperature_2m_min") {
  f <- glue("R/cache/om_{tag}.json")
  if (!file.exists(f)) {
    url <- glue("https://archive-api.open-meteo.com/v1/archive?latitude={lat}&longitude={lon}",
                "&start_date={Y0}-01-01&end_date={Y1}-12-31&daily={vars}",
                "&models=era5_land&timezone=Europe%2FAthens")
    # The free tier rate-limits (HTTP 429) on long daily series: back off and retry.
    for (i in 1:10) {
      ok <- tryCatch({ download.file(url, f, quiet = TRUE); TRUE }, error = function(e) FALSE)
      if (ok && !grepl('"error"', readLines(f, n = 1, warn = FALSE))) break
      unlink(f); message("    retry ", i, " for ", tag); Sys.sleep(45 * i)
    }
    if (!file.exists(f)) stop("Open-Meteo kept refusing ", tag, " — rerun later; cache is kept.")
    Sys.sleep(3)
  }
  j <- fromJSON(f)
  tibble(date = as.Date(j$daily$time), tmean = j$daily$temperature_2m_mean,
         tmax = j$daily$temperature_2m_max %||% NA_real_, tmin = j$daily$temperature_2m_min %||% NA_real_,
         elev = j$elevation)
}

lar <- fetch_point(LARISSA["lon"], LARISSA["lat"], "larissa")
reg <- lapply(seq_len(nrow(pts)), function(i) {
  if (i %% 10 == 0) message("  point ", i)
  fetch_point(pts$lon[i], pts$lat[i], sprintf("p%02d", i), vars = "temperature_2m_mean") |> mutate(id = i)
}) |> bind_rows()

# 3 · annual means
ann_lar <- lar |> mutate(year = as.integer(format(date, "%Y"))) |>
  group_by(year) |> summarise(larissa = mean(tmean), .groups = "drop")
ann_reg <- reg |> mutate(year = as.integer(format(date, "%Y"))) |>
  group_by(id, year) |> summarise(t = mean(tmean), .groups = "drop") |>   # per point
  group_by(year) |> summarise(thessaly = mean(t), .groups = "drop")        # area mean
d <- inner_join(ann_reg, ann_lar, by = "year") |>
  mutate(across(c(thessaly, larissa), \(v) round(v, 2)))
stopifnot(nrow(d) == Y1 - Y0 + 1, !anyNA(d), diff(range(d$thessaly)) < 5)

# 4 · write climate.json (clears the stamp in both HTML and R)
j <- fromJSON("data/climate.json", simplifyVector = FALSE)
j$status <- "observed"
j$series <- list(
  `_source`    = "ERA5-Land (Copernicus/ECMWF) μέσω Open-Meteo, 1960–2024",
  `_method`    = glue("ERA5-Land (Copernicus/ECMWF) via Open-Meteo archive API; annual mean of daily 2 m temperature. ",
                      "Thessaly = mean of {nrow(pts)} grid points (0,2°) inside NUTS-2 EL61; Larissa = grid cell at 39,64 N 22,42 E"),
  `_retrieved` = format(Sys.Date()),
  years = d$year, thessaly = d$thessaly, larissa = d$larissa)
write_json(j, "data/climate.json", auto_unbox = TRUE, pretty = TRUE, digits = NA)

# 5 · keep the daily Larissa series for the heat-days figure
lar |> mutate(across(c(tmean, tmax, tmin), \(v) round(v, 1))) |> select(-elev) |>
  write.csv("data/larissa_daily_era5land.csv", row.names = FALSE)

message(glue("Done. {nrow(d)} years. Thessaly {d$thessaly[1]} -> {d$thessaly[nrow(d)]} °C; ",
             "Larissa {d$larissa[1]} -> {d$larissa[nrow(d)]} °C"))
