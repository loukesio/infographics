"""Step 11: HAND → per-H3-cell flooded share for water levels LEVELS (m above the nearest channel),
and calibration against Storm Daniel (EMSR692 'Flooded area' union, inside mapped AOIs only)."""
import os, json, glob, numpy as np, rasterio, geopandas as gpd, pandas as pd, h3
from rasterio.features import rasterize
from pyproj import Transformer
from common import CACHE, DATA, CRS_GR, ROOT
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
LEVELS = [1, 2, 3, 4, 5, 6, 8, 10]
with rasterio.open(CACHE / "hand_90m.tif") as r: hand = r.read(1); T = r.transform; shp = hand.shape
reg = gpd.read_file(DATA / "border_el61.geojson").to_crs(CRS_GR)
inreg = rasterize([(g, 1) for g in reg.geometry], out_shape=shp, transform=T).astype(bool)
fl = gpd.read_file(DATA / "daniel_flood_union.geojson").to_crs(CRS_GR)
flood = rasterize([(g, 1) for g in fl.geometry], out_shape=shp, transform=T).astype(bool)
aoi = []
for f in glob.glob(str(CACHE / "emsr692/**/*areaOfInterestA*.shp"), recursive=True): aoi.append(gpd.read_file(f).to_crs(CRS_GR))
aoi = pd.concat(aoi); mapped = rasterize([(g, 1) for g in aoi.geometry], out_shape=shp, transform=T).astype(bool)
valid = inreg & ~np.isnan(hand)
# --- calibration (pixel level, inside mapped AOIs)
px = 0.0081; cal = []
M = valid & mapped
for h in [0.5] + LEVELS + [12, 15]:
    sim = M & (hand <= h); obs = M & flood
    hit = (sim & obs).sum(); fa = (sim & ~obs).sum(); miss = (~sim & obs).sum()
    cal.append(dict(level=h, sim_km2=round(sim.sum() * px), obs_km2=round(obs.sum() * px), hit_rate=round(hit / obs.sum(), 3),
                    false_alarm=round(fa / max(sim.sum(), 1), 3), csi=round(hit / (hit + fa + miss), 3)))
cal = pd.DataFrame(cal); print(cal.to_string(index=False))
best = cal.loc[cal.csi.idxmax()]
# --- per cell shares
tf = Transformer.from_crs(CRS_GR, 4326, always_xy=True)
rows, cols = np.nonzero(valid & (hand <= max(LEVELS)))
xs, ys = rasterio.transform.xy(T, rows, cols); lon, lat = tf.transform(np.array(xs), np.array(ys))
cells = json.loads((ROOT / "web/data.json").read_text())["h3"]; cidx = {c: i for i, c in enumerate(cells)}
ci = np.array([cidx.get(h3.latlng_to_cell(la, lo, 8), -1) for la, lo in zip(lat, lon)])
# pixel count per cell (all valid pixels) for the denominator
r2, c2 = np.nonzero(valid); xs2, ys2 = rasterio.transform.xy(T, r2, c2); lo2, la2 = tf.transform(np.array(xs2), np.array(ys2))
ci2 = np.array([cidx.get(h3.latlng_to_cell(a, b, 8), -1) for a, b in zip(la2, lo2)])
den = np.bincount(ci2[ci2 >= 0], minlength=len(cells))
hv = hand[rows, cols]; ok = ci >= 0
out = {"levels": LEVELS, "calibration": cal.to_dict("records"), "best": {"level": float(best.level), "csi": float(best.csi), "hit_rate": float(best.hit_rate), "false_alarm": float(best.false_alarm)},
       "channel_area_km2": 40, "cells": {}}
shares = []
for h in LEVELS:
    num = np.bincount(ci[ok & (hv <= h)], minlength=len(cells)); shares.append(np.where(den > 0, num / np.maximum(den, 1), 0))
S = np.vstack(shares)                         # levels × cells
nz = np.nonzero(S[-1] > 0.02)[0]
out["cells"] = {"idx": nz.tolist(), "share": (S[:, nz] * 100).round().astype(int).T.tolist()}
(ROOT / "web/assets/hand.json").write_text(json.dumps(out, separators=(",", ":")))
print("cells with any flooding at 10 m:", len(nz), "best", out["best"])
