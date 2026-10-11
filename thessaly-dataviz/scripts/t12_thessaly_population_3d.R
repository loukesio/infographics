# t12 — Thessaly population density in 3D (rayshader spike map)
# Style after the Kontur/rayshader maps of France (@researchremora) and Italy (@terence).
#
# Data   : Kontur Population Greece, 400 m H3 hexagons, release 2023-11-01 (HDX, CC BY)
#          https://data.humdata.org/dataset/kontur-population-greece
# Border : Eurostat GISCO NUTS-2 2021, EL61 Thessalia (1:1M). Mainland only — the Sporades
#          (Skiathos, Skopelos, Alonnisos; ~13 000 people) are cropped so the plain fills the frame.
#
# v2: labels are NOT drawn in 3D (rayshader's labels use a plain system font and look messy).
#     Each spike top is projected to image pixels through rgl and labelled afterwards with magick.
#     Vertical scale is derived from the data (tallest spike = SPIKE × map width) so it works at any cell size.
# Run from the project root: FAST=TRUE for a ~1 min camera check, FAST=FALSE for the rayrender final.

FAST   <- as.logical(Sys.getenv("FAST", "TRUE"))
TEST   <- as.logical(Sys.getenv("TEST", "FALSE"))   # TEST=TRUE: low-sample rayrender pass to tune the lights
SPIKE  <- 0.42                                   # tallest spike as a share of the map width
CAMERA <- list(theta = 0, phi = 32, zoom = 0.58, fov = 0)
options(rgl.useNULL = TRUE)                      # headless
suppressPackageStartupMessages({
  library(dplyr); library(purrr); library(sf); library(terra); library(rayshader); library(magick)
})
dir.create("out", showWarnings = FALSE)

# ---- 1. data -------------------------------------------------------------------------------------
gpkg <- "data/kontur/kontur_population_GR_20231101.gpkg"
nuts <- "data/kontur/nuts2_2021.geojson"
if (!file.exists(nuts)) download.file(paste0(
  "https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/",
  "NUTS_RG_01M_2021_4326_LEVL_2.geojson"), nuts, quiet = TRUE)
crs_gr <- 2100                                   # Greek Grid, metres
th  <- read_sf(nuts) |> filter(NUTS_ID == "EL61") |> st_transform(crs_gr) |> st_geometry() |> st_cast("POLYGON")
th  <- th[which.max(st_area(th))]                # mainland only
pop <- st_read(gpkg, quiet = TRUE) |> st_transform(crs_gr) |> st_filter(th)
message(sprintf("%d hexagons, %s people", nrow(pop), format(round(sum(pop$population)), big.mark = ",")))

# ---- 2. hexagons -> raster -> height matrix --------------------------------------------------------
res_m <- if (FAST || TEST) 800 else 400
r <- rast(ext(vect(th)), resolution = res_m, crs = st_crs(crs_gr)$wkt)
r <- rasterize(vect(pop), r, field = "population", fun = "sum", background = 0)   # empty land = 0
r <- mask(r, vect(th))                                                           # outside = NA (cut-out)
mat <- raster_to_matrix(r)
w <- nrow(mat); h <- ncol(mat)
zsc <- max(mat, na.rm = TRUE) / (SPIKE * w)
message(sprintf("matrix %d x %d, max cell %.0f people, zscale %.1f", w, h, max(mat, na.rm = TRUE), zsc))

# ---- 3. 3D scene -----------------------------------------------------------------------------------
pal <- colorRampPalette(c("#E9DCD9", "#E2CBDD", "#CFA8D8", "#B26BA9", "#7A1F5C", "#2B0A23"), bias = 3)(256)
win <- if (FAST || TEST) 1200 else 3000
win_h <- round(win * h / w)
mat |>
  height_shade(texture = pal) |>
  plot_3d(heightmap = mat, zscale = zsc, solid = FALSE, shadowdepth = 0,
          windowsize = c(win, win_h), background = "#FBF6F4")
do.call(render_camera, CAMERA)

