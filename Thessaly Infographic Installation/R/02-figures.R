# ── One fig_*() per figure. Returns a ggplot. No side effects, no ggsave. ────

fig_peaks <- function() {
  # The grey bars are 38% ink2 over paper — a LIGHT grey. Paper text on them is
  # 1.9:1, so the region label branches on the same flag as the fill.
  grey_bg  <- composite(INK2, PAPER, 0.38)
  label_fg <- ifelse(d_peaks$thess[order(d_peaks$m)], PAPER, INK)
  contrast_ok(PAPER, RED,     "region label on Thessalian bar")
  contrast_ok(INK,   grey_bg, "region label on grey bar")
  ggplot(d_peaks, aes(reorder(name, m), m, fill = thess)) +
    geom_col(width = .62) +
    geom_text(aes(label = paste0(gr_num(m), " m")), hjust = -0.12,
              family = "plexmono", size = 4.4,
              colour = ifelse(d_peaks$thess[order(d_peaks$m)], RED, INK2)) +
    geom_text(aes(y = 60, label = region), hjust = 0, family = "plexmono",
              size = 3.6, colour = label_fg) +
    scale_fill_manual(values = c("TRUE" = RED, "FALSE" = alpha(INK2, .38))) +
    scale_y_continuous(limits = c(0, 3300), expand = expansion(0)) +
    coord_flip() + theme_thess(grid = "none") +
    labs(title = "Οι ψηλότερες κορυφές της Ελλάδας",
         subtitle = "Ύψος σε μέτρα · οι θεσσαλικές κορυφές με κόκκινο",
         caption = "Πηγή: Ελληνική Ορειβατική Ομοσπονδία")
}

fig_river <- function() {
  ggplot(d_river, aes(km, m)) +
    geom_area(fill = PAPER2) +
    geom_line(colour = WATER, linewidth = 1.1) +
    geom_point(data = d_river_marks, size = 2.6, colour = INK) +
    geom_text(data = d_river_marks, aes(label = lab), vjust = -1.6,
              family = "plexmono", size = 3.6, colour = INK) +
    scale_x_continuous(breaks = seq(0, 200, 50), labels = \(x) paste0(x, " km"),
                       expand = expansion(mult = c(0, .04))) +
    scale_y_continuous(labels = gr_num, expand = expansion(mult = c(0, .18))) +
    theme_thess() +
    labs(title = "Πηνειός: 205 χιλιόμετρα από την Πίνδο στο Αιγαίο",
         subtitle = "Υψόμετρο κοίτης (m) · αποστάσεις κατά προσέγγιση",
         caption = "Πηγή: Britannica · WWF, Pinios River Basin")
}

fig_karla <- function() {
  ggplot(d_karla, aes(year, km2)) +
    geom_area(fill = WATER, alpha = .55) +
    geom_step(colour = "#5fb3bf", linewidth = 1.0) +
    annotate("text", x = 1966, y = 172, label = "Αποξήρανση, 1962",
             family = "plexmono", colour = RED, hjust = 0, size = 4) +
    annotate("text", x = 2022, y = 172, label = "Daniel, Σεπ. 2023",
             family = "plexmono", colour = RED, hjust = 1, size = 4) +
    scale_y_continuous(labels = gr_num) +
    theme_thess(dark = TRUE) +
    labs(title = "Η λίμνη που στράγγισαν και ξαναβρήκαν",
         subtitle = "Επιφάνεια λίμνης Κάρλας, km², 1950–2025",
         caption = "Πηγή: Φορέας Διαχείρισης · δημοσιευμένες δορυφορικές εκτιμήσεις")
}

fig_pop <- function() {
  ggplot(d_pop, aes(year, n)) +
    geom_line(linewidth = 1.0, colour = INK) +
    geom_point(aes(fill = approx), shape = 21, size = 3.2, stroke = 1.0, colour = INK) +
    scale_fill_manual(values = c("TRUE" = PAPER, "FALSE" = INK)) +
    scale_y_continuous(labels = \(y) paste0(gr_num(y / 1000), " χιλ.")) +
    theme_thess() +
    labs(title = "Μόνιμος πληθυσμός Θεσσαλίας, 1951–2021",
         subtitle = "Γεμάτη κουκκίδα = απογραφή · κενή = κατά προσέγγιση",
         caption = "ΕΛΣΤΑΤ. Τιμές πριν το 2011 κατά προσέγγιση — βλ. HANDOFF.md §3.5")
}

