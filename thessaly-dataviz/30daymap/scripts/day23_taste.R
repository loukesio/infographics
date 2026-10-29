# Day 23 · Taste — Thessaly's protected foods and drinks: EU geographical indications (PDO / PGI) whose
# specified area covers part of Thessaly. A count map (how many GIs touch each municipality), a strip of the
# larder by kind, and one small "label" map per product.
#
# Data
#   EU eAmbrosia register, downloaded 2026-10-29 through its public API
#     list:    https://webgate.ec.europa.eu/eambrosia-api/api/geographical-indications?size=1000&page=0..3
#     details: https://webgate.ec.europa.eu/eambrosia-api/api/v2/geographical-indications/<giIdentifier>
#   The specification of every Greek GI with an attached file was read (pdftools) and searched for Thessaly place
#   names; the area of each product was typed into 30daymap/data/day23_gi_thessaly.csv with its source URL.
#   For 7 GIs eAmbrosia has no attached file: the area comes from the Official Journal / EUR-Lex single document
#   (Firiki Piliou, Arnaki & Katsikaki Elassonas, Kashkavali Pindou), the AADE technical files (Tsipouro of Thessaly,
#   Tsipouro of Tyrnavos), the EU Ouzo technical file and, for the Tyrnavos wine (broken file), the ministry's
#   single document. Those were read through web-search excerpts because EUR-Lex / minagric / AADE block scripts.
#   Municipalities: GADM 4.1 (m30_municipalities). Villages named in specifications placed with OSM place nodes.
# Caveats
#   * "Touches Thessaly" = the specified area includes at least part of the region. Feta, Kasseri, Manouri, Batzos,
#     Galotyri and Ouzo cover much more than Thessaly.
#   * Village-level areas are drawn as the whole municipality, lighter ("part of"). Altitude limits are not drawn.
#   * Katiki Domokou (Fthiotida) has a scanned specification with no text; not counted (its name area is outside).
source("30daymap/R/m30_base.R")
suppressPackageStartupMessages({ library(patchwork) })

# ---- 1. data ----
gi <- read.csv("30daymap/data/day23_gi_thessaly.csv", encoding = "UTF-8")
mu <- m30_municipalities()
all_mu <- mu$municipality
long <- gi |>
  mutate(muni = ifelse(municipalities == "ALL", paste(all_mu, collapse = ";"), municipalities)) |>
  separate_longer_delim(muni, ";")
stopifnot(all(long$muni %in% all_mu))
n_gi <- nrow(gi)
by_kind <- count(gi, category, type)
cnt <- long |> count(muni, name = "n")
mu <- mu |> left_join(cnt, by = c("municipality" = "muni")) |> mutate(n = replace_na(n, 0))
top <- mu |> st_drop_geometry() |> filter(n == max(n)) |> arrange(municipality)
top_txt <- if (nrow(top) > 1) paste(paste(head(top$municipality, -1), collapse = ", "), "and", tail(top$municipality, 1)) else top$municipality
low <- min(mu$n)
message(sprintf("%d GIs touch Thessaly: %s", n_gi,
                paste(sprintf("%s %s %d", by_kind$category, by_kind$type, by_kind$n), collapse = ", ")))
message(sprintf("GIs per municipality: min %d, max %d (%s)", low, max(mu$n),
                paste(sprintf("%s %d", top$municipality, top$n), collapse = ", ")))

# ---- 2. look ----
acc <- "#7A1F2B"           # wine-red label ink
cream <- "#F4EEE3"
ink <- M30$ink
cat_order <- c("Cheese", "Meat", "Apples", "Table olives", "Wine", "Spirit")
reg <- m30_region(FALSE)
bb <- st_bbox(reg)

