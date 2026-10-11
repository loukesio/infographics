# radial_fan(): spren9er-style "fan" chart
# Inner bubbles = groups (sized by total), every item sits on the rim and is linked
# to its group by a curved line. Inspired by spren9er's CRAN packages plot (#TidyTuesday 2019-46).
library(tidyverse)
library(ggraph)
library(igraph)

radial_fan <- function(items, groups_order, colours, title, subtitle, caption,
                       label_size = 2.1, edge_alpha = 0.35, group_label_fmt = scales::comma,
                       unit = "", leaf_max = 6, hub_fill = 0.32, show_leaf_labels = TRUE) {
  # items: tibble(item, group, value)
  items <- items |>
    mutate(group = factor(group, groups_order)) |>
    arrange(group, desc(value)) |>
    mutate(item_id = paste0(group, "::", item))

  grp <- items |> summarise(total = sum(value), n = n(), .by = group)

  edges <- bind_rows(
    tibble(from = "root", to = as.character(grp$group)),
    tibble(from = as.character(items$group), to = items$item_id)
  )
  verts <- bind_rows(
    tibble(name = "root", group = NA, value = NA, level = 0, label = NA),
    tibble(name = as.character(grp$group), group = as.character(grp$group),
           value = grp$total, level = 1, label = as.character(grp$group)),
    tibble(name = items$item_id, group = as.character(items$group),
           value = items$value, level = 2, label = items$item)
  )
  g <- graph_from_data_frame(edges, vertices = verts)
  lay <- create_layout(g, layout = "dendrogram", circular = TRUE)

  # hubs: real circles (area ~ total), placed towards their leaves, then pushed apart
  h <- which(lay$level == 1)
  v <- lay$value[h]
  r <- sqrt(hub_fill * 0.80^2 / sum(v)) * sqrt(v)
  ang <- atan2(lay$y[h], lay$x[h])
  x0 <- 0.42 * cos(ang); y0 <- 0.42 * sin(ang)
  px <- x0; py <- y0
  for (it in 1:3000) {
    for (i in seq_along(h)) for (j in seq_along(h)) if (i < j) {
      dx <- px[j] - px[i]; dy <- py[j] - py[i]; d <- sqrt(dx^2 + dy^2) + 1e-9
      ov <- r[i] + r[j] + 0.015 - d
      if (ov > 0) {
        w <- r[j]^2 / (r[i]^2 + r[j]^2)          # small circles move more
        px[i] <- px[i] - dx / d * ov * w;       py[i] <- py[i] - dy / d * ov * w
        px[j] <- px[j] + dx / d * ov * (1 - w); py[j] <- py[j] + dy / d * ov * (1 - w)
      }
    }
    px <- px + 0.01 * (x0 - px); py <- py + 0.01 * (y0 - py)   # gentle pull home
    rr <- sqrt(px^2 + py^2); lim <- 0.86 - r                    # stay inside the rim
    out <- rr > lim; px[out] <- px[out] / rr[out] * lim[out]; py[out] <- py[out] / rr[out] * lim[out]
  }
  lay$x[h] <- px; lay$y[h] <- py; lay$r <- NA; lay$r[h] <- r

  leaves <- as_tibble(lay) |> filter(level == 2) |>
    mutate(angle = atan2(y, x) * 180 / pi,
           hjust = if_else(x < 0, 1, 0),
           angle = if_else(x < 0, angle + 180, angle),
           lx = x * 1.04, ly = y * 1.04)
  hubs <- as_tibble(lay) |> filter(level == 1)

  ggraph(lay) +
    geom_edge_diagonal(aes(filter = node1.level == 1, edge_colour = node2.group),
                       edge_alpha = edge_alpha, edge_width = 0.25, show.legend = FALSE) +
    ggforce::geom_circle(data = hubs, aes(x0 = x, y0 = y, r = r, fill = group),
                         colour = NA, alpha = 0.72, show.legend = FALSE, inherit.aes = FALSE) +
    geom_point(data = leaves, aes(x, y, size = value, colour = group), alpha = 0.9,
               show.legend = FALSE) +
    { if (show_leaf_labels)
        geom_text(data = leaves, aes(lx, ly, label = label, angle = angle, hjust = hjust),
                  size = label_size, family = "Fira Sans Condensed", colour = "#495057") } +
    # label size follows bubble size so text always fits inside
    geom_text(data = hubs, aes(x, y, label = label),
              size = pmin(4.6, hubs$r * 330 / pmax(nchar(hubs$label), 5)),
              family = "Oswald", colour = "#1F2933", vjust = -0.2) +
    geom_text(data = hubs, aes(x, y, label = paste0(group_label_fmt(value), unit)),
              size = pmin(3, hubs$r * 26),
              family = "Fira Sans", colour = "#1F2933", vjust = 1.4) +
    guides(size = "none") +
    scale_size_area(max_size = leaf_max) +
    scale_colour_manual(values = colours, aesthetics = c("colour", "fill", "edge_colour")) +
    coord_equal(clip = "off", xlim = c(-1.25, 1.25), ylim = c(-1.25, 1.25)) +
    labs(title = title, subtitle = subtitle, caption = caption) +
    theme_void() +
    theme(
      plot.background = element_rect(fill = "white", colour = NA),
      plot.title    = element_text(family = "Oswald", size = 22, hjust = 0.5, colour = "#1F2933"),
      plot.subtitle = element_text(family = "Fira Sans", size = 11, hjust = 0.5, colour = "#495057",
                                   lineheight = 1.25, margin(6, 0, 30, 0)),
      plot.caption  = element_text(family = "Fira Sans", size = 8, colour = "#ADB5BD"),
      plot.margin   = margin(24, 24, 16, 24)
    )
}
