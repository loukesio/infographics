# Rebuild every chart into out/.  Run from the project root:  Rscript run_all.R
# Scripts that need things you may not have yet are skipped with a message:
#   t7_thessaly_drought.R   needs internet on first run (downloads ERA5 via Open-Meteo, cached afterwards)
#   x1_europe_acled_map.R   needs data/acled_europe.csv (manual ACLED download, see CLAUDE.md)
Sys.setlocale("LC_ALL", "en_US.UTF-8")      # Greek letters and ₂ / – in titles need UTF-8

scripts <- c(
  # Greece / Thessaly / Larissa
  "scripts/t4_greek_parliament.R",
  "scripts/t5_larissa_bellwether.R",
  "scripts/t6_larissa_mayor.R",
  "scripts/t8_larissa_mayors_history.R",
  "scripts/t10_larissa_mayors_1881.R",
  "scripts/t11_mayor_professions_radar.R",
  "scripts/t1_storm_daniel.R",
  "scripts/t7_thessaly_drought.R",
  # global data-journalism set
  "scripts/p1_carbon_majors.R",
  "scripts/p2_ai_datacenters.R",
  "scripts/p2b_ai_fan.R",
  "scripts/p3_redistribution.R",
  "scripts/p4_incarceration.R",
  "scripts/p5_plant_extinction.R",
  "scripts/t9_music_flavors.R",
  "scripts/x1_europe_acled_map.R"
)

skip <- c("scripts/x1_europe_acled_map.R" = !file.exists("data/acled_europe.csv"))

res <- lapply(scripts, function(s) {
  if (isTRUE(skip[s])) { message("SKIP  ", s, " (missing input, see CLAUDE.md)"); return("skipped") }
  message("RUN   ", s)
  ok <- tryCatch({ source(s, local = new.env()); "ok" },
                 error = function(e) { message("  ERROR: ", conditionMessage(e)); "error" })
  ok
})
print(table(unlist(res)))
