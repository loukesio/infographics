# Download GBIF occurrence records of globally threatened species (IUCN CR / EN / VU) in Thessaly.
# API: https://api.gbif.org/v1/occurrence/search  (parameter iucnRedListCategory, geometry = WKT)
# Writes data/gbif_thessaly_threatened.csv. Re-run to refresh.
suppressMessages({ library(dplyr); library(jsonlite); library(sf); library(purrr) })
bbox <- "POLYGON((21.1 38.9,24.4 38.9,24.4 40.25,21.1 40.25,21.1 38.9))"   # bbox incl. Sporades; clipped below
fetch <- function(cat) {
  out <- list(); off <- 0
  repeat {
    url <- paste0("https://api.gbif.org/v1/occurrence/search?hasCoordinate=true&hasGeospatialIssue=false",
                  "&iucnRedListCategory=", cat, "&geometry=", URLencode(bbox, reserved = TRUE),
                  "&limit=300&offset=", off)
    j <- fromJSON(url, flatten = TRUE)
    if (!length(j$results)) break
    out[[length(out) + 1]] <- j$results
    off <- off + 300
    if (j$endOfRecords) break
    Sys.sleep(0.5)
  }
  bind_rows(out)
}
cols <- c("key", "species", "scientificName", "kingdom", "phylum", "class", "order", "family",
          "iucnRedListCategory", "decimalLatitude", "decimalLongitude", "coordinateUncertaintyInMeters",
          "year", "month", "basisOfRecord", "datasetKey", "datasetName", "institutionCode")
raw <- map(c("CR", "EN", "VU"), \(c) { message(c); fetch(c) }) |> bind_rows()
raw <- raw[, intersect(cols, names(raw))]
# clip to the real Thessaly polygon (NUTS-2 EL61, incl. Sporades)
th <- read_sf("data/kontur/nuts2_2021.geojson") |> filter(NUTS_ID == "EL61")
pts <- st_as_sf(raw, coords = c("decimalLongitude", "decimalLatitude"), crs = 4326, remove = FALSE)
inside <- lengths(st_intersects(pts, th)) > 0
dat <- raw[inside, ] |> distinct(key, .keep_all = TRUE)
message(sprintf("%d records in bbox, %d inside Thessaly, %d species", nrow(raw), nrow(dat), n_distinct(dat$species)))
write.csv(dat, "data/gbif_thessaly_threatened.csv", row.names = FALSE)
print(count(dat, iucnRedListCategory, class, sort = TRUE), n = 30)
