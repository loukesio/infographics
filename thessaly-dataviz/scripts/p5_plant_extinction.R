# P5 · What drove plants to extinction — Nightingale roses, one per continent
# Data: IUCN Red List, extinct plants (via TidyTuesday 2020-08-18)
library(tidyverse)
library(ggtext)

thr <- read_csv("data/threats.csv", show_col_types = FALSE)

n_species <- n_distinct(thr$binomial_name)

petals <- c("Agriculture & Aquaculture"    = "Farming",
            "Biological Resource Use"      = "Logging & harvesting",
            "Natural System Modifications" = "Fire, dams & drainage",
            "Commercial Development"       = "Building",
            "Invasive Species"             = "Invasive species",
            "Energy Production & Mining"   = "Mining & energy",
            "Climate Change"               = "Climate change")

roses <- thr |>
  filter(threatened == 1, threat_type != "Unknown") |>
  mutate(threat = coalesce(petals[threat_type], "Other (pollution, roads, …)")) |>
  count(continent, threat) |>
  complete(continent, threat, fill = list(n = 0))

per_cont <- thr |> distinct(binomial_name, continent) |> count(continent, name = "species")
roses <- roses |>
  left_join(per_cont, by = "continent") |>
  mutate(cont_lab = glue::glue("{continent}<br><span style='font-size:10pt;color:#7B8794'>{species} species lost</span>"),
         cont_lab = fct_reorder(cont_lab, -species),
         threat   = factor(threat, c(unname(petals), "Other (pollution, roads, …)")))

farm_share <- round(100 * mean(thr$threatened[thr$threat_type == "Agriculture & Aquaculture"]))
africa_n   <- per_cont$species[per_cont$continent == "Africa"]

pal <- c("#2B8A3E", "#8F5B34", "#E8590C", "#5C7CFA", "#C2255C", "#495057", "#1098AD", "#CED4DA")
names(pal) <- levels(roses$threat)

p <- ggplot(roses, aes(threat, n, fill = threat)) +
  geom_col(width = 1, colour = "#FFFFFF", linewidth = 0.4, alpha = 0.92) +
  coord_polar(start = -pi / 8) +
  scale_y_sqrt(expand = c(0, 0)) +            # sqrt so petal AREA is proportional to count
  facet_wrap(~cont_lab, nrow = 2) +
  scale_fill_manual(values = pal, name = NULL) +
  guides(fill = guide_legend(nrow = 2, override.aes = list(colour = NA))) +
  labs(
    title = "Farming, not climate change, is the top driver of plant extinctions",
    subtitle = glue::glue(
      "{n_species} plant species the IUCN lists as extinct or extinct in the wild. Each rose is a continent; ",
      "each petal a threat, its area showing how many lost species faced it. ",
      "<b style='color:{pal[1]}'>Farming</b> affected {farm_share}% of them. ",
      "Africa alone lost <b>{africa_n}</b>, nearly half of them in Madagascar."),
    caption = "A species can face several threats. Data: IUCN Red List (via #TidyTuesday 2020-08-18) · Chart: Loukas Theodosiou"
  ) +
  theme_void(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "#FFFFFF", colour = NA),
    strip.text    = element_markdown(family = "Oswald", size = 14, colour = "#1F2933",
                                     lineheight = 1.1, margin = margin(b = 4)),
    legend.position = "bottom", legend.text = element_text(size = 10, colour = "#3E4C59"),
    legend.key.size = unit(10, "pt"),
    panel.spacing = unit(1, "lines"),
    plot.title    = element_text(family = "Oswald", size = 21, colour = "#1F2933", margin = margin(b = 8)),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.subtitle = element_textbox_simple(size = 11, colour = "#3E4C59", lineheight = 1.3,
                                           margin = margin(4, 0, 14, 0)),
    plot.caption  = element_text(size = 8, colour = "#7B8794", margin = margin(t = 10)),
    plot.margin   = margin(20, 24, 14, 20)
  )

ggsave("out/p5_plant_extinction.png", p, width = 10, height = 9, dpi = 200, device = ragg::agg_png)