fig_trans <- function() {
  ggplot(d_trans, aes(month, m)) +
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = 0, ymax = 400,
             fill = WHEAT, alpha = .22) +
    annotate("rect", xmin = 5.6, xmax = 9.4, ymin = 1100, ymax = 1600,
             fill = TEAL, alpha = .10) +
    geom_line(colour = RED, linewidth = 1.2) +
    geom_point(shape = 21, fill = PAPER, colour = RED, size = 2.6, stroke = 1.1) +
    annotate("text", x = 7.5, y = 1680, label = "ΘΕΡΙΝΑ ΒΟΣΚΟΤΟΠΙΑ · ΠΙΝΔΟΣ, ΟΛΥΜΠΟΣ",
             family = "plexmono", colour = TEAL, size = 3.8) +
    annotate("text", x = 1.4, y = 300, label = "ΧΕΙΜΕΡΙΝΑ · Ο ΚΑΜΠΟΣ ΚΑΙ Η ΑΚΤΗ",
             family = "plexmono", colour = OCHRE, size = 3.8, hjust = 0) +
    scale_x_continuous(breaks = 1:12,
                       labels = c("Ι","Φ","Μ","Α","Μ","Ι","Ι","Α","Σ","Ο","Ν","Δ")) +
    scale_y_continuous(labels = gr_num, limits = c(0, 1800)) +
    theme_thess() +
    labs(title = "Η διπλή μετακίνηση",
         subtitle = "Υψόμετρο των κοπαδιών μέσα στον χρόνο (m) · σχηματικό",
         caption = "Οι ημερομηνίες κινούνταν με τον καιρό και τη βοσκή.")
}

fig_temptime <- function() {
  n <- nrow(d_temp)
  rise <- mean(d_temp$thessaly[(n - 9):n]) - mean(d_temp$thessaly[1:10])   # last decade vs first
  warmest <- d_temp$year[which.max(d_temp$thessaly)]
  p <- ggplot(d_temp_long, aes(year, t, colour = series)) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 2.2) +
    scale_colour_manual(values = c(thessaly = WHEAT, larissa = RED)) +
    scale_y_continuous(labels = \(v) paste0(gr_num(v, 1), "°")) +
    theme_thess(dark = TRUE) +
    labs(title = "Μέση ετήσια θερμοκρασία, 1960–2024",
         subtitle = glue("Θεσσαλία (ώχρα) και Λάρισα (κόκκινο) · +{gr_num(rise,1)} °C: μέση τιμή ",
                         "{d_temp$year[n-9]}–{d_temp$year[n]} έναντι {d_temp$year[1]}–{d_temp$year[10]} · ",
                         "θερμότερη χρονιά το {warmest}"),
         caption = if (CLIM_PROVISIONAL)
           "ΠΡΟΣΩΡΙΝΗ ΣΕΙΡΑ — δεν είναι παρατηρήσεις. Βλ. HANDOFF.md §3.1"
         else .clim$series$`_source`)
  if (CLIM_PROVISIONAL) stamp_provisional(p) else p
}

fig_heatdays <- function() {
  stopifnot(!is.null(d_heat))
  # decade means, the figure a visitor can actually read from 3 m
  dec <- d_heat |> filter(year < 2020) |> mutate(dec = year %/% 10 * 10) |>
    group_by(dec) |> summarise(d35 = mean(d35), d40 = mean(d40), .groups = "drop")
  first <- dec$d35[1]; last <- dec$d35[nrow(dec)]
  ggplot(d_heat_long, aes(year, n, fill = thr)) +
    geom_col(data = \(d) filter(d, thr == "35"), width = .8) +
    geom_col(data = \(d) filter(d, thr == "40"), width = .8) +
    geom_segment(data = dec, aes(x = dec - .4, xend = dec + 9.4, y = d35, yend = d35),
                 inherit.aes = FALSE, colour = PAPER, linewidth = 1.0) +
    scale_fill_manual(values = c("35" = WHEAT, "40" = RED)) +
    scale_x_continuous(breaks = seq(1960, 2020, 10), expand = expansion(add = 1)) +
    scale_y_continuous(expand = expansion(mult = c(0, .08))) +
    theme_thess(dark = TRUE) +
    labs(title = "Ημέρες καύσωνα στη Λάρισα, 1960–2024",
         subtitle = glue("Ημέρες ανά έτος με μέγιστη ≥ 35 °C (ώχρα) και ≥ 40 °C (κόκκινο) · ",
                         "λευκή γραμμή = μέσος όρος δεκαετίας: {gr_num(first)} τη δεκαετία του ’60, ",
                         "{gr_num(last)} τη δεκαετία του 2010"),
         caption = paste0("ERA5-Land (Copernicus/ECMWF) μέσω Open-Meteo · κελί πλέγματος Λάρισας, 39,64 N 22,42 E · ",
                          "ανάλυση ~9 km, άρα λίγο ψυχρότερο από τον σταθμό της πόλης"))
}
