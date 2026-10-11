# t14 — What Thessaly sells abroad, and to whom (2025)
# Layout after the "Made in France" export Sankey: product categories on top, destination markets below,
# links between them. Bar widths are proportional to € values (ELSTAT 2025 via the ΣΒΘΣΕ study).
# The links are QUALITATIVE: the study names the main products of each market but publishes no
# product × country values, so every link has the same width. Said on the chart.
# Data: data/exports/*.csv, see data/exports/README.md for provenance.
suppressPackageStartupMessages({ library(tidyverse); library(ggtext) })

prod <- read.csv("data/exports/thessaly_exports_2025_products.csv")
ctry <- read.csv("data/exports/thessaly_exports_2025_countries.csv")
link <- read.csv("data/exports/thessaly_exports_2025_links.csv")
TOTAL <- 2238.6                                     # € m, Thessaly exports 2025

pal <- c(Food = "#C08A1E", Metals = "#1C4B52", Cotton = "#8B8474", Other = "#B3241F", Rest = "#D9D4C7")

# ---- positions: both rows share one scale (x = € m), with a gap between boxes --------------------
gap <- 28
place <- function(d, value) {
  d |> mutate(v = {{ value }}, xmax = cumsum(v) + gap * (row_number() - 1), xmin = xmax - v, xc = (xmin + xmax) / 2)
}
P <- prod |> mutate(label = product_en) |>
  bind_rows(tibble(label = "All other products", group = "Rest", value_meur = TOTAL - sum(prod$value_meur))) |>
  place(value_meur)
C <- ctry |> mutate(label = country_en, group = "Country") |>
  bind_rows(tibble(label = "All other countries", group = "Rest", value_meur = TOTAL - sum(ctry$value_meur))) |>
  place(value_meur)
# centre the shorter row under the longer one
shift <- (max(P$xmax) - max(C$xmax)) / 2; C <- C |> mutate(across(c(xmin, xmax, xc), \(x) x + shift))

y_top <- 1; y_bot <- 0; bh <- 0.055                 # row y and box half-height

# ---- links: bezier from product box bottom to country box top ---------------------------------------
L <- link |> left_join(P |> select(product_en, px = xc, pg = group), by = "product_en") |>
  left_join(C |> select(country_en, cx = xc), by = "country_en") |>
  mutate(id = row_number())
bez <- L |> rowwise() |> reframe(id = id, pg = pg, t = seq(0, 1, length.out = 40),
                                x = (1 - t)^3 * px + 3 * (1 - t)^2 * t * px + 3 * (1 - t) * t^2 * cx + t^3 * cx,
                                y = (y_top - bh) - t * (y_top - y_bot - 2 * bh))

Plab <- P |> mutate(small = value_meur < 120 & group != "Rest",
                    row = ifelse(small, (cumsum(small) - 1) %% 3 + 1, 0),
                    ylab = y_top + bh + 0.045 + row * 0.075)
fmt <- \(v) paste0("€", trimws(format(round(v), big.mark = ",")), " m")
p <- ggplot() +
  geom_path(data = bez, aes(x, y, group = id, colour = pg), linewidth = .45, alpha = .55, lineend = "round") +
  geom_rect(data = P, aes(xmin = xmin, xmax = xmax, ymin = y_top - bh, ymax = y_top + bh, fill = group)) +
  geom_rect(data = C, aes(xmin = xmin, xmax = xmax, ymin = y_bot - bh, ymax = y_bot + bh, fill = group)) +
  # product labels: big boxes get one tier; the run of small boxes cycles through three tiers with leader ticks
  geom_segment(data = Plab |> filter(row > 0), aes(x = xc, xend = xc, y = y_top + bh + 0.01, yend = ylab - 0.012),
               colour = "#c7bfa9", linewidth = .3) +
  geom_text(data = Plab, aes(x = xc, y = ylab, label = str_wrap(label, 18)),
            family = "Fira Sans Condensed", size = 3.1, colour = "#191713", lineheight = .85, vjust = 0) +
  geom_text(data = P, aes(x = xc, y = y_top, label = ifelse(value_meur >= 90, fmt(value_meur), "")),
            family = "Fira Sans Condensed", size = 2.9, colour = "white", fontface = "bold") +
  geom_text(data = C |> mutate(row = ifelse(value_meur > 100 | row_number() %% 2 == 1, 0, 1)),
            aes(x = xc, y = y_bot - bh - 0.045 - row * 0.07, label = paste0(label, "\n", fmt(value_meur))),
            family = "Fira Sans Condensed", size = 3.1, colour = "#191713", lineheight = .85, vjust = 1) +
  annotate("text", x = -40, y = y_top, label = "PRODUCTS", family = "Oswald", size = 3.6, colour = "#8b8474", hjust = 1) +
  annotate("text", x = -40, y = y_bot, label = "MARKETS", family = "Oswald", size = 3.6, colour = "#8b8474", hjust = 1) +
  scale_fill_manual(values = c(pal, Country = "#4a463d"), guide = "none") +
  scale_colour_manual(values = pal, guide = "none") +
  scale_y_continuous(limits = c(y_bot - 0.3, y_top + 0.4), expand = c(0, 0)) +
  coord_cartesian(clip = "off") +
  labs(
    title = "What Thessaly sells abroad, and to whom",
    subtitle = glue::glue(
      "Exports of the Region of Thessaly reached <b>€2.24 billion</b> in 2025, up 9.8% on 2024, with a trade surplus of €986 million. ",
      "<span style='color:#C08A1E'><b>Food</b></span> is 63% of it: dairy alone (mostly feta) is worth €722 million, more than all ",
      "<span style='color:#1C4B52'><b>metals</b></span> together. <b>Germany</b> buys a fifth; the ten biggest markets take two thirds. ",
      "Larissa ships 56% of the total, Magnesia 30%, Trikala 13%, Karditsa 2%.<br>",
      "Links show which products the study names as the main exports to each market. Their widths carry no value: ",
      "product-by-country figures are not published."),
    caption = paste0("Data: ELSTAT 2025 foreign-trade statistics, compiled in ΣΒΘΣΕ (Association of Industries of Thessaly & Central Greece), ",
                     "«Στοιχεία εξαγωγών Περιφέρειας Θεσσαλίας, έτος 2025», July 2026. Top-10 product categories (CN chapters) and top-10 markets; ",
                     "country values are given as approximate in the study. Bulgaria (€70 m) has only generic product mentions and no link. Chart: Loukas Theodosiou")
  ) +
  theme_void(base_family = "Fira Sans") +
  theme(plot.background = element_rect(fill = "white", colour = NA),
        plot.title = element_text(family = "Oswald", face = "bold", size = 28, colour = "#191713", margin = margin(b = 6)),
        plot.subtitle = element_textbox_simple(size = 10.5, colour = "#4a463d", lineheight = 1.4, margin = margin(b = 18)),
        plot.caption = element_textbox_simple(size = 7.6, colour = "#8b8474", lineheight = 1.3, margin = margin(t = 14)),
        plot.margin = margin(22, 28, 16, 28))
ggsave("out/t14_thessaly_exports.png", p, width = 14, height = 8.5, dpi = 200, device = ragg::agg_png, bg = "white")
message("Done: out/t14_thessaly_exports.png")
