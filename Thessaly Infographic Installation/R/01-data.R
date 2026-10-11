# ── Every dataset, one object per figure. Nothing inline in a fig_*(). ──────
# Naming: d_<slug> matches fig_<slug>().
library(jsonlite)

# Panel 03 — Greece's highest summits (sourced: Ελληνική Ορειβατική Ομοσπονδία)
d_peaks <- tribble(
  ~name,       ~region,                ~m,   ~thess,
  "Όλυμπος",   "Θεσσαλία / Μακεδονία", 2917, TRUE,
  "Σμόλικας",  "Ήπειρος",              2637, FALSE,
  "Βόρας",     "Μακεδονία",            2524, FALSE,
  "Γράμμος",   "Ήπειρος",              2520, FALSE,
  "Γκιώνα",    "Στερεά Ελλάδα",        2510, FALSE,
  "Τύμφη",     "Ήπειρος",              2497, FALSE,
  "Παρνασσός", "Στερεά Ελλάδα",        2457, FALSE,
  "Τζουμέρκα", "Ήπειρος",              2429, FALSE,
  "Άγραφα",    "Θεσσαλία",             2184, TRUE,
  "Όσσα",      "Θεσσαλία",             1978, TRUE,
  "Κοζιάκας",  "Θεσσαλία",             1901, TRUE,
  "Πήλιο",     "Θεσσαλία",             1624, TRUE
)

# Panel 06 — Pineios long profile (approximate; Britannica, WWF basin study)
d_river <- tibble(
  km = c(0,12,24,38,50,60,72,85,100,120,140,160,178,192,205),
  m  = c(1100,880,620,400,300,240,170,115,95,74,62,50,30,12,0)
)
d_river_marks <- tibble(
  km  = c(0, 60, 85, 120, 178, 205),
  m   = c(1100, 240, 115, 74, 30, 0),
  lab = c("ΠΗΓΕΣ · Πίνδος","ΚΑΛΑΜΠΑΚΑ · Μετέωρα","ΤΡΙΚΑΛΑ","ΛΑΡΙΣΑ","ΤΕΜΠΗ","ΣΤΟΜΙΟ · Αιγαίο")
)

# Panel 07 — Lake Karla surface area, km²
d_karla <- tibble(
  year = c(1950,1961,1962,1963,1964,1965,1990,2009,2010,2012,2015,2018,2022,
           2023.6,2023.7,2023.95,2024.3,2025),
  km2  = c(180,180,180,95,30,2,0,0,8,18,26,38,38,38,180,150,55,42)
)

# Panel 13 — population of Thessaly
# TODO(HANDOFF §3.5): pre-2011 values are approximate. Replace with the exact
# ΕΛΣΤΑΤ census series before printing.
d_pop <- tibble(
  year   = c(1951,1961,1971,1981,1991,2001,2011,2021),
  n      = c(606000,694000,660000,695000,734000,754000,732762,688255),
  approx = c(rep(TRUE, 6), FALSE, FALSE)
)

# Panel 14 — transhumance: flock altitude through the year (schematic)
d_trans <- tibble(
  month = 1:12,
  m     = c(110,110,120,320,1150,1500,1550,1550,1350,520,140,110)
)

# Panel 17 — temperature. Read from the shared JSON so R and the HTML panels
# can never disagree about what has and has not been sourced.
.clim   <- fromJSON("data/climate.json", simplifyVector = TRUE)
CLIM_PROVISIONAL <- identical(.clim$status, "provisional")
d_temp <- tibble(
  year     = as.integer(.clim$series$years),
  thessaly = as.numeric(.clim$series$thessaly),
  larissa  = as.numeric(.clim$series$larissa)
)
# Long form for plotting. Built with base R on purpose: one fewer dependency
# for whoever runs the documented quick start on a clean machine.
d_temp_long <- tibble(
  year   = rep(d_temp$year, 2L),
  series = rep(c("thessaly", "larissa"), each = nrow(d_temp)),
  t      = c(d_temp$thessaly, d_temp$larissa)
)

if (CLIM_PROVISIONAL)
  message("NOTE: data/climate.json is provisional — fig_temptime() will stamp itself. See HANDOFF.md §3.1")

# Panel 17 (candidate) — hot days at Larisa. Daily ERA5-Land grid cell, written
# by R/fetch-openmeteo.R. Counts of days with Tmax >= 35 °C and >= 40 °C per year.
.heat_f <- "data/larissa_daily_era5land.csv"
if (file.exists(.heat_f)) {
  .lar <- read.csv(.heat_f)
  .lar$year <- as.integer(substr(.lar$date, 1, 4))
  d_heat <- tibble(
    year = sort(unique(.lar$year)),
    d35  = as.integer(tapply(.lar$tmax >= 35, .lar$year, sum)),
    d40  = as.integer(tapply(.lar$tmax >= 40, .lar$year, sum))
  )
  d_heat_long <- tibble(
    year = rep(d_heat$year, 2L),
    thr  = rep(c("35", "40"), each = nrow(d_heat)),
    n    = c(d_heat$d35, d_heat$d40)
  )
} else {
  d_heat <- NULL
  message("NOTE: ", .heat_f, " missing — run R/fetch-openmeteo.R; fig_heatdays() will be skipped.")
}
