"""Fill building heights in web/assets/bld_*.json: Overture/OSM height where present (flag bit 8), else GHS-BUILT-H ANBH E2018 R2023A
(JRC GHSL, 3 arcsec ~90 m, mean net building height; tile R5_C21 in cache/ghsl/), minimum 4 m. Run after s19/s21; files already done are skipped."""
import json, glob, pathlib, rasterio, numpy as np
R = pathlib.Path(__file__).resolve().parents[1]
s = rasterio.open(glob.glob(str(R / "cache/ghsl/*.tif"))[0])
for f in sorted(glob.glob(str(R / "web/assets/bld_*.json"))):
    j = json.load(open(f))
    if j.get("hsrc"): continue
    ox, oy = j["o"]; B = j["b"]
    g = np.array([v[0] for v in s.sample([(ox + a[3] / 1e5, oy + a[4] / 1e5) for a in B])])
    for a, gh in zip(B, g):
        if a[1] > 0: a[0] |= 8
        else: a[1] = int(round(max(float(gh), 3.5))) if gh >= 3 else 4
    j["hsrc"] = "Overture/OSM height (bit 8) else GHS-BUILT-H ANBH 2018, min 4 m"
    json.dump(j, open(f, "w"), separators=(",", ":")); print(pathlib.Path(f).name, len(B), int(np.median([a[1] for a in B])))
