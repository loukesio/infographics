# Day 30 · Pen & paper — a printable A4 drawing template of Thessaly (Loukas draws the map himself)
# This script does NOT make the map: it makes the paper. Faint region outline, very light municipality borders,
# the 9 main towns as small dots, a 10 km grid in Greek Grid (EGSA87) metres, a title strip and a blank
# box for his own title / legend. Print at 100 % (no "fit to page") so the scale bar stays true.
#
# Data: Eurostat GISCO NUTS-2 2021 (EL61 border) https://gisco-services.ec.europa.eu/distribution/v2/nuts/
#       GADM 4.1 level 3 (25 Kallikratis municipalities) https://gadm.org
#       Town centres from m30_base.R (m30_towns)
# Caveats: the Sporades are left out to give the mainland the whole sheet.
source("30daymap/R/m30_base.R")

# ---- 1. data ----
reg  <- m30_region(TRUE)
muni <- m30_municipalities() |> filter(unit != "Sporades")
bb   <- st_bbox(reg)
message(sprintf("Mainland Thessaly bbox: %.0f x %.0f km", (bb$xmax - bb$xmin) / 1000, (bb$ymax - bb$ymin) / 1000))

# map frame: snap to whole 10 km grid lines with a 10 km margin
g <- 10000
fx <- c(floor(bb$xmin / g) * g - g, ceiling(bb$xmax / g) * g + g)
fy <- c(floor(bb$ymin / g) * g - g, ceiling(bb$ymax / g) * g + g)
# stretch the grid north and south so it fills the A4 sheet (free squares for a hand-drawn title, inset or key)
ny <- 25; extra <- ny - diff(fy) / g
fy <- fy + c(-floor(extra / 2), ceiling(extra / 2)) * g
message(sprintf("Grid: %d x %d squares of 10 km", diff(fx) / g, diff(fy) / g))
tw <- m30_towns |> mutate(x = st_coordinates(m30_towns)[, 1], y = st_coordinates(m30_towns)[, 2])

# ---- 2. sheet ----
ink <- M30$ink; faint <- "#C9C9C9"
grid_x <- seq(fx[1], fx[2], g); grid_y <- seq(fy[1], fy[2], g)
p <- ggplot() +
  geom_vline(xintercept = grid_x, colour = "#ECECEC", linewidth = 0.18) +
  geom_hline(yintercept = grid_y, colour = "#ECECEC", linewidth = 0.18) +
  geom_sf(data = muni, fill = NA, colour = "#E2E2E2", linewidth = 0.2) +
  geom_sf(data = reg, fill = NA, colour = faint, linewidth = 0.45) +
  geom_point(data = tw, aes(x, y), size = 0.9, colour = "#8A8A8A") +
  geom_text(data = tw, aes(x, y, label = name), family = "Fira Sans Condensed", size = 2.5,
            colour = "#9A9A9A", nudge_y = 3200) +
  # grid coordinates on the edges, in km of the Greek Grid
  annotate("text", x = grid_x[seq(1, length(grid_x), 5)], y = fy[1] - 3500,
           label = grid_x[seq(1, length(grid_x), 5)] / 1000, family = "Fira Sans Condensed",
           size = 2, colour = "#B0B0B0") +
  annotate("text", x = fx[1] - 3500, y = grid_y[seq(1, length(grid_y), 5)],
           label = grid_y[seq(1, length(grid_y), 5)] / 1000, family = "Fira Sans Condensed",
           size = 2, colour = "#B0B0B0", hjust = 1) +
  m30_scalebar(20, x = fx[2] - 26000, y = fy[1] + 5000, bbox = bb, col = "#9A9A9A") +
  annotate("text", x = fx[2] - 4000, y = fy[2] - 4000, label = "N ↑", family = "Fira Sans Condensed",
           size = 3, colour = "#9A9A9A", hjust = 1) +
  coord_sf(crs = CRS_GR, xlim = fx, ylim = fy, expand = FALSE, clip = "off") +
  m30_labs(30, "Pen & paper",
           title = "<span style='color:#C9C9C9'>Your title here, by hand</span>",
           subtitle = "Drawing sheet for Thessaly. Grey lines are only a guide: one square = 10 km. Draw over them.",
           source = "Eurostat GISCO NUTS 2021 border · GADM 4.1 municipalities · Greek Grid (EGSA87) in km",
           accent = "#1E1E1E", extra = "Print at 100 %") +
  labs(caption = NULL) +
  theme_m30(base = 11) +
  theme(plot.title = element_markdown(family = "Oswald", size = 26, colour = "#C9C9C9",
                                      margin = margin(22, 0, 6, 0)),
        plot.margin = margin(36, 40, 6, 40))

# blank strip under the map for his own key / notes
key <- ggplot() +
  annotate("rect", xmin = 0, xmax = 1, ymin = 0, ymax = 1, fill = NA, colour = "#DADADA", linewidth = 0.3) +
  annotate("text", x = 0.012, y = 0.9, label = "KEY / NOTES", hjust = 0, vjust = 1,
           family = "Fira Sans Condensed", size = 2.6, colour = "#B0B0B0") +
  annotate("segment", x = 0.012, xend = 0.988, y = c(0.55, 0.3), yend = c(0.55, 0.3),
           colour = "#EEEEEE", linewidth = 0.25) +
  annotate("text", x = 0.988, y = 0.1, label = "drawn by ____________________   date ________",
           hjust = 1, family = "Fira Sans Condensed", size = 2.6, colour = "#B0B0B0") +
  scale_x_continuous(expand = c(0, 0)) + scale_y_continuous(expand = c(0, 0)) +
  labs(caption = "<b>Data</b> Eurostat GISCO NUTS 2021 border · GADM 4.1 municipalities (25) · grid = Greek Grid EGSA87, labels in km &nbsp;·&nbsp; <b>Map</b> drawn by hand by Loukas Theodosiou") +
  theme_void() + theme(plot.margin = margin(14, 40, 30, 40), plot.caption.position = "plot",
                       plot.caption = element_textbox_simple(family = "Fira Sans", size = 7.5, colour = M30$soft,
                                                             margin = margin(8, 0, 0, 0)))

out <- patchwork::wrap_plots(p, key, ncol = 1, heights = c(1, 0.11)) &
  theme(plot.background = element_rect(fill = "white", colour = NA))

# ---- 3. save: A4 portrait PDF (vector, for printing) + PNG ----
w <- 210 / 25.4; h <- 297 / 25.4
pdf_f <- file.path(M30_OUT, "day30_pen_paper_template.pdf")
ggsave(pdf_f, out, width = w, height = h, device = cairo_pdf)
ggsave(file.path(M30_OUT, "day30_pen_paper_template.png"), out, width = w, height = h, dpi = 300,
       bg = "white", device = ragg::agg_png)
message("saved ", pdf_f)
