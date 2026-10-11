# Download the Google Fonts used by every chart into your user font folder. Run once:
#   Rscript setup/install_fonts.R
# Fonts: Oswald (titles), Fira Sans + Fira Sans Condensed (text), Playfair Display (drought title).
# After installing, restart R / RStudio so systemfonts and ragg see them.
base <- "https://raw.githubusercontent.com/google/fonts/main/ofl/"
files <- c("oswald/Oswald%5Bwght%5D.ttf",
           "firasans/FiraSans-Regular.ttf", "firasans/FiraSans-Bold.ttf", "firasans/FiraSans-Light.ttf",
           "firasanscondensed/FiraSansCondensed-Regular.ttf", "firasanscondensed/FiraSansCondensed-Bold.ttf",
           "playfairdisplay/PlayfairDisplay%5Bwght%5D.ttf",
           "cormorantgaramond/CormorantGaramond%5Bwght%5D.ttf")

dest <- switch(Sys.info()[["sysname"]],
  Darwin  = file.path(Sys.getenv("HOME"), "Library", "Fonts"),
  Windows = file.path(Sys.getenv("LOCALAPPDATA"), "Microsoft", "Windows", "Fonts"),
  file.path(Sys.getenv("HOME"), ".fonts"))
dir.create(dest, recursive = TRUE, showWarnings = FALSE)

for (f in files) {
  out <- file.path(dest, URLdecode(basename(f)))
  if (!file.exists(out)) download.file(paste0(base, f), out, mode = "wb", quiet = TRUE)
}
if (.Platform$OS.type == "unix" && Sys.info()[["sysname"]] != "Darwin") system("fc-cache -f")
message("Fonts installed in ", dest, ". On Windows you may need to double-click each .ttf and press Install.")
