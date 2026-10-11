# Install every R package the project needs. Run once:  Rscript setup/install_packages.R
cran <- c("tidyverse", "sf", "rnaturalearth", "rnaturalearthdata", "ggrepel", "patchwork",
          "ggtext", "ggraph", "igraph", "ggforce", "ragg", "glue", "scales", "jsonlite",
          "colorspace", "systemfonts", "readxl", "remotes", "geomtextpath", "polyclip")
missing <- setdiff(cran, rownames(installed.packages()))
if (length(missing)) install.packages(missing, repos = "https://cloud.r-project.org")

# ggvmap (Loukas's own package, GitHub)
if (!requireNamespace("ggvmap", quietly = TRUE)) remotes::install_github("loukesio/ggvmap")

# geomtextpath makes the ggvmap ring labels curve. Without it ggvmap silently draws straight labels.
stopifnot(requireNamespace("geomtextpath", quietly = TRUE))
message("All packages installed.")
