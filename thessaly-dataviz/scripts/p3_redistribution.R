# P3 · Same inequality before taxes, very different after — arrow/dumbbell chart, Kaupp-style
# Data: Our World in Data (LIS) via TidyTuesday 2025-08-05
library(tidyverse)
library(ggtext)

ineq <- read_csv("data/income_inequality_processed.csv", show_col_types = FALSE) |>
  drop_na(gini_mi_eq, gini_dhi_eq) |>
  slice_max(Year, by = Entity) |>
  filter(Year >= 2015) |>                         # recent data only
  mutate(country = glue::glue("{Entity} <span style='color:#9AA5B1'>{Year}</span>"),
         country = fct_reorder(country, gini_dhi_eq))

us <- filter(ineq, Code == "USA"); de <- filter(ineq, Code == "DEU")

hl <- c(USA = "#C92A2A", DEU = "#1971C2")
ineq <- ineq |> mutate(col = coalesce(hl[Code], "#ADB5BD"),
                       lw  = if_else(Code %in% names(hl), 1.1, 0.6))

p <- ggplot(ineq, aes(y = country)) +
  geom_segment(aes(yend = country, x = gini_mi_eq, xend = gini_dhi_eq + 0.006, colour = I(col), linewidth = I(lw)),
               arrow = arrow(length = unit(5, "pt"), type = "closed")) +
  geom_point(aes(x = gini_mi_eq, colour = I(col)), size = 2.4, shape = 21, fill = "#FFFFFF", stroke = 1) +
  # callout
  annotate("richtext", x = 0.60, y = 9.5, hjust = 0, family = "Fira Sans", size = 3.4,
           fill = NA, label.colour = NA, colour = "#3E4C59", lineheight = 1.3,
           label = glue::glue(
             "Before taxes and benefits, <b style='color:{hl['USA']}'>the US</b> ({us$gini_mi_eq})<br>",
             "and <b style='color:{hl['DEU']}'>Germany</b> ({de$gini_mi_eq}) are equally unequal.<br>",
             "After them, Germany drops to {de$gini_dhi_eq};<br>the US only to {us$gini_dhi_eq}.")) +
  scale_x_continuous(limits = c(0.22, 0.85), breaks = seq(0.2, 0.7, 0.1),
                     position = "top", expand = c(0, 0)) +
  labs(
    title = "Taxes decide how unequal a country really is",
    subtitle = "Gini index of income: <b>○ before</b> taxes and benefits → <b>◀ after</b> them. 0 = everyone earns the same, 1 = one person earns everything.<br>Countries sorted by inequality after taxes. Grey number = survey year.",
    x = NULL, y = NULL,
    caption = "Data: Luxembourg Income Study via Our World in Data / #TidyTuesday 2025-08-05 · Chart: Loukas Theodosiou"
  ) +
  theme_minimal(base_family = "Fira Sans") +
  theme(
    plot.background  = element_rect(fill = "#FFFFFF", colour = NA),
    panel.grid.major.y = element_blank(), panel.grid.minor = element_blank(),
    panel.grid.major.x = element_line(colour = "#E2DACB", linewidth = 0.3),
    axis.text.y   = element_markdown(colour = "#1F2933", size = 9.5),
    axis.text.x   = element_text(colour = "#7B8794"),
    plot.title    = element_text(family = "Oswald", size = 21, colour = "#1F2933"),
    plot.subtitle = element_textbox_simple(size = 10.5, colour = "#3E4C59", lineheight = 1.3,
                                           margin = margin(4, 0, 12, 0)),
    plot.caption  = element_text(size = 8, colour = "#7B8794"),
    plot.title.position = "plot", plot.caption.position = "plot",
    plot.margin = margin(20, 24, 14, 20)
  )

ggsave("out/p3_redistribution.png", p, width = 9, height = 9.5, dpi = 200, device = ragg::agg_png)