# ---- 3. count map ----
pal <- colorRampPalette(c("#F4E6E1", "#D79A97", "#A8474D", acc, "#3E0E16"))(5)
mu <- mu |> mutate(nb = factor(n, sort(unique(n))))
pal <- colorRampPalette(c("#F1DCD6", "#C77E7F", acc, "#3E0E16"))(nlevels(mu$nb))
tw <- m30_towns |> filter(name %in% c("Larissa", "Volos", "Trikala", "Karditsa", "Elassona", "Tyrnavos"))
p_map <- ggplot() +
  geom_sf(data = mu, aes(fill = nb), colour = "white", linewidth = 0.35) +
  geom_sf(data = reg, fill = NA, colour = ink, linewidth = 0.35) +
  geom_sf(data = tw, shape = 21, fill = "white", colour = ink, size = 1.6, stroke = 0.5) +
  shadowtext::geom_shadowtext(data = cbind(st_drop_geometry(tw), st_coordinates(tw)), aes(X, Y, label = name),
                              family = "Fira Sans Condensed", size = 2.9, colour = ink, bg.colour = "white",
                              bg.r = 0.12, nudge_y = 4200) +
  scale_fill_manual(values = setNames(pal, levels(mu$nb)), drop = FALSE, name = "Protected names per municipality",
                    guide = guide_legend(title.position = "top", nrow = 1, keywidth = unit(9, "mm"),
                                         keyheight = unit(3, "mm"), label.position = "bottom")) +
  coord_sf(crs = CRS_GR, expand = FALSE, clip = "off") +
  theme_void(base_family = "Fira Sans") +
  theme(legend.position = "top", legend.justification = "left",
        legend.title = element_text(family = "Fira Sans", size = 8.5, colour = M30$soft),
        legend.text = element_text(family = "Fira Sans Condensed", size = 7.5, colour = M30$soft),
        plot.margin = margin(0, 6, 0, 0))

# ---- 4. the larder by kind: one square per GI ----
kind <- gi |> mutate(category = factor(category, rev(cat_order)), type = factor(type, c("PDO", "PGI"))) |>
  arrange(category, type) |> group_by(category) |> mutate(i = row_number()) |> ungroup()
plural <- c(Cheese = "Cheeses", Meat = "Meats", Apples = "Apples", `Table olives` = "Table olives", Wine = "Wines", Spirit = "Spirits")
kind_lab <- kind |> count(category) |> mutate(category_lab = plural[as.character(category)]) |>
  mutate(lab = sprintf("<span style='font-family:\"Cormorant Garamond\";font-size:15pt'><b>%s</b></span>", category_lab))
p_kind <- ggplot(kind) +
  geom_tile(aes(i, category, fill = type), width = 0.82, height = 0.62, colour = acc, linewidth = 0.5) +
  geom_richtext(data = kind_lab, aes(0.4, category, label = lab), hjust = 1, fill = NA, label.colour = NA,
                colour = ink) +
  geom_text(data = kind_lab, aes(n + 0.75, category, label = n), hjust = 0, family = "Oswald", size = 4,
            colour = acc) +
  scale_fill_manual(values = c(PDO = acc, PGI = "white"), name = NULL,
                    labels = c(PDO = "PDO · protected designation of origin: everything made in the area",
                               PGI = "PGI · protected geographical indication: at least one step in the area")) +
  scale_x_continuous(limits = c(-4.2, 14), expand = c(0, 0)) +
  guides(fill = guide_legend(ncol = 1, keywidth = unit(4, "mm"), keyheight = unit(3, "mm"))) +
  labs(title = "THE LARDER BY KIND") +
  theme_void(base_family = "Fira Sans") +
  theme(legend.position = "bottom", legend.justification = "left",
        legend.text = element_text(family = "Fira Sans Condensed", size = 7.5, colour = M30$soft),
        plot.title = element_text(family = "Fira Sans Condensed", face = "bold", size = 8.5, colour = M30$soft,
                                  margin = margin(0, 0, 4, 0)),
        plot.margin = margin(4, 0, 0, 10))

# ---- 5. one label per product ----
gi <- gi |> mutate(category = factor(category, cat_order),
                   reach = ifelse(municipalities == "ALL", 25, lengths(strsplit(municipalities, ";"))))
ord <- gi |> arrange(category, reach, name_en)
wrap_name <- function(x, w = 14) vapply(x, \(s) {
  if (nchar(s) <= w) return(s)
  sp <- gregexpr(" ", s)[[1]]; k <- sp[which.min(abs(sp - nchar(s) / 2))]
  paste0(substr(s, 1, k - 1), "<br>", substr(s, k + 1, nchar(s)))
}, "")
ord$strip <- sprintf(paste0(
  "<span style='font-family:\"Fira Sans Condensed\";font-size:6.3pt;color:%s'>",
  "<b style='color:%s'>%s</b> · %s</span><br>",
  "<span style='font-family:\"Cormorant Garamond\";font-size:11pt;color:%s'><b>%s</b></span><br>",
  "<span style='font-family:\"Fira Sans\";font-size:6.5pt;color:%s'>%s%s</span>"),
  M30$soft, acc, ord$type, toupper(ord$category), ink, wrap_name(ord$name_en), M30$mute, wrap_name(ord$name_gr, 18),
  "")
