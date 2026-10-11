# 145 years of Larissa's mayors, 1881–today — one row per person, elected vs appointed
library(tidyverse)
library(ggtext)

m <- read_csv("data/larissa_mayors_1881.csv", show_col_types = FALSE)

people <- m |> summarise(first = min(from), years = sum(to - from), .by = c(name, profession)) |>
  arrange(first) |> mutate(row = row_number())
m <- m |> left_join(select(people, name, row), by = "name")

col <- c(elected = "#0B7285", appointed = "#E8590C")

# share of years with an appointed (not elected) mayor
yrs_app <- m |> filter(how == "appointed") |> summarise(y = sum(to - from)) |> pull(y)
share_app <- round(100 * yrs_app / (max(m$to) - min(m$from)))
n_doc <- sum(people$profession == "doctor")

eras <- tribble(
  ~from, ~to,  ~lab,                     ~ly,
  1936, 1941,  "Metaxas dictatorship",    -1.5,
  1941, 1944.8, "Occupation",             -0.6,
  1946, 1949,  "Civil war",               0.3,
  1967, 1974.6, "Military junta",         -0.6
)

p <- ggplot() +
  geom_rect(data = eras, aes(xmin = from, xmax = to, ymin = -Inf, ymax = Inf), fill = "#F1F3F5") +
  geom_text(data = eras, aes(x = (from + to) / 2, y = ly, label = lab),
            family = "Fira Sans", size = 2.6, colour = "#868E96") +
  geom_segment(data = people, aes(x = 1881, xend = 2026.8, y = row, yend = row),
               colour = "#F1F3F5", linewidth = 0.3) +
  geom_rect(data = m, aes(xmin = from, xmax = pmax(to, from + 0.45), ymin = row - 0.36, ymax = row + 0.36,
                          fill = how), colour = NA) +
  geom_text(data = people, aes(x = 1879, y = row, label = name), hjust = 1, family = "Fira Sans",
            size = 3, colour = "#1F2933") +
  geom_text(data = people, aes(x = 2028, y = row,
                               label = if_else(profession == "—", "", profession)),
            hjust = 0, family = "Fira Sans", size = 2.6,
            colour = if_else(people$profession == "doctor", "#C2255C", "#ADB5BD")) +
  scale_fill_manual(values = col, guide = "none") +
  scale_y_reverse(expand = expansion(add = c(0.8, 2.1))) +
  scale_x_continuous(breaks = seq(1890, 2020, 10), position = "top") +
  coord_cartesian(xlim = c(1881, 2026.8), clip = "off") +
  labs(
    title = "145 Years of Larissa's Mayors",
    subtitle = glue::glue(
      "Every mayor since Thessaly became part of Greece in 1881, one row per person. ",
      "<b style='color:{col['elected']}'>Elected</b> or <b style='color:{col['appointed']}'>appointed by the government</b>. ",
      "For about <b>{share_app}%</b> of these years the city was run by an appointed mayor, mostly in times of war, ",
      "civil strife and dictatorship. <b style='color:#C2255C'>{n_doc} of {nrow(people)}</b> mayors were doctors."),
    caption = "Terms as listed by the newspaper Eleftheria; where the list overlaps (1967–70/1969–74, 1978–81/1980–94) the hand-over is drawn at the later start. Short 1944–46 terms are shown at their order, not exact months.<br>Source: eleftheria.gr, «Οι δήμαρχοι της Λάρισας από το 1881 μέχρι σήμερα»; 2023 from the Region of Thessaly results · Chart: Loukas Theodosiou"
  ) +
  theme_void(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    axis.text.x = element_text(size = 8.5, colour = "#868E96", margin = margin(b = 4)),
    plot.title = element_text(family = "Oswald", size = 26, colour = "#1F2933", margin = margin(b = 8)),
    plot.subtitle = element_textbox_simple(size = 10.5, colour = "#495057", lineheight = 1.35,
                                           margin = margin(6, 0, 12, 0)),
    plot.caption = element_textbox_simple(size = 7.2, colour = "#ADB5BD", lineheight = 1.3,
                                          margin = margin(t = 12)),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(20, 90, 14, 120)
  )

ggsave("out/t10_larissa_mayors_1881.png", p, width = 10, height = 10, dpi = 220, device = ragg::agg_png)
