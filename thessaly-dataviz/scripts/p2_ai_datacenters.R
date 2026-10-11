# P2 · Who owns the power behind AI — ggvmap Voronoi treemap
# Data: Epoch AI, Frontier Data Centers hub (operating sites, current power in MW)
library(tidyverse)
library(ggvmap)
library(ggtext)

dc <- read_csv("data/epoch_data_centers.csv", show_col_types = FALSE) |>
  filter(power_mw > 0)

total_gw <- sum(dc$power_mw) / 1000
us_share <- round(100 * sum(dc$power_mw[dc$country == "United States"]) / sum(dc$power_mw))

owners <- dc |> filter(owner != "Unlisted") |>
  summarise(mw = sum(power_mw), .by = owner) |> arrange(desc(mw))
big5 <- owners$owner[1:5]
big5_share <- round(100 * sum(dc$power_mw[dc$owner %in% big5]) / sum(dc$power_mw))

dc <- dc |>
  mutate(group = if_else(owner %in% big5, owner, "Everyone else"),
         group = factor(group, c(big5, "Everyone else")),
         label = name |> str_remove("^(Google|Meta|Microsoft|AWS|Amazon) ") |>
           str_replace("Anthropic-Amazon ", "")) |>
  arrange(group, desc(power_mw))

pal <- c(Google = "#3B5BDB", Meta = "#E8590C", Amazon = "#2B8A3E",
         Microsoft = "#C2255C", SpaceXAI = "#7048E8", "Everyone else" = "#ADB5BD")
grp_order <- unique(as.character(dc$group))   # ggvmap colours groups in order of appearance
pal_vm <- unname(pal[grp_order])

vm <- voronoi_map(dc$power_mw, labels = dc$label, group = as.character(dc$group),
                  clip = clip_circle(), seed = 3, max_iter = 120)

p <- ggvmap(vm, palette = pal_vm,
            label_col = "white", autoscale = TRUE, min_area = 0.02, wrap = 11,
            family = "Fira Sans Condensed", border_size = 0.5, group_border_size = 2.4) |>
  vm_add_ring(style = "arc", palette = pal_vm, values = TRUE)

p <- p +
  labs(
    title = glue::glue("Five companies control {big5_share}% of the power in the biggest AI data centers"),
    subtitle = glue::glue(
      "The {nrow(dc)} largest operating AI data centers tracked by Epoch AI use <b>{round(total_gw, 1)} gigawatts</b> ",
      "of electricity. Each cell is one data center, sized by the power it draws today. ",
      "{us_share}% of this power is in the United States."),
    caption = "Data: Epoch AI, Frontier Data Centers hub (accessed Oct 2026) · Chart: Loukas Theodosiou · built with ggvmap"
  ) +
  theme(
    plot.background  = element_rect(fill = "white", colour = NA),
    panel.background = element_rect(fill = "white", colour = NA),
    plot.title    = element_text(family = "Oswald", size = 19, colour = "#1F2933", margin = margin(b = 6)),
    plot.subtitle = element_textbox_simple(family = "Fira Sans", size = 11.5, colour = "#3E4C59",
                                           lineheight = 1.3, margin = margin(b = 10)),
    plot.caption  = element_text(family = "Fira Sans", size = 8, colour = "#7B8794"),
    plot.margin   = margin(20, 20, 14, 20)
  )

ggsave("out/p2_ai_datacenters.png", p, width = 9, height = 10, dpi = 200, device = ragg::agg_png)
