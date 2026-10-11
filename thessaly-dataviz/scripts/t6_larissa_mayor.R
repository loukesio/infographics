# Who runs Larissa? Mayoral elections 2014–2023 — ribbon bars
# Data: Region of Thessaly election results (ekloges.thessaly.gov.gr), Dim2014A/B, Dim2019A/B, Dim2023A
library(tidyverse)
library(ggtext)

d <- read_csv("data/larissa_mayor.csv", show_col_types = FALSE)
rounds <- unique(d$round)

key_order <- c("laiki", "kalogiannis", "tzanakoulis", "nasiokas", "vaioulis", "goulas",
               "gamvroulas", "bartzokis", "diamantos", "karalariotou", "mamakos")
cols <- c(laiki = "#B71C1C", kalogiannis = "#0B7285", tzanakoulis = "#F08C00", nasiokas = "#82C91E",
          vaioulis = "#CED4DA", goulas = "#ADB5BD", gamvroulas = "#868E96", bartzokis = "#DEE2E6",
          diamantos = "#BE4BDB", karalariotou = "#4C6EF5", mamakos = "#1C4E9C")
txt <- c(vaioulis = "#495057", goulas = "#343A40", bartzokis = "#495057")

bar_h <- 0.62
segs <- d |>
  mutate(row = match(round, rounds), y = -row,
         ord = match(key, key_order), col = cols[key], txtcol = coalesce(txt[key], "white")) |>
  arrange(row, ord) |>
  group_by(round) |>
  mutate(share = 100 * votes / sum(votes),
         xmax = cumsum(share), xmin = lag(xmax, default = 0)) |>
  ungroup()

ribbons <- segs |>
  select(row, key, col, xmin, xmax, y) |>
  inner_join(segs |> select(row, key, xmin, xmax, y) |> mutate(row = row - 1),
             by = c("row", "key"), suffix = c("", "_n")) |>
  mutate(id = paste(row, key)) |>
  rowwise() |>
  reframe(id, col,
          x  = c(xmin, xmax, xmax_n, xmin_n),
          yy = c(y - bar_h / 2, y - bar_h / 2, y_n + bar_h / 2, y_n + bar_h / 2))

winners <- tribble(~round, ~key, "2014 · runoff", "kalogiannis", "2019 · runoff", "kalogiannis",
                   "2023 · 1st round", "mamakos")
labs_df <- segs |>
  filter(share >= 5) |>
  left_join(winners |> mutate(win = TRUE), by = c("round", "key")) |>
  mutate(lab = case_when(
    share >= 15 ~ glue::glue("<b>{candidate}</b> {sprintf('%.1f', share)}%{if_else(coalesce(win, FALSE), ' ✓', '')}"),
    share >= 10 ~ glue::glue("<b>{candidate}</b><br>{sprintf('%.1f', share)}%"),
    TRUE        ~ glue::glue("{sprintf('%.0f', share)}%")))

p <- ggplot() +
  geom_polygon(data = ribbons, aes(x, yy, group = id, fill = I(col)), alpha = 0.25) +
  geom_rect(data = segs, aes(xmin = xmin, xmax = xmax, ymin = y - bar_h / 2, ymax = y + bar_h / 2,
                             fill = I(col)), colour = "white", linewidth = 0.4) +
  geom_richtext(data = labs_df, aes((xmin + xmax) / 2, y, label = lab, colour = I(txtcol)),
                family = "Fira Sans Condensed", size = if_else(labs_df$share >= 15, 3.3, 2.8), lineheight = 1, fill = NA, label.colour = NA) +
  geom_vline(xintercept = 50, linetype = "22", linewidth = 0.4, colour = "#1F2933") +
  annotate("text", x = 50.5, y = -0.62, label = "50%", hjust = 0, family = "Fira Sans", size = 3, colour = "#1F2933", vjust = 0) +
  scale_x_continuous(breaks = seq(0, 100, 10), labels = paste0(seq(0, 100, 10), "%"),
                     position = "top", expand = c(0, 0)) +
  scale_y_continuous(breaks = -seq_along(rounds), labels = rounds, expand = c(0.02, 0.02)) +
  coord_cartesian(clip = "off") +
  labs(
    title = "Who runs Larissa?",
    subtitle = glue::glue(
      "Vote share of every mayoral candidate in the Municipality of Larissa, 2014–2023. ",
      "<b style='color:{cols['kalogiannis']}'>Apostolos Kalogiannis</b> won two runoffs against ",
      "<b style='color:{cols['karalariotou']}'>Rena Karalariotou</b>, then lost in 2023 when ",
      "<b style='color:{cols['mamakos']}'>Thanasis Mamakos</b> took 51% and won in the first round. ",
      "<b style='color:{cols['laiki']}'>Laiki Syspeirosi</b> (KKE-backed list) rose from 6% to 9% between 2019 and 2023. ✓ = elected."),
    x = NULL, y = NULL,
    caption = "Share of valid votes. A candidate needs over 50% (since 2023: over 43%) in the 1st round to avoid a runoff.<br>Data: Region of Thessaly election results (ekloges.thessaly.gov.gr) · Chart: Loukas Theodosiou"
  ) +
  theme_minimal(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    panel.grid = element_blank(),
    panel.grid.major.x = element_line(colour = "#F1F3F5", linewidth = 0.3),
    axis.text.y = element_text(family = "Oswald", size = 11, colour = "#1F2933", hjust = 1),
    axis.text.x = element_text(size = 8.5, colour = "#ADB5BD"),
    plot.title = element_text(family = "Oswald", size = 26, colour = "#1F2933", margin = margin(b = 8)),
    plot.subtitle = element_textbox_simple(size = 10.5, colour = "#495057", lineheight = 1.35,
                                           margin = margin(4, 0, 14, 0)),
    plot.caption = element_textbox_simple(size = 7.5, colour = "#ADB5BD", lineheight = 1.3,
                                          margin = margin(t = 12)),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(20, 24, 14, 16)
  )

ggsave("out/t6_larissa_mayor.png", p, width = 9, height = 6.5, dpi = 220, device = ragg::agg_png)
