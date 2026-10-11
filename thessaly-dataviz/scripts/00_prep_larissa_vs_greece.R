# Rebuilds data/larissa_vs_greece.csv from the official Ministry of Interior results,
# as scraped by github.com/GrigorisLionis/Elektion-Data-Scraper (2019, May 2023, June 2023, 2024 EU)
# Checked against published figures: 2019 ND 39.85% nationally, 39.30% in Larissa.
library(tidyverse)

base <- "https://raw.githubusercontent.com/GrigorisLionis/Elektion-Data-Scraper/main/"
files <- c("votes2019.csv" = "2019", "votes2023.csv" = "May 2023",
           "votes2023J.csv" = "Jun 2023", "votes2024j.csv" = "2024 EU")

party_map <- c(nd = "ND", syriza = "SYRIZA", pasok = "PASOK", kke = "KKE",
               ellinikiLysi = "Greek Solution", mera25 = "MeRA25", pleusi = "Plefsi",
               niki = "Niki", spartiates = "Spartans", NA41 = "Golden Dawn")   # NA41 = Golden Dawn in 2019
special <- c("LEFKA", "AKYRA", "GRAMMENOI", "GRMAMMENOI", "EGYRA")           # blank/invalid/registered/valid

out <- imap(files, \(lab, f) {
  read_csv(paste0(base, f), col_names = c("date", "level", "name", "lvl2", "district", "party", "votes"),
           col_types = "cccccci") |>
    filter(level == "DISTRICT", !party %in% special) |>
    mutate(party = coalesce(party_map[party], "Others")) |>
    (\(d) bind_rows(
      d |> summarise(votes = sum(votes, na.rm = TRUE), .by = party) |> mutate(area = "Greece"),
      d |> filter(name == "Λάρισας") |> summarise(votes = sum(votes, na.rm = TRUE), .by = party) |>
        mutate(area = "Larissa")
    ))() |>
    mutate(share = 100 * votes / sum(votes), .by = area) |>
    mutate(election = lab)
}) |> list_rbind()

out |> select(election, area, party, share) |> write_csv("data/larissa_vs_greece.csv")
