# Larissa town hall 1975–2023: mayors timeline + the deciding vote of every election since 1998
library(tidyverse)
library(ggtext)
library(patchwork)

# ---- data -----------------------------------------------------------------------------------
# Mayors (eleftheria.gr, "Οι δήμαρχοι της Λάρισας από το 1881"); the source lists 1978–1981 and 1980–1994,
# which overlap, so the hand-over is drawn at 1980.
mayors <- tribble(
  ~mayor,              ~from, ~to,  ~col,
  "Blanas",             1975, 1978, "#ADB5BD",
  "Chondronasios",      1978, 1980, "#868E96",
  "Lamproulis",         1980, 1994, "#5C5F66",
  "Kaffes",             1994, 1998, "#2B8A3E",
  "Tzanakoulis",        1998, 2014, "#3B5BDB",
  "Kalogiannis",        2014, 2023, "#0B7285",
  "Mamakos",            2023, 2026.8, "#1C4E9C"
)

# Deciding round of each election (onlarissa.gr 2019 retrospective; Region of Thessaly results for 2014–2023)
dec <- tribble(
  ~year,  ~round,       ~cand,          ~camp,   ~pct,
  1998, "runoff",       "Kaffes",       "left",  48.5,
  1998, "runoff",       "Tzanakoulis",  "right", 51.5,
  2002, "runoff",       "Kaffes",       "left",  44.6,
  2002, "runoff",       "Tzanakoulis",  "right", 55.4,
  2006, "1st round",    "Sapkas",       "left",  40.10,
  2006, "1st round",    "Others",       "other", 17.38,
  2006, "1st round",    "Tzanakoulis",  "right", 42.52,
  2010, "runoff",       "Sapkas",       "left",  49.77,
  2010, "runoff",       "Tzanakoulis",  "right", 50.23,
  2014, "runoff",       "Kalogiannis",  "left",  54.54,
  2014, "runoff",       "Karalariotou", "right", 45.46,
  2019, "runoff",       "Kalogiannis",  "left",  57.34,
  2019, "runoff",       "Karalariotou", "right", 42.66,
  2023, "1st round",    "Krikis",       "kke",    8.92,
  2023, "1st round",    "Kalogiannis",  "left",  37.13,
  2023, "1st round",    "Vaioulis",     "other",  2.82,
  2023, "1st round",    "Mamakos",      "right", 51.14
)
winner <- c(`1998` = "Tzanakoulis", `2002` = "Tzanakoulis", `2006` = "Tzanakoulis", `2010` = "Tzanakoulis",
            `2014` = "Kalogiannis", `2019` = "Kalogiannis", `2023` = "Mamakos")

cand_col <- c(Kaffes = "#2B8A3E", Sapkas = "#51CF66", Kalogiannis = "#0B7285", Tzanakoulis = "#3B5BDB",
              Karalariotou = "#748FFC", Mamakos = "#1C4E9C", Krikis = "#C92A2A",
              Others = "#DEE2E6", Vaioulis = "#DEE2E6")
camp_col <- c(left = "#40A9A0", right = "#4C6EF5", other = "#CED4DA", kke = "#E03131")
camp_ord <- c("kke", "left", "other", "right")

# ---- timeline -------------------------------------------------------------------------------
tl <- ggplot(mayors) +
  geom_rect(aes(xmin = from, xmax = to, ymin = 0, ymax = 1, fill = I(col)), colour = "white", linewidth = 0.8) +
  geom_text(aes(x = (from + to) / 2, y = 0.5, label = if_else(to - from >= 4, mayor, "")),
            family = "Oswald", colour = "white", size = 3.8) +
  geom_text(data = filter(mayors, to - from < 4) |> mutate(yy = c(-0.3, -0.75, -0.3)),
            aes(x = (from + to) / 2, y = yy, label = mayor),
            family = "Fira Sans Condensed", colour = "#495057", size = 2.8) +
  annotate("text", x = 1974.6, y = 0.5, label = "Mayor", hjust = 1, family = "Oswald", size = 4, colour = "#1F2933") +
  scale_x_continuous(breaks = seq(1975, 2025, 5), limits = c(1970, 2027), expand = c(0, 0), position = "top") +
  coord_cartesian(clip = "off", ylim = c(-0.95, 1)) +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.x = element_text(size = 8.5, colour = "#868E96", margin = margin(b = 4)))

# ---- deciding votes: ribbon bars --------------------------------------------------------------
yrs <- sort(unique(dec$year))
bar_h <- 0.6
segs <- dec |>
  mutate(row = match(year, yrs), y = -row, ord = match(camp, camp_ord)) |>
  arrange(row, ord) |>
  group_by(year) |>
  mutate(xmax = cumsum(pct) / sum(pct) * 100, xmin = lag(xmax, default = 0)) |>
  ungroup() |>
  mutate(win = cand == winner[as.character(year)])

