# Larissa votes like Greece — ribbon bars, Greece vs Larissa per election
# Data: Ministry of Interior (ekloges.ypes.gr), scraped by GrigorisLionis/Elektion-Data-Scraper
library(tidyverse)
library(ggtext)

v <- read_csv("data/larissa_vs_greece.csv", show_col_types = FALSE)
elections <- c("2019", "May 2023", "Jun 2023", "2024 EU")

parties <- tribble(
  ~party,           ~col,      ~txt,
  "KKE",            "#B71C1C", "white",
  "SYRIZA",         "#D6336C", "white",
  "MeRA25",         "#E8590C", "white",
  "Plefsi",         "#9C36B5", "white",
  "PASOK",          "#2B8A3E", "white",
  "Others",         "#DEE2E6", "#495057",
  "ND",             "#1C4E9C", "white",
  "Niki",           "#868E96", "white",
  "Greek Solution", "#343A40", "white",
  "Spartans",       "#212529", "white",
  "Golden Dawn",    "#000000", "white"
)

# row positions: each election = Greece row + Larissa row, then a gap
rows <- expand_grid(election = elections, area = c("Greece", "Larissa")) |>
  mutate(e = match(election, elections),
         y = -(e - 1) * 3.0 - if_else(area == "Larissa", 1.15, 0))
bar_h <- 0.78

segs <- v |>
  left_join(parties, by = "party") |>
  left_join(rows, by = c("election", "area")) |>
  mutate(ord = match(party, parties$party)) |>
  arrange(e, area, ord) |>
  group_by(election, area) |>
  mutate(xmax = cumsum(share), xmin = lag(xmax, default = 0)) |>
  ungroup()

# ribbons only inside each election: Greece -> Larissa (the "mirror")
ribbons <- segs |>
  filter(area == "Greece") |>
  select(election, party, col, xmin, xmax, y) |>
  inner_join(segs |> filter(area == "Larissa") |> select(election, party, xmin, xmax, y),
             by = c("election", "party"), suffix = c("", "_l")) |>
  mutate(id = paste(election, party)) |>
  rowwise() |>
  reframe(id, col,
          x  = c(xmin, xmax, xmax_l, xmin_l),
          yy = c(y - bar_h / 2, y - bar_h / 2, y_l + bar_h / 2, y_l + bar_h / 2))

labs_df <- segs |>
  filter(share >= 5.5) |>
  mutate(lab = if_else(share >= 9, paste0(party, " ", round(share), "%"), paste0(round(share), "%")),
         lab = str_replace(lab, "Greek Solution", "Gr. Sol."))

# headline numbers: biggest gap between Larissa and Greece for the three big parties, national elections
gaps <- v |>
  filter(party %in% c("ND", "SYRIZA", "PASOK"), election != "2024 EU") |>
  pivot_wider(names_from = area, values_from = share) |>
  mutate(gap = abs(Larissa - Greece))
max_gap <- round(max(gaps$gap), 1)

ylab <- rows |> mutate(lab = if_else(area == "Greece",
                                     glue::glue("<span style='font-family:Oswald;font-size:13pt;color:#1F2933'>{election}</span><br><span style='color:#868E96'>Greece</span>"),
                                     "<b style='color:#1F2933'>Larissa</b>"))

p <- ggplot() +
  geom_polygon(data = ribbons, aes(x, yy, group = id, fill = I(col)), alpha = 0.25) +
  geom_rect(data = segs, aes(xmin = xmin, xmax = xmax, ymin = y - bar_h / 2, ymax = y + bar_h / 2,
                             fill = I(col)), colour = "white", linewidth = 0.3) +
  geom_text(data = labs_df, aes((xmin + xmax) / 2, y, label = lab, colour = I(txt)),
            family = "Fira Sans Condensed", fontface = "bold", size = 3) +
  geom_richtext(data = ylab, aes(x = -1, y = y, label = lab), hjust = 1, family = "Fira Sans",
                size = 3.3, fill = NA, label.colour = NA, lineheight = 1.1) +
  scale_x_continuous(breaks = seq(0, 100, 10), labels = paste0(seq(0, 100, 10), "%"),
                     position = "top", expand = c(0, 0)) +
  coord_cartesian(xlim = c(0, 100), clip = "off") +
  labs(
    title = "As Larissa votes, so votes Greece",
    subtitle = glue::glue(
      "Vote share by party in every election since 2019: all of Greece (top bar) and the Larissa constituency (bottom bar). ",
      "The ribbons barely bend. In the three national elections, Larissa never differed from the country by more than ",
      "<b>{max_gap} points</b> for New Democracy, SYRIZA or PASOK, which is why Greek media call it the country's bellwether.<br>",
      paste0("<span style='color:", parties$col[parties$party != "Others"], "'>■</span> ",
             parties$party[parties$party != "Others"], collapse = " &emsp; ")),
    caption = "Share of valid votes. 2024 = European Parliament election. 'Others' = all parties not shown separately (in 2024 incl. Voice of Reason, ~3%).<br>Data: Hellenic Ministry of Interior (ekloges.ypes.gr), collected by GrigorisLionis/Elektion-Data-Scraper on GitHub · Chart: Loukas Theodosiou"
  ) +
  theme_void(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    axis.text.x = element_text(size = 8.5, colour = "#ADB5BD", margin = margin(b = 6)),
    panel.grid.major.x = element_line(colour = "#F1F3F5", linewidth = 0.3),
    plot.title = element_text(family = "Oswald", size = 24, colour = "#1F2933", margin = margin(b = 10)),
    plot.subtitle = element_textbox_simple(size = 10.5, colour = "#495057", lineheight = 1.35,
                                           margin = margin(6, 0, 14, 0)),
    plot.caption = element_textbox_simple(size = 7.5, colour = "#ADB5BD", lineheight = 1.3,
                                          margin = margin(t = 12)),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(20, 24, 14, 90)
  )

ggsave("out/t5_larissa_bellwether.png", p, width = 9, height = 8, dpi = 220, device = ragg::agg_png)
