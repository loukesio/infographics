# The flavours of three genres — radar "spaghetti" chart, style after Jake Lawlor's "The Flavors of 3 Playlists"
# Data: Spotify audio features via spotifyr, #TidyTuesday 2020-01-21 (32,833 songs from genre playlists)
library(tidyverse)
library(patchwork)
library(ggtext)

songs <- read_csv("data/spotify_songs.csv", show_col_types = FALSE) |>
  distinct(track_id, .keep_all = TRUE)

feat <- c(danceability = "Danceable", energy = "Energetic", valence = "Happy", loudness = "Loud",
          tempo = "Fast", acousticness = "Acoustic", instrumentalness = "Instrumental", speechiness = "Wordy")

genres <- c(rock = "Rock", rap = "Rap", edm = "EDM")
cols   <- c(Rock = "#C994D6", Rap = "#B5508F", EDM = "#F5A882")

# every feature as a percentile among ALL songs (0 = lowest, 1 = highest), so axes are comparable
long <- songs |>
  select(track_id, playlist_genre, all_of(names(feat))) |>
  mutate(across(all_of(names(feat)), \(x) percent_rank(x))) |>
  filter(playlist_genre %in% names(genres)) |>
  mutate(genre = factor(genres[playlist_genre], levels = genres)) |>
  pivot_longer(all_of(names(feat)), names_to = "f", values_to = "v") |>
  mutate(k = match(f, names(feat)), lab = feat[f])

n_ax  <- length(feat)
theta <- \(k) 2 * pi * (k - 1) / n_ax                 # first axis straight up, clockwise
to_xy <- \(df) df |> mutate(x = v * sin(theta(k)), y = v * cos(theta(k)))

set.seed(2026)
sample_ids <- long |> distinct(genre, track_id) |> slice_sample(n = 35, by = genre)
lines <- long |> semi_join(sample_ids, by = c("genre", "track_id")) |> to_xy() |>
  arrange(genre, track_id, k) |>
  group_by(genre, track_id) |> group_modify(\(d, ...) bind_rows(d, d[1, ])) |> ungroup()   # close polygon

means <- long |> summarise(v = mean(v), .by = c(genre, f, k, lab)) |> to_xy() |> arrange(genre, k) |>
  group_by(genre) |> group_modify(\(d, ...) bind_rows(d, d[1, ])) |> ungroup()

rings <- expand_grid(r = c(0.25, 0.5, 0.75, 1), a = seq(0, 2 * pi, length.out = 200)) |>
  mutate(x = r * sin(a), y = r * cos(a))
spokes <- tibble(k = 1:n_ax) |> mutate(x = 1.05 * sin(theta(k)), y = 1.05 * cos(theta(k)))
axlabs <- tibble(k = 1:n_ax, lab = feat) |>
  mutate(x = 1.17 * sin(theta(k)), y = 1.17 * cos(theta(k)),
         hjust = case_when(abs(x) < 0.1 ~ 0.5, x > 0 ~ 0, TRUE ~ 1))

base <- function(show_labels = TRUE) {
  list(
    geom_path(data = rings, aes(x, y, group = r), colour = "#E6E6E6", linewidth = 0.6, inherit.aes = FALSE),
    geom_segment(data = spokes, aes(0, 0, xend = x, yend = y), colour = "#E6E6E6", linewidth = 0.6, inherit.aes = FALSE),
    if (show_labels) geom_text(data = axlabs, aes(x, y, label = lab, hjust = hjust), family = "Fira Sans Light",
                               size = 5, colour = "#3E4C59", inherit.aes = FALSE),
    scale_colour_manual(values = cols, aesthetics = c("colour", "fill"), guide = "none"),
    coord_equal(clip = "off"),
    theme_void()
  )
}

main <- ggplot() + base() +
  geom_polygon(data = lines, aes(x, y, group = interaction(genre, track_id), colour = genre),
               fill = NA, linewidth = 0.3, alpha = 0.4) +
  geom_polygon(data = means, aes(x, y, group = genre, fill = genre), alpha = 0.3, colour = NA) +
  geom_polygon(data = means, aes(x, y, group = genre, colour = genre), fill = NA, linewidth = 2.4) +
  xlim(-1.45, 1.45) + ylim(-1.25, 1.3)

small <- map(genres, \(g) {
  ggplot() + base(show_labels = FALSE) +
    geom_polygon(data = filter(lines, genre == g), aes(x, y, group = track_id, colour = genre),
                 fill = NA, linewidth = 0.25, alpha = 0.7) +
    geom_polygon(data = filter(means, genre == g), aes(x, y, fill = genre), alpha = 0.25, colour = NA) +
    geom_polygon(data = filter(means, genre == g), aes(x, y, colour = genre), fill = NA, linewidth = 1.4) +
    labs(title = g) +
    theme(plot.title = element_text(family = "Fira Sans", size = 13, hjust = 0.5, colour = cols[[g]]))
})

sub <- paste0("<span style='color:", cols, "'>", names(cols), "</span>", collapse = " &nbsp; ")

p <- main / wrap_plots(small, nrow = 1) +
  plot_layout(heights = c(3.2, 1)) +
  plot_annotation(
    title = "The Flavours of 3 Genres",
    subtitle = sub,
    caption = "Thin lines: 35 random songs per genre. Thick line: genre average. Each axis is a percentile among all 32,000 songs (centre = lowest, edge = highest).<br>Data: Spotify audio features via spotifyr, #TidyTuesday 2020-01-21 · Chart: Loukas Theodosiou · style after Jake Lawlor",
    theme = theme(
      plot.background = element_rect(fill = "white", colour = NA),
      plot.title = element_text(family = "Fira Sans Light", size = 40, hjust = 0.5, colour = "#111111"),
      plot.subtitle = element_markdown(family = "Fira Sans", face = "bold", size = 24, hjust = 0.5,
                                       margin = margin(4, 0, 0, 0)),
      plot.caption = element_textbox_simple(family = "Fira Sans", size = 8.5, colour = "#495057",
                                            halign = 0.5, lineheight = 1.3, margin = margin(t = 10)),
      plot.margin = margin(24, 24, 16, 24)
    )
  )

ggsave("out/t9_music_flavors.png", p, width = 9, height = 12, dpi = 200, device = ragg::agg_png)
