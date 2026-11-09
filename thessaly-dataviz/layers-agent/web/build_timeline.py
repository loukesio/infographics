"""Daniel day-by-day: for each acquisition date, the flood state of each EMSR692 AOI (its latest product up to that date),
aggregated to the H3 cells of the demo. Output: assets/daniel_timeline.json {dates, km2, frames:[[cellIdx, share%],...]}."""
import json, glob, pathlib, numpy as np, pandas as pd, geopandas as gpd, h3
from rasterio.features import rasterize
from rasterio.transform import from_bounds
R = pathlib.Path(__file__).resolve().parents[1]; C = R / "cache"
W0, S0, E0, N0, TW, TH = 21.3, 38.95, 23.4, 39.95, 2100, 1000      # ~100 m pixels over the flooded plain
tr = from_bounds(W0, S0, E0, N0, TW, TH)
d = json.load(open(C / "emsr692.json")); d = d["results"][0] if "results" in d else d
prods = []
for a in d["aois"]:
    for p in a["products"]:
        if not p.get("downloadPath"): continue
        dt = p["images"][0]["acquisitionTime"][:10]
        stem = pathlib.Path(p["downloadPath"]).stem
        shp = glob.glob(str(C / "emsr692" / stem / "**/*observedEventA*.shp"), recursive=True)
        if shp: prods.append((a["name"], dt, shp[0]))
prods = pd.DataFrame(prods, columns=["aoi", "date", "shp"]).sort_values("date")
dates = sorted(prods.date.unique()); print(dates)
cells = json.loads((R / "web/data.json").read_text())["h3"]; cidx = {c: i for i, c in enumerate(cells)}
lat = N0 - (np.arange(TH) + .5) * (N0 - S0) / TH; lon = W0 + (np.arange(TW) + .5) * (E0 - W0) / TW
pix = np.full((TH, TW), -1, np.int32)
for r in range(TH):
    for c in range(TW):
        pix[r, c] = cidx.get(h3.latlng_to_cell(lat[r], lon[c], 8), -1)
pxkm2 = ((E0 - W0) / TW * 111.32 * np.cos(np.radians(lat)))[:, None] * ((N0 - S0) / TH * 110.54)
masks = {}
for _, p in prods.iterrows():
    g = gpd.read_file(p.shp).to_crs(4326); g = g[g.notation == "Flooded area"]
    masks[(p.aoi, p.date)] = rasterize([(x, 1) for x in g.geometry], out_shape=(TH, TW), transform=tr).astype(bool) if len(g) else np.zeros((TH, TW), bool)
cellpx = np.bincount(pix[pix >= 0], minlength=len(cells))
frames, km2 = [], []
for dt in dates:
    m = np.zeros((TH, TW), bool)
    for aoi, grp in prods[prods.date <= dt].groupby("aoi"):
        m |= masks[(aoi, grp.date.max())]
    inside = (pix >= 0) & m
    cnt = np.bincount(pix[inside], minlength=len(cells))
    sh = np.where(cellpx > 0, cnt / np.maximum(cellpx, 1), 0)
    nz = np.nonzero(sh > 0.02)[0]
    frames.append([[int(i), int(round(sh[i] * 100))] for i in nz]); km2.append(round(float((m * pxkm2)[pix >= 0].sum())))
out = {"dates": dates, "km2": km2, "frames": frames, "aoi_dates": prods.groupby("date").aoi.apply(list).to_dict()}
(R / "web/assets/daniel_timeline.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
print(list(zip(dates, km2)))