ribbons <- segs |>
  select(row, camp, xmin, xmax, y) |>
  inner_join(segs |> select(row, camp, xmin, xmax, y) |> mutate(row = row - 1),
             by = c("row", "camp"), suffix = c("", "_n")) |>
  mutate(id = paste(row, camp), col = camp_col[camp]) |>
  rowwise() |>
  reframe(id, col,
          x  = c(xmin, xmax, xmax_n, xmin_n),
          yy = c(y - bar_h / 2, y - bar_h / 2, y_n + bar_h / 2, y_n + bar_h / 2))

labs_df <- segs |>
  filter(pct >= 8) |>
  mutate(lab = if_else(pct >= 15,
                       glue::glue("<b>{cand}</b> {sprintf('%.1f', pct)}%{if_else(win, ' ✓', '')}"),
                       glue::glue("{sprintf('%.0f', pct)}%")))

ylabs <- tibble(year = yrs, row = seq_along(yrs)) |>
  left_join(distinct(dec, year, round), by = "year") |>
  mutate(lab = glue::glue("<span style='font-family:Oswald;font-size:12pt;color:#1F2933'>{year}</span><br><span style='color:#868E96;font-size:8pt'>{round}</span>"))

rb <- ggplot() +
  geom_polygon(data = ribbons, aes(x, yy, group = id, fill = I(col)), alpha = 0.22) +
  geom_rect(data = segs, aes(xmin = xmin, xmax = xmax, ymin = y - bar_h / 2, ymax = y + bar_h / 2,
                             fill = I(cand_col[cand])), colour = "white", linewidth = 0.4) +
  geom_richtext(data = labs_df, aes((xmin + xmax) / 2, y, label = lab,
                                    colour = I(if_else(cand %in% c("Others", "Vaioulis"), "#495057", "white"))),
                family = "Fira Sans Condensed", size = 3.3, fill = NA, label.colour = NA) +
  geom_richtext(data = ylabs, aes(x = -1.5, y = -row, label = lab), hjust = 1, family = "Fira Sans",
                fill = NA, label.colour = NA, lineheight = 1) +
  geom_vline(xintercept = 50, linetype = "22", linewidth = 0.4, colour = "#1F2933") +
  annotate("richtext", x = 51, y = -4 - 0.32, hjust = 0, vjust = 1, family = "Fira Sans", size = 3,
           colour = "#1F2933", fill = NA, label.colour = NA,
           label = "<b>2010: decided by 217 ballots</b>") +
  scale_x_continuous(breaks = seq(0, 100, 25), labels = paste0(seq(0, 100, 25), "%"), expand = c(0, 0)) +
  coord_cartesian(xlim = c(0, 100), clip = "off") +
  theme_void(base_family = "Fira Sans") +
  theme(axis.text.x = element_text(size = 8.5, colour = "#ADB5BD", margin = margin(t = 4)),
        plot.margin = margin(0, 0, 0, 70))

p <- tl / rb + plot_layout(heights = c(0.9, 7)) +
  plot_annotation(
    title = "Fifty Years of Larissa's Town Hall",
    subtitle = glue::glue(
      "Top: every elected mayor since the fall of the junta. Bottom: the round that decided each election since 1998.<br>",
      "Power has swung between a <b style='color:{camp_col['left']}'>centre-left</b> and a <b style='color:{camp_col['right']}'>centre-right</b> camp, ",
      "often by a hair: in 2010 Tzanakoulis kept the town hall by 50.2% to 49.8%. Ribbons follow each camp from one election to the next."),
    caption = "Camps as described by the sources: Kaffes, Sapkas = PASOK-backed; Kalogiannis = centre-left coalition (SYRIZA-backed in 2023); Tzanakoulis = ND-backed (1998); Karalariotou = centre-right; Mamakos = ND-backed.<br>Krikis = Laiki Syspeirosi (KKE). Mayors before 1994 shown in grey: party backing not stated in the source. Results before 2014 only exist online for the deciding round. 2006 'Others' = remaining first-round candidates combined.<br>Sources: eleftheria.gr (mayors since 1881), onlarissa.gr (elections 1998–2014), Region of Thessaly results site (2014–2023), protothema.gr · Chart: Loukas Theodosiou",
    theme = theme(
      plot.background = element_rect(fill = "white", colour = NA),
      plot.title = element_text(family = "Oswald", size = 26, colour = "#1F2933"),
      plot.subtitle = element_textbox_simple(family = "Fira Sans", size = 10.5, colour = "#495057",
                                             lineheight = 1.35, margin = margin(6, 0, 14, 0)),
      plot.caption = element_textbox_simple(family = "Fira Sans", size = 7.2, colour = "#ADB5BD",
                                            lineheight = 1.3, margin = margin(t = 12)),
      plot.margin = margin(20, 24, 14, 20)
    )
  )

ggsave("out/t8_larissa_mayors_history.png", p, width = 9.5, height = 9.5, dpi = 220, device = ragg::agg_png)