# ---- 4. project each city's spike top to window pixels ---------------------------------------------
cities <- tribble(
  ~name,       ~lon,    ~lat,    ~lift,          # lift = label height above the spike, share of image width
  "LARISSA",   22.4191, 39.6390, 0.05,
  "VOLOS",     22.9425, 39.3622, 0.05,
  "TRIKALA",   21.7681, 39.5556, 0.07,
  "KARDITSA",  21.9222, 39.3650, 0.04,
  "KALAMBAKA", 21.6262, 39.7044, 0.04,
  "ELASSONA",  22.1862, 39.8947, 0.04
)
cxy <- st_as_sf(cities, coords = c("lon", "lat"), crs = 4326) |> st_transform(crs_gr) |> st_coordinates()
proj <- map_dfr(seq_len(nrow(cities)), \(i) {
  cell <- rowColFromCell(r, cellFromXY(r, cxy[i, , drop = FALSE]))
  xi <- cell[2]; yi <- cell[1]                   # mat[x, y]: x = raster column, y = raster row
  xs <- max(1, xi - 2):min(w, xi + 2); ys <- max(1, yi - 2):min(h, yi + 2)
  top <- max(mat[xs, ys], na.rm = TRUE)
  pk  <- which(mat[xs, ys] == top, arr.ind = TRUE)[1, ]
  xi <- xs[pk[1]]; yi <- ys[pk[2]]
  p <- rgl::rgl.user2window(xi - w / 2, top / zsc, yi - h / 2)   # rayshader scene coordinates
  tibble(name = cities$name[i], wx = p[1], wy = p[2], lift = cities$lift[i])
})

# ---- 5. render -------------------------------------------------------------------------------------
raw <- "out/t12_thessaly_population_3d_raw.png"
if (FAST) {
  render_snapshot(raw, software_render = TRUE, width = win, height = win_h)
} else {
  render_highquality(raw, samples = if (TEST) 24 else 256, light = TRUE, lightdirection = c(240, 320),
                     lightaltitude = c(35, 80), lightintensity = c(750, 300),
                     lightcolor = c("#FFE9D6", "white"), interactive = FALSE,
                     ground_material = rayrender::diffuse(color = "#F6F1EE"),
                     width = win, height = win_h)
}

# ---- 6. labels, title & credits with magick (real fonts) --------------------------------------------
img <- image_read(raw); IW <- image_info(img)$width; IH <- image_info(img)$height
BG  <- if (FAST) "#FBF6F4" else {                 # rayrender ground as it actually came out
  px <- as.integer(image_data(img, "rgb")[, 6, 6]); grDevices::rgb(px[1], px[2], px[3], maxColorValue = 255) }
proj <- proj |> mutate(px = wx * IW, py = (1 - wy) * IH, lift = lift * IW)
img <- image_draw(img)
segments(proj$px, proj$py - 0.004 * IW, proj$px, proj$py - proj$lift, col = "#8a7f86", lwd = max(1, IW / 1500))
dev.off()
for (i in seq_len(nrow(proj))) {
  lab <- image_blank(round(0.2 * IW), round(0.03 * IW), "none") |>
    image_annotate(proj$name[i], gravity = "center", size = round(0.016 * IW), color = "#3a3a3a", font = "Oswald") |>
    image_trim()
  li <- image_info(lab)
  img <- image_composite(img, lab, offset = sprintf("%+d%+d", round(proj$px[i] - li$width / 2),
                                                    round(proj$py[i] - proj$lift[i] - li$height - 0.004 * IW)))
}
img <- img |> image_border(BG, "60x60")
W <- image_info(img)$width
img |>
  image_border(BG, paste0("0x", round(W * 0.12))) |>
  image_annotate("POPULATION DENSITY MAP", gravity = "north", location = paste0("+0+", round(W * 0.03)),
                 size = round(W * 0.013), color = "#8a7f86", font = "Fira Sans") |>
  image_annotate("THESSALY", gravity = "north", location = paste0("+0+", round(W * 0.05)),
                 size = round(W * 0.065), weight = 700, color = "#3a3a3a", font = "Oswald") |>
  image_annotate(paste("Kontur Population 2023 (400 m hexagons, HDX) · border: Eurostat NUTS 2021, mainland only ·",
                       "rendered with rayshader in #rstats · Loukas Theodosiou"),
                 gravity = "south", location = paste0("+0+", round(W * 0.03)),
                 size = round(W * 0.0095), color = "#8a7f86", font = "Fira Sans") |>
  image_write("out/t12_thessaly_population_3d.png")
message("Done: out/t12_thessaly_population_3d.png")
