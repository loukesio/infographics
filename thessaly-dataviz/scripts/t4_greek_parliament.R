# The Hellenic Parliament 1974–2023 — seat share by party, ribbon bars
# Style after Ansgar Wolsing's "The German Bundestag"
library(tidyverse)
library(ggtext)

seats <- read_csv("data/greek_parliament_seats.csv", show_col_types = FALSE)

# sanity check: every parliament has exactly 300 seats
chk <- seats |> summarise(total = sum(seats), .by = election)
stopifnot(all(chk$total == 300))

elections <- unique(seats$election)

# left -> right order (roughly political spectrum), one colour per party family
parties <- tribble(
  ~party,          ~col,      ~txt,
  "KKE",           "#B71C1C", "white",
  "EA",            "#B71C1C", "white",
  "KKE Int.",      "#E57373", "white",
  "SPAD",          "#E57373", "white",
  "SYN",           "#D6336C", "white",
  "SYRIZA",        "#D6336C", "white",
  "Plefsi",        "#9C36B5", "white",
  "MeRA25",        "#E8590C", "white",
  "DIMAR",         "#F08C00", "white",
  "DIKKI",         "#F59F00", "white",
  "PASOK",         "#2B8A3E", "white",
  "Potami",        "#74C0FC", "#1F2933",
  "EK-ND",         "#FCC419", "#1F2933",
  "EDIK",          "#FCC419", "#1F2933",
  "Centrists",     "#FFE066", "#1F2933",
  "POLAN",         "#66D9E8", "#1F2933",
  "KNF",           "#CED4DA", "#1F2933",
  "Others",        "#CED4DA", "#1F2933",
  "ND",            "#1C4E9C", "white",
  "ANEL",          "#5C7CFA", "white",
  "LAOS",          "#495057", "white",
  "Greek Solution","#343A40", "white",
  "Niki",          "#868E96", "white",
  "EP",            "#212529", "white",
  "Spartans",      "#212529", "white",
  "Golden Dawn",   "#000000", "white"
)
# party "families" so ribbons connect successors (EA -> KKE, SYN -> SYRIZA, EK-ND -> EDIK)
family <- c(EA = "KKE", SYN = "SYRIZA", "EK-ND" = "EDIK")

pm <- tribble(
  ~election, ~party, ~pm,
  "1974", "ND", "K. Karamanlis",  "1977", "ND", "K. Karamanlis",
  "1981", "PASOK", "A. Papandreou", "1985", "PASOK", "A. Papandreou",
  "1990", "ND", "K. Mitsotakis",  "1993", "PASOK", "A. Papandreou",
  "1996", "PASOK", "Simitis",       "2000", "PASOK", "Simitis",
  "2004", "ND", "K. Karamanlis",  "2007", "ND", "K. Karamanlis",
  "2009", "PASOK", "G. Papandreou", "Jun 2012", "ND", "Samaras",
  "Jan 2015", "SYRIZA", "Tsipras",  "Sep 2015", "SYRIZA", "Tsipras",
  "2019", "ND", "K. Mitsotakis",  "Jun 2023", "ND", "K. Mitsotakis"
)

bar_h <- 0.62   # bar thickness (row spacing = 1)

segs <- seats |>
  left_join(parties, by = "party") |>
  mutate(ord = match(party, parties$party),
         fam = coalesce(family[party], party),
         row = match(election, elections),
         y   = -row) |>
  arrange(row, ord) |>
  group_by(election) |>
  mutate(xmax = cumsum(seats) / 3, xmin = lag(xmax, default = 0)) |>   # percent of 300
  ungroup() |>
  left_join(pm, by = c("election", "party"))

# ribbons between consecutive elections for the same party family
ribbons <- segs |>
  select(row, fam, xmin, xmax, y, col) |>
  inner_join(segs |> select(row, fam, xmin, xmax, y) |> mutate(row = row - 1),
             by = c("row", "fam"), suffix = c("", "_n")) |>
  mutate(id = paste(row, fam)) |>
  rowwise() |>
  reframe(id, col,
          x = c(xmin, xmax, xmax_n, xmin_n),
          yy = c(y - bar_h / 2, y - bar_h / 2, y_n + bar_h / 2, y_n + bar_h / 2))

labs_df <- segs |>
  filter(seats >= 12) |>
  mutate(party = recode(party, "Golden Dawn" = "GD", "Greek Solution" = "EL", "Spartans" = "Sp."),
         lab = if_else(!is.na(pm),
                       glue::glue("<b>{party}</b> <span style='font-size:7pt'>{pm}</span>"),
                       glue::glue("<b>{party}</b>")))

p <- ggplot() +
  geom_polygon(data = ribbons, aes(x, yy, group = id, fill = I(col)), alpha = 0.28) +
  geom_rect(data = segs, aes(xmin = xmin, xmax = xmax, ymin = y - bar_h / 2, ymax = y + bar_h / 2,
                             fill = I(col)), colour = "white", linewidth = 0.25) +
  geom_richtext(data = labs_df, aes((xmin + xmax) / 2, y, label = lab, colour = I(txt)),
                family = "Fira Sans Condensed", size = if_else(labs_df$seats >= 24, 2.9, 2.3), fill = NA, label.colour = NA) +
  geom_vline(xintercept = 50.33, linetype = "22", linewidth = 0.4, colour = "#1F2933") +
  annotate("text", x = 50.33, y = 0.25, label = "151 seats = majority", family = "Fira Sans",
           size = 2.8, colour = "#1F2933", vjust = 0) +
  scale_x_continuous(breaks = seq(0, 100, 10), labels = paste0(seq(0, 100, 10), "%"),
                     position = "top", expand = c(0, 0)) +
  scale_y_continuous(breaks = -seq_along(elections), labels = elections, expand = c(0.01, 0.01)) +
  coord_cartesian(clip = "off") +
  labs(
    title = "The Hellenic Parliament",
    subtitle = "Share of the 300 seats by party, 1974–2023. The prime minister who formed a government after the election is shown next to the party.<br>Parties are ordered roughly from left to right; ribbons follow each party from one election to the next.",
    x = NULL, y = NULL,
    caption = "<b>Note:</b> Seat bonus for the largest party distorts shares. Elections of Jun & Nov 1989, May 2012 and May 2023 produced no single-party government.<br>Seat counts compiled by the author (each election sums to 300); verify against official Ministry of Interior results before publishing. GD = Golden Dawn, EL = Greek Solution. · Chart: Loukas Theodosiou"
  ) +
  theme_minimal(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    panel.grid = element_blank(),
    panel.grid.major.x = element_line(colour = "#E9ECEF", linewidth = 0.3),
    axis.text.y = element_text(family = "Oswald", size = 10, colour = "#1F2933", hjust = 1),
    axis.text.x = element_text(size = 8.5, colour = "#868E96"),
    plot.title = element_text(family = "Oswald", size = 24, colour = "#1F2933"),
    plot.subtitle = element_textbox_simple(size = 10, colour = "#495057", lineheight = 1.3,
                                           margin = margin(4, 0, 12, 0)),
    plot.caption = element_textbox_simple(size = 7.5, colour = "#868E96", lineheight = 1.3,
                                          margin = margin(t = 12)),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(20, 24, 14, 16)
  )

ggsave("out/t4_greek_parliament.png", p, width = 8, height = 11, dpi = 220, device = ragg::agg_png)
