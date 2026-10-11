# Thessaly · Storm Daniel, September 2023 — rain gauges
library(tidyverse)
library(ggtext)

rain <- tribble(
  ~place,                         ~period,                 ~mm,  ~kind,
  "Athens",                       "a whole year\n(average)", 400, "ref",
  "Makrynitsa",                   "old Greek daily\nrecord, 2009", 417, "ref",
  "Karditsa",                     "4 days",                 659, "daniel",
  "Zagora",                       "1 day",                  760, "daniel",
  "Portaria",                     "1 day",                  762, "daniel",
  "Zagora",                       "4 days",                 910, "daniel",
  "Makrynitsa",                   "1–20 September",        1235, "daniel"
) |> mutate(i = row_number())

blue <- "#1971C2"; grey <- "#ADB5BD"
w <- 0.30                                   # half-width of a gauge
top <- 1400

ticks <- expand_grid(i = rain$i, t = seq(100, 1300, 100))

p <- ggplot(rain) +
  # empty tube
  geom_rect(aes(xmin = i - w, xmax = i + w, ymin = 0, ymax = top),
            fill = "#F8F9FA", colour = "#DEE2E6", linewidth = 0.4) +
  # water
  geom_rect(aes(xmin = i - w, xmax = i + w, ymin = 0, ymax = mm,
                fill = I(if_else(kind == "ref", grey, blue))), colour = NA) +
  geom_segment(data = ticks, aes(x = i - w, xend = i - w + 0.08, y = t, yend = t),
               colour = "white", linewidth = 0.35, alpha = 0.9) +
  # Athens reference line
  geom_hline(yintercept = 400, linetype = "22", colour = "#495057", linewidth = 0.4) +
  geom_text(aes(i, mm + 25, label = paste0(scales::comma(mm), " mm"),
                colour = I(if_else(kind == "ref", "#868E96", blue))),
            family = "Oswald", size = 4.6, vjust = 0) +
  geom_text(aes(i, -40, label = place), family = "Oswald", size = 4.2, colour = "#1F2933", vjust = 1) +
  geom_text(aes(i, -120, label = period), family = "Fira Sans", size = 3, colour = "#868E96",
            vjust = 1, lineheight = 0.9) +
  scale_y_continuous(limits = c(-260, top + 60), expand = c(0, 0)) +
  scale_x_continuous(expand = expansion(add = 0.4)) +
  labs(
    title = "Storm Daniel poured a year of rain on Thessaly in a day",
    subtitle = glue::glue(
      "Rainfall measured in Thessaly during Storm Daniel, 4–7 September 2023 (<b style='color:{blue}'>blue</b>), ",
      "against reference values (<b style='color:#868E96'>grey</b>). The dashed line is Athens' rain in a whole year. In one day Portaria and Zagora on Mount Pelion ",
      "got almost twice what Athens gets in a year. The floods covered about 730 km² of the Thessalian plain, ",
      "killed 17 people and some 110,000 farm animals."),
    caption = "Sources: National Observatory of Athens / meteo.gr via KeepTalkingGreece (daily & monthly records), NASA Earth Observatory (4-day totals, Athens average),<br>Wikipedia 'Storm Daniel' (flooded area from Sentinel-1, deaths, livestock). Makrynitsa's 1,235 mm is the highest monthly rainfall ever recorded in Europe. · Chart: Loukas Theodosiou"
  ) +
  theme_void(base_family = "Fira Sans") +
  theme(
    plot.background = element_rect(fill = "white", colour = NA),
    plot.title    = element_text(family = "Oswald", size = 22, colour = "#1F2933"),
    plot.subtitle = element_textbox_simple(size = 10.5, colour = "#495057", lineheight = 1.35,
                                           margin = margin(6, 0, 16, 0)),
    plot.caption  = element_textbox_simple(size = 7.5, colour = "#ADB5BD", lineheight = 1.3,
                                           margin = margin(t = 10)),
    plot.margin   = margin(22, 26, 14, 26)
  )

ggsave("out/t1_storm_daniel.png", p, width = 10, height = 8, dpi = 220, device = ragg::agg_png)
