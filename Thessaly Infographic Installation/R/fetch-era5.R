# ── Fetch the real temperature series and write data/climate.json ───────────
# Replaces the provisional model behind panel 17. See HANDOFF.md §3.1.
#
# Needs a free Copernicus CDS account and ~/.cdsapirc. The R package ecmwfr
# wraps the same API:
#   install.packages("ecmwfr"); ecmwfr::wf_set_key(user = "<uid>", key = "<key>")

library(ecmwfr); library(terra); library(dplyr); library(jsonlite); library(glue)

THESSALY_BBOX <- c(40.2, 21.1, 38.9, 23.4)   # N, W, S, E
LARISSA       <- c(lon = 22.4191, lat = 39.6390)
YEARS         <- 1960:2024

request <- list(
  dataset_short_name = "reanalysis-era5-land-monthly-means",
  product_type = "monthly_averaged_reanalysis",
  variable     = "2m_temperature",
  year         = as.character(YEARS),
  month        = sprintf("%02d", 1:12),
  time         = "00:00",
  area         = THESSALY_BBOX,
  format       = "netcdf",
  target       = "era5_thessaly.nc"
)
# nc <- wf_request(request, user = "<uid>", path = "R/cache", time_out = 7200)

summarise_annual <- function(nc_path) {
  r <- rast(nc_path) - 273.15                      # K -> °C
  yr <- as.integer(format(time(r), "%Y"))
  regional <- tapply(global(r, "mean", na.rm = TRUE)[, 1], yr, mean)
  cell <- extract(r, matrix(LARISSA, ncol = 2))[-1] |> as.numeric()
  larissa <- tapply(cell, yr, mean)
  tibble(year = as.integer(names(regional)),
         thessaly = round(as.numeric(regional), 2),
         larissa  = round(as.numeric(larissa), 2))
}

write_climate_json <- function(d, source_label) {
  j <- fromJSON("data/climate.json", simplifyVector = FALSE)
  j$status <- "observed"                            # clears the stamp on both
  j$series <- list(
    `_source`    = source_label,
    `_retrieved` = format(Sys.Date()),
    years        = d$year, thessaly = d$thessaly, larissa = d$larissa
  )
  write_json(j, "data/climate.json", auto_unbox = TRUE, pretty = TRUE)
  message(glue("data/climate.json updated with {nrow(d)} years — stamp cleared."))
}

# d <- summarise_annual("R/cache/era5_thessaly.nc")
# stopifnot(nrow(d) > 50, diff(range(d$thessaly)) < 5)   # sanity: no unit slip
# write_climate_json(d, "ERA5-Land monthly means, annual mean of 2m temperature")
