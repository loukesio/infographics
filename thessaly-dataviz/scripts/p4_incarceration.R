# P4 · The racial gap in US prisons — small multiples, Scherer-style
# Data: Vera Institute of Justice, Incarceration Trends (via TidyTuesday 2019-01-22)
library(tidyverse)
library(ggtext)

pr <- read_csv("data/prison_summary.csv", show_col_types = FALSE) |>
  filter(pop_category %in% c("Black", "Latino", "White"), year >= 1990) |>
  mutate(urbanicity = recode(urbanicity, "small/mid" = "Small & mid-size cities",
                             rural = "Rural counties", suburban = "Suburbs", urban = "Big cities"),
         urbanicity = factor(urbanicity, c("Big cities", "Small & mid-size cities", "Suburbs", "Rural counties")))

wide <- pr |> pivot_wider(names_from = pop_category, values_from = rate_per_100000)
ratio <- wide |> filter(year == max(year)) |> mutate(r = Black / White)
rng <- round(range(ratio$r))

cols <- c(Black = "#7048E8", Latino = "#E8590C", White = "#868E96")

p <- ggplot() +
  geom_ribbon(data = wide, aes(year, ymin = White, ymax = Black), fill = cols["Black"], alpha = 0.10) +
  geom_line(data = pr, aes(year, rate_per_100000, colour = pop_category), linewidth = 1) +
  geom_point(data = filter(pr, year == max(year)),
             aes(year, rate_per_100000, colour = pop_category), size = 2) +
  geom_richtext(data = ratio, aes(x = max(wide$year) - 0.5, y = (Black + White) / 2,
                                  label = glue::glue("<b>{round(r, 1)}×</b>")),
                hjust = 1, family = "Fira Sans", size = 4.2, colour = cols["Black"],
                fill = NA, label.colour = NA) +
  facet_wrap(~urbanicity, nrow = 1) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_y_continuous(labels = scales::comma, breaks = seq(0, 2500, 500)) +
  scale_x_continuous(breaks = c(1990, 2000, 2010)) +
  labs(
    title = glue::glue("Black Americans are imprisoned at {rng[1]}–{rng[2]} times the rate of white Americans"),
    subtitle = glue::glue(
      "Prison population per 100,000 residents, by type of county, 1990–{max(wide$year)}. ",
      "<b style='color:{cols['Black']}'>Black</b> · <b style='color:{cols['Latino']}'>Latino</b> · ",
      "<b style='color:{cols['White']}'>White</b>. The shaded band is the gap; the number is the ratio in {max(wide$year)}."),
    x = NULL, y = NULL,
    caption = "Data: Vera Institute of Justice, Incarceration Trends (via #TidyTuesday 2019-01-22) · Chart: Loukas Theodosiou"
  ) +
  theme_minimal(base_family = "Fira Sans", base_size = 11) +
  theme(
    plot.background  = element_rect(fill = "#FFFFFF", colour = NA),
    panel.grid.minor = element_blank(), panel.grid.major.x = element_blank(),
    panel.grid.major.y = element_line(colour = "#E2DACB", linewidth = 0.3),
    strip.text    = element_text(family = "Oswald", size = 13, hjust = 0, colour = "#1F2933"),
    axis.text     = element_text(colour = "#7B8794"),
    panel.spacing = unit(1.4, "lines"),
    plot.title    = element_text(family = "Oswald", size = 20, colour = "#1F2933"),
    plot.subtitle = element_textbox_simple(size = 11, colour = "#3E4C59", lineheight = 1.3,
                                           margin = margin(4, 0, 14, 0)),
    plot.caption  = element_text(size = 8, colour = "#7B8794"),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(20, 24, 14, 20)
  )

ggsave("out/p4_incarceration.png", p, width = 12, height = 6, dpi = 200, device = ragg::agg_png)
