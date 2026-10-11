# Europe: Social unrest & armed violence (ACLED, aggregated data)
# Remake of J. Luengo-Cabrera's Africa map
#
# Data: ACLED aggregated data for Europe (weekly, by Admin 1 region)
# Save it next to this script as "acled_europe.csv" (or .xlsx)

library(tidyverse)
library(sf)
library(rnaturalearth)
library(ggrepel)
library(patchwork)

# ---- 1. Data -------------------------------------------------------------
file <- "data/acled_europe.csv"   # change to "acled_europe.xlsx" if needed

raw <- if (grepl("xlsx$", file)) readxl::read_excel(file) else read_csv(file, show_col_types = FALSE)

# make column names consistent: "ADMIN1" / "admin 1" -> "admin1"
names(raw) <- tolower(gsub(" ", "", names(raw)))

acled <- raw |>
  mutate(
    year = lubridate::year(as.Date(week)),
    group = case_when(
      event_type %in% c("Protests", "Riots") ~ "Social unrest",
      event_type %in% c("Battles", "Violence against civilians",
                        "Explosions/Remote violence") ~ "Armed violence"
    )
  ) |>
  filter(!is.na(group))

cols <- c("Social unrest" = "#3B82C4", "Armed violence" = "#B5223B")

# events per region (one circle per Admin 1 region)
by_loc <- acled |>
  summarise(n = sum(events),
            .by = c(group, admin1, centroid_latitude, centroid_longitude)) |>
  filter(n > 0) |>
  arrange(n)  # big circles drawn last

# events per year (for the bar chart)
by_year <- acled |> summarise(n = sum(events), .by = c(year, group))

# biggest hotspots to label
labels <- by_loc |> slice_max(n, n = 6, by = group)

# ---- 2. Map --------------------------------------------------------------
world <- ne_countries(scale = "medium", returnclass = "sf")

map <- ggplot() +
  geom_sf(data = world, fill = "grey88", colour = "grey55", linewidth = 0.25) +
  geom_point(
    data = by_loc,
    aes(centroid_longitude, centroid_latitude, size = n, colour = group),
    alpha = 0.35, stroke = 0
  ) +
  geom_text_repel(
    data = labels,
    aes(centroid_longitude, centroid_latitude, label = admin1),
    size = 3, fontface = "bold", colour = "grey15",
    min.segment.length = 0, segment.colour = "grey30",
    bg.colour = "white", bg.r = 0.15, seed = 1
  ) +
  scale_colour_manual(values = cols, guide = "none") +
  scale_size_area(max_size = 22, name = "Events by region",
                  labels = scales::label_number(big.mark = " ")) +
  coord_sf(xlim = c(-25, 45), ylim = c(34, 71), expand = FALSE) +
  theme_void() +
  theme(
    panel.background = element_rect(fill = "white", colour = NA),
    legend.position = c(0.92, 0.12),
    legend.title = element_text(size = 9, colour = "grey30")
  )

# ---- 3. Bar chart --------------------------------------------------------
bars <- ggplot(by_year, aes(year, n, fill = group)) +
  geom_col(width = 0.7) +
  scale_fill_manual(values = cols, guide = "none") +
  scale_y_continuous(labels = scales::label_number(big.mark = " "),
                     expand = expansion(mult = c(0, 0.05))) +
  labs(x = NULL, y = NULL, title = "Annual total") +
  theme_minimal(base_size = 9) +
  theme(
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank(),
    plot.background = element_rect(fill = "white", colour = NA),
    plot.title = element_text(size = 9, colour = "grey30")
  )

# ---- 4. Combine ----------------------------------------------------------
yrs <- range(acled$year)

final <- map +
  inset_element(bars, left = 0.01, bottom = 0.02, right = 0.30, top = 0.38) +
  plot_annotation(
    title = "Europe",
    subtitle = paste0(
      "<span style='color:#3B82C4'>Social unrest*</span> & ",
      "<span style='color:#B5223B'>Armed violence**</span><br>",
      "Reported incidents (", yrs[1], "-", yrs[2], ") · Data: ACLED"
    ),
    caption = "*Protests & riots   **Battles, violence against civilians & explosions",
    theme = theme(
      plot.title = element_text(size = 24, face = "bold", colour = "grey30"),
      plot.subtitle = ggtext::element_markdown(size = 13, colour = "grey40"),
      plot.caption = element_text(size = 8, colour = "grey50", hjust = 0)
    )
  )

ggsave("out/x1_europe_acled_map.png", final, width = 10, height = 11, dpi = 300, bg = "white")
