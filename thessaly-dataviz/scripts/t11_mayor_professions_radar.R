# What did Larissa's mayors do for a living? Radar of professions in three eras (style after Jake Lawlor)
library(tidyverse)
library(patchwork)
library(ggtext)

m <- read_csv("data/larissa_mayors_1881.csv", show_col_types = FALSE) |>
  filter(profession != "—")                       # current mayor: profession not in the source

grp <- c(doctor = "Doctors", lawyer = "Law", judge = "Law",
         merchant = "Trade", `grain merchant` = "Trade", businessman = "Trade", tradesman = "Trade", landowner = "Trade",
         agronomist = "Land & building", `civil engineer` = "Land & building", `farm-estate manager` = "Land & building",
         pharmacist = "Pharmacy & dentistry", dentist = "Pharmacy & dentistry",
         teacher = "Teaching")
axes <- c("Doctors", "Law", "Trade", "Land & building", "Teaching", "Pharmacy & dentistry")

eras <- tribble(~era, ~e0, ~e1,
                "1881–1935", 1881, 1936,
                "1936–1974", 1936, 1975,
                "1975–2023", 1975, 2023)
cols <- c("1881–1935" = "#C994D6", "1936–1974" = "#B5508F", "1975–2023" = "#F5A882")

# years in office per profession group, clipped to each era
terms <- m |> mutate(g = grp[profession]) |>
  cross_join(eras) |>
  mutate(yrs = pmax(0, pmin(to, e1) - pmax(from, e0))) |>
  filter(yrs > 0)

share <- terms |>
  summarise(yrs = sum(yrs), .by = c(era, g)) |>
  complete(era = eras$era, g = axes, fill = list(yrs = 0)) |>
  mutate(v = yrs / sum(yrs), .by = era) |>
  mutate(k = match(g, axes))

# radar geometry
n_ax  <- length(axes)
theta <- \(k) 2 * pi * (k - 1) / n_ax
rmax  <- 0.75                                     # outer ring = 75% of the era's years
xy <- \(df) df |> mutate(x = v / rmax * sin(theta(k)), y = v / rmax * cos(theta(k)))
close <- \(df) df |> arrange(era, k) |> group_by(era) |> group_modify(\(d, ...) bind_rows(d, d[1, ])) |> ungroup()

polys <- share |> xy() |> close()

# thin "spikes": one per term, length = that term's share of its era's years (the spaghetti layer)
spikes <- terms |>
  mutate(v = yrs / sum(yrs), .by = era) |>
  mutate(k = match(g, axes)) |> xy()

rings <- expand_grid(r = c(0.25, 0.5, 0.75), a = seq(0, 2 * pi, length.out = 200)) |>
  mutate(x = r / rmax * sin(a), y = r / rmax * cos(a))
ring_lab <- tibble(r = c(0.25, 0.5, 0.75)) |> mutate(x = r / rmax * sin(pi / 6), y = r / rmax * cos(pi / 6), lab = paste0(r * 100, "%"))
spokes <- tibble(k = 1:n_ax) |> mutate(x = 1.04 * sin(theta(k)), y = 1.04 * cos(theta(k)))
axlabs <- tibble(k = 1:n_ax, lab = axes) |>
  mutate(x = 1.16 * sin(theta(k)), y = 1.16 * cos(theta(k)),
         hjust = case_when(abs(x) < 0.1 ~ 0.5, x > 0 ~ 0, TRUE ~ 1))

base <- function(labels = TRUE) list(
  geom_path(data = rings, aes(x, y, group = r), colour = "#E6E6E6", linewidth = 0.6),
  geom_segment(data = spokes, aes(0, 0, xend = x, yend = y), colour = "#E6E6E6", linewidth = 0.6),
  if (labels) geom_text(data = axlabs, aes(x, y, label = lab, hjust = hjust), family = "Fira Sans Light",
                        size = 5, colour = "#3E4C59"),
  if (labels) geom_text(data = ring_lab, aes(x, y, label = lab), family = "Fira Sans", size = 2.8,
                        colour = "#ADB5BD", hjust = 0, vjust = -0.3),
  scale_colour_manual(values = cols, aesthetics = c("colour", "fill"), guide = "none"),
  coord_equal(clip = "off"),
  theme_void()
)

main <- ggplot() + base() +
  geom_polygon(data = polys, aes(x, y, group = era, fill = era), alpha = 0.25) +
  geom_polygon(data = polys, aes(x, y, group = era, colour = era), fill = NA, linewidth = 2.4) +
  xlim(-1.6, 1.6) + ylim(-1.25, 1.3)

small <- map(eras$era, \(e) {
  ggplot() + base(labels = FALSE) +
    geom_segment(data = filter(spikes, era == e), aes(0, 0, xend = x, yend = y, colour = era),
                 linewidth = 0.7, alpha = 0.6) +
    geom_point(data = filter(spikes, era == e), aes(x, y, colour = era), size = 1.6) +
    geom_polygon(data = filter(polys, era == e), aes(x, y, fill = era), alpha = 0.2) +
    geom_polygon(data = filter(polys, era == e), aes(x, y, colour = era), fill = NA, linewidth = 1.3) +
    labs(title = e) +
    theme(plot.title = element_text(family = "Fira Sans", size = 13, hjust = 0.5, colour = cols[[e]]))
})

# numbers for the subtitle
doc_early <- round(100 * share$v[share$era == "1881–1935" & share$g == "Doctors"])
law_mid   <- round(100 * share$v[share$era == "1936–1974" & share$g == "Law"])
land_late <- round(100 * share$v[share$era == "1975–2023" & share$g == "Land & building"])

p <- main / wrap_plots(small, nrow = 1) +
  plot_layout(heights = c(3.2, 1)) +
  plot_annotation(
    title = "Who Ran Larissa?",
    subtitle = paste0(
      "<span style='font-size:13pt;color:#495057'>Share of years in office held by each profession, in three eras</span><br>",
      paste0("<span style='color:", cols, "'>", names(cols), "</span>", collapse = " &nbsp; ")),
    caption = glue::glue(
      "Before 1936, doctors held the town hall {doc_early}% of the time. From 1936 to 1974, years of dictatorship, war and appointed mayors, lawyers and judges held it {law_mid}% of the time. ",
      "Since 1975 two agronomists and a civil engineer account for {land_late}%.<br>",
      "Small charts: each spoke is one term, its length that term's share of the era. Current mayor (since 2023) not included: profession not in the source.<br>",
      "Source: eleftheria.gr, «Οι δήμαρχοι της Λάρισας από το 1881 μέχρι σήμερα» · Chart: Loukas Theodosiou · style after Jake Lawlor"),
    theme = theme(
      plot.background = element_rect(fill = "white", colour = NA),
      plot.title = element_text(family = "Fira Sans Light", size = 40, hjust = 0.5, colour = "#111111"),
      plot.subtitle = element_markdown(family = "Fira Sans", face = "bold", size = 22, hjust = 0.5,
                                       lineheight = 1.4, margin = margin(4, 0, 0, 0)),
      plot.caption = element_textbox_simple(family = "Fira Sans", size = 9, colour = "#495057",
                                            halign = 0.5, lineheight = 1.35, margin = margin(t = 12)),
      plot.margin = margin(24, 30, 16, 30)
    )
  )

ggsave("out/t11_mayor_professions_radar.png", p, width = 9, height = 12, dpi = 200, device = ragg::agg_png)
