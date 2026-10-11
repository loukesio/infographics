# P1 · Carbon Majors since the Paris Agreement — ggvmap Voronoi treemap
# Data: Carbon Majors (via TidyTuesday 2024-05-21)
library(tidyverse)
library(ggvmap)
library(ggtext)

em <- read_csv("data/emissions.csv", show_col_types = FALSE)

since_paris <- em |>
  filter(year >= 2016) |>
  summarise(mt = sum(total_emissions_MtCO2e), .by = c(parent_entity, parent_type)) |>
  mutate(share = 100 * mt / sum(mt)) |>
  arrange(desc(mt))

total_gt  <- sum(since_paris$mt) / 1000
n_ent     <- nrow(since_paris)
top10     <- round(sum(since_paris$share[1:10]))
yr_max    <- max(em$year)

# short readable names
since_paris <- since_paris |>
  mutate(
    label = parent_entity |>
      str_replace("Coal India", "Coal India") |>
      str_replace("^China \\(Coal\\)", "China (coal)") |>
      str_replace("Former Soviet Union", "Fmr. USSR") |>
      str_replace("Saudi Aramco", "Saudi Aramco") |>
      str_replace("National Iranian Oil Co.", "NIOC (Iran)") |>
      str_replace("Abu Dhabi National Oil Company", "ADNOC") |>
      str_replace("Petroleos de Venezuela", "PDVSA") |>
      str_replace(" ?\\(Cement\\)", " cement") |>
      str_replace("Kuwait Petroleum Corp.", "Kuwait Petroleum") |>
      str_replace("Iraq National Oil Company", "Iraq NOC"),
    group = recode(parent_type,
                   "State-owned Entity"      = "State-owned companies",
                   "Investor-owned Company"  = "Investor-owned companies",
                   "Nation State"            = "Nation states")
  )

pal <- c("Investor-owned companies" = "#2E4057",
         "Nation states"            = "#B5223B",
         "State-owned companies"    = "#D98E04")

grp_order <- unique(since_paris$group)   # ggvmap colours groups in order of appearance
pal_vm    <- unname(pal[grp_order])

vm <- voronoi_map(since_paris$share, labels = since_paris$label,
                  group = since_paris$group, clip = clip_circle(),
                  seed = 7, max_iter = 120)

p <- ggvmap(vm, palette = pal_vm,
            label_col = "white", autoscale = TRUE, min_area = 0.012,
            wrap = 11, family = "Fira Sans Condensed",
            border_col = "#FFFFFF", group_border_col = "#FFFFFF",
            border_size = 0.4, group_border_size = 2.2) |>
  vm_add_labels(fmt = \(v) paste0(round(v, 1), "%"), autoscale = TRUE,
                col = "white", family = "Fira Sans Light",
                min_area = 0.012) |>
  vm_add_ring(style = "arc", palette = pal_vm,
              values = TRUE)

p <- p +
  labs(
    title = glue::glue("Since Paris, {n_ent} fossil-fuel and cement producers are linked to {round(total_gt)} billion tonnes of CO₂e"),
    subtitle = glue::glue(
      "Each cell is one producer, sized by its share of emissions 2016–{yr_max}. ",
      "The top 10 alone account for **{top10}%**.<br>",
      "<span style='color:{pal[2]}'>**Nation states**</span> · ",
      "<span style='color:{pal[3]}'>**State-owned companies**</span> · ",
      "<span style='color:{pal[1]}'>**Investor-owned companies**</span>"),
    caption = "Data: Carbon Majors database (InfluenceMap) via #TidyTuesday · Chart: Loukas Theodosiou · built with ggvmap"
  ) +
  theme(
    plot.background  = element_rect(fill = "#FFFFFF", colour = NA),
    panel.background = element_rect(fill = "#FFFFFF", colour = NA),
    plot.title    = element_text(family = "Oswald", size = 19, colour = "#1F2933",
                                 margin = margin(b = 6)),
    plot.subtitle = element_markdown(family = "Fira Sans", size = 11.5,
                                     colour = "#3E4C59", lineheight = 1.3),
    plot.caption  = element_text(family = "Fira Sans", size = 8, colour = "#7B8794"),
    plot.margin   = margin(20, 20, 14, 20)
  )

ggsave("out/p1_carbon_majors.png", p, width = 9, height = 10, dpi = 200, device = ragg::agg_png)