ord$strip <- factor(ord$strip, ord$strip)
tiles <- long |> select(gi_id, muni) |> left_join(select(ord, gi_id, strip, cover), by = "gi_id")
tile_geo <- mu |> select(municipality) |> inner_join(tiles, by = c("municipality" = "muni"), relationship = "many-to-many")
base <- tidyr::expand_grid(strip = ord$strip, municipality = mu$municipality) |>
  left_join(select(mu, municipality, geometry), by = "municipality") |> st_as_sf()
p_tiles <- ggplot() +
  geom_sf(data = base, fill = cream, colour = "white", linewidth = 0.08) +
  geom_sf(data = tile_geo, aes(fill = cover), colour = "white", linewidth = 0.08) +
  geom_sf(data = reg, fill = NA, colour = "#B9A99A", linewidth = 0.15) +
  scale_fill_manual(values = c(whole = acc, part = "#C9878A"), name = NULL,
                    labels = c(whole = "Whole municipality\nin the area",
                               part = "Only some of its\nvillages in the area")) +
  guides(fill = guide_legend(ncol = 1, keywidth = unit(5, "mm"), keyheight = unit(8, "mm"))) +
  facet_wrap(~strip, ncol = 7) +
  coord_sf(crs = CRS_GR, expand = FALSE) +
  theme_void(base_family = "Fira Sans") +
  theme(strip.text = element_markdown(hjust = 0, vjust = 1, lineheight = 1.05, margin = margin(3, 0, 6, 0)),
        strip.placement = "outside", panel.spacing.x = unit(5, "mm"), panel.spacing.y = unit(2, "mm"),
        legend.position = "inside", legend.position.inside = c(0.875, 0.09), legend.key.spacing.y = unit(2, "mm"), legend.justification = c(0, 0.5),
        legend.text = element_text(family = "Fira Sans Condensed", size = 8, colour = M30$soft),
        plot.margin = margin(10, 0, 0, 0))
p_tiles <- p_tiles + facet_wrap(~strip, ncol = 7, strip.position = "bottom")

# ---- 6. compose ----
right <- p_kind
top_row <- p_map + right + plot_layout(widths = c(1.25, 1))
p <- (top_row / p_tiles) + plot_layout(heights = c(1, 1.75)) +
  plot_annotation(theme = theme_m30()) &
  theme(plot.background = element_rect(fill = M30$paper, colour = NA))
p <- p + plot_annotation(
  # series tag on top of the title (patchwork has no per-plot tag here)
  title = sprintf(paste0("<span style='font-family:\"Fira Sans Condensed\";font-size:11pt;color:%s;font-weight:normal'>",
                         "#30DAYMAPCHALLENGE 2026 &nbsp;·&nbsp; DAY 23 &nbsp;·&nbsp; <b style='color:%s'>TASTE</b></span><br>",
                         "%d protected foods and drinks<br>carry a Thessaly address"),
                  M30$soft, acc, n_gi),
  subtitle = sprintf(paste0(
    "EU geographical indications whose official area covers part of Thessaly: %d wines, %d cheeses, %d spirits, ",
    "%d meats, %d apples and %d table olive. Six reach far beyond the region (Feta, Ouzo…); the rest are Thessaly's own. ",
    "Every municipality is covered by at least %d; <b style='color:%s'>%s count %d</b>."),
    sum(gi$category == "Wine"), sum(gi$category == "Cheese"), sum(gi$category == "Spirit"),
    sum(gi$category == "Meat"), sum(gi$category == "Apples"), sum(gi$category == "Table olives"),
    low, acc, top_txt, top$n[1]),
  caption = paste0(
    "<b>Data</b> EU eAmbrosia register (API, 2026-10-29) and the product specifications filed there; for GIs without a ",
    "file: Official Journal / EUR-Lex single documents, AADE spirit technical files, EU Ouzo technical file · ",
    "GADM 4.1 municipalities · villages placed with © OpenStreetMap contributors &nbsp;·&nbsp; Altitude limits in the specifications are not drawn &nbsp;·&nbsp; <b>Map</b> Loukas Theodosiou · #rstats ggplot2"),
  theme = theme_m30() + theme(plot.title = element_markdown(family = "Oswald", size = 32, lineheight = 1.02,
                                                            margin = margin(4, 0, 8, 0)))
)
m30_save(p, 23, "taste", w = 10, h = 12.8)
