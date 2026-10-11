# P2 · AI data centers — spren9er-style fan chart
source("R/radial_fan.R")

dc <- read_csv("data/epoch_data_centers.csv", show_col_types = FALSE) |>
  filter(power_mw > 0) |>
  mutate(owner = if_else(owner == "Unlisted", "Not listed", owner))

owners <- dc |> summarise(mw = sum(power_mw), .by = owner) |> arrange(desc(mw))
main <- head(owners$owner, 8)
dc <- dc |> mutate(group = if_else(owner %in% main, owner, "Others"))
order <- c(setdiff(main, "Not listed"), "Not listed", "Others")

cols <- c(Google = "#3B5BDB", Meta = "#E8590C", Amazon = "#2B8A3E", Microsoft = "#C2255C",
          SpaceXAI = "#7048E8", CoreWeave = "#0C8599", Oracle = "#E03131",
          "Not listed" = "#ADB5BD", Others = "#868E96")
cols <- cols[order]

total_gw <- round(sum(dc$power_mw) / 1000, 1)

p <- radial_fan(
  items = transmute(dc, item = str_remove(name, "^(Google|Meta|Microsoft|AWS|Amazon|CoreWeave|Coreweave|Huawei) "), group, value = power_mw),
  groups_order = order, colours = cols, unit = " MW",
  title = "Who Owns the Power Behind AI",
  subtitle = glue::glue("The {nrow(dc)} largest operating AI data centers draw {total_gw} GW of electricity.\n",
                        "Inner bubbles = owners, sized by total power. Rim = each data center, sized by its power."),
  caption = "Data: Epoch AI, Frontier Data Centers hub (Oct 2026) · Chart: Loukas Theodosiou · style after spren9er",
  label_size = 2.6, edge_alpha = 0.5, leaf_max = 7
)

ggsave("out/p2_ai_datacenters_fan.png", p, width = 11, height = 11.5, dpi = 200, device = ragg::agg_png)
