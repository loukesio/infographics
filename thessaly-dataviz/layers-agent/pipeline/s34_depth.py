"""EXPERIMENT, NOT USED (12/11/2026). Kept to document why there is no depth layer.
Result: median depth 0-0.3 m depending on the edge setting, known deeply flooded villages (Metamorfosi, Vlochos, Palamas, Koskinas)
come out at 0 m or outside the extent: SAR flood maps do not see water between buildings, so villages are holes in the EMSR692
polygons, and GLO-30 is a surface model. Building-level depth would be wrong exactly where it matters. Needs a bare-earth DEM
and an extent that includes built-up areas (e.g. optical/aerial mapping) before it is worth another try.

Step 34: Storm Daniel water depth, FwDET-style (Cohen et al.): the water surface at every flooded pixel is the ground
elevation of the nearest edge of the flood polygon; depth = water surface - ground.

Inputs: Daniel extent (s05, EMSR692 'Flooded area' union), the EMSR692 areas of interest (to ignore edges that are only
the end of the mapped area), Copernicus GLO-30 (cache/dem_30m_2100.tif, from s29).
Edge elevations are taken as the 25th percentile of the edge pixels within ~300 m, because GLO-30 is a surface model
(trees and buildings at the water's edge would lift the water surface); the water surface is then smoothed (median, 270 m).

Per H3 cell: dan_depth_mean (m, mean over the flooded part), dan_depth_max (m),
bld_d05 / bld_d1 / bld_d2 = buildings whose centroid had at least 0.5 / 1 / 2 m of water.
Also writes web/assets/ov_depth.png and data/daniel_depth_summary.json."""
import os, glob, json; os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
import numpy as np, pandas as pd, geopandas as gpd, shapely, h3, rasterio, pyproj
from rasterio.features import rasterize
from rasterio.warp import reproject, Resampling
from rasterio.transform import from_bounds as tfb
from scipy import ndimage as ndi
from PIL import Image
from common import CACHE, DATA, ROOT

with rasterio.open(CACHE / "dem_30m_2100.tif") as r: Z = r.read(1).astype("float32"); T = r.transform; nod = r.nodata
Z[Z == nod] = np.nan
flood = gpd.read_file(DATA / "daniel_flood_union.geojson").to_crs(2100).geometry
aoi = pd.concat([gpd.read_file(f).to_crs(2100)[["geometry"]] for f in glob.glob(str(CACHE / "emsr692/**/*areaOfInterestA*.shp"), recursive=True)])
F = rasterize([(g, 1) for g in flood], out_shape=Z.shape, transform=T).astype(bool) & np.isfinite(Z)
A = rasterize([(g, 1) for g in aoi.geometry.make_valid()], out_shape=Z.shape, transform=T).astype(bool)
dry = ~F & A & np.isfinite(Z)
edge = F & ndi.binary_dilation(dry, structure=np.ones((3, 3), bool))
print("flooded px", int(F.sum()), "edge px", int(edge.sum()), flush=True)
# robust edge elevation: 25th percentile of edge pixels in an 11 x 11 window (330 m)
ez = np.where(edge, Z, np.nan)
pad = 5; P = np.pad(ez, pad, constant_values=np.nan); ys, xs = np.nonzero(edge)
win = np.stack([P[ys + dy, xs + dx] for dy in range(2 * pad + 1) for dx in range(2 * pad + 1)], 1)
ez[ys, xs] = np.nanpercentile(win, float(os.environ.get("EDGE_PCT", 25)), axis=1); del win, P
# nearest edge pixel for every flooded pixel
_, (iy, ix) = ndi.distance_transform_edt(~edge, return_indices=True)
W = np.where(F, ez[iy, ix], np.nan); del iy, ix
Wf = np.where(F, W, 0); Ws = ndi.median_filter(Wf, size=9); W = np.where(F, Ws, np.nan)
D = np.clip(W - Z, 0, 15); D[~F] = np.nan
v = D[F]; q = np.nanpercentile(v, [50, 90, 99, 99.9]); print("depth m p50/p90/p99/p99.9:", q.round(2), "max", round(float(np.nanmax(v)), 2))
summ = {"p50": float(q[0]), "p90": float(q[1]), "p99": float(q[2]), "max": float(np.nanmax(v)), "share_gt1m": float((v > 1).mean()), "share_gt2m": float((v > 2).mean())}

# per building and per H3 cell
F2 = pyproj.Transformer.from_crs(4326, 2100, always_xy=True); B2 = pyproj.Transformer.from_crs(2100, 4326, always_xy=True)
b = pd.read_parquet(CACHE / "region_buildings.parquet"); bc = shapely.centroid(shapely.from_wkb(b.wkb.apply(bytes).values))
bx, by = F2.transform(shapely.get_x(bc), shapely.get_y(bc)); c = ((np.array(bx) - T.c) / T.a).astype(int); r_ = ((np.array(by) - T.f) / T.e).astype(int)
ok = (c >= 0) & (c < Z.shape[1]) & (r_ >= 0) & (r_ < Z.shape[0]); bd = np.full(len(bx), np.nan, "float32"); bd[ok] = D[r_[ok], c[ok]]
wet = np.isfinite(bd); lo, la = B2.transform(np.array(bx)[wet], np.array(by)[wet])
bb = pd.DataFrame({"h3": [h3.latlng_to_cell(y, x, 8) for x, y in zip(lo, la)], "d": bd[wet]})
summ.update({"buildings_wet": int(wet.sum()), "buildings_gt05": int((bb.d >= .5).sum()), "buildings_gt1": int((bb.d >= 1).sum()), "buildings_gt2": int((bb.d >= 2).sum())})
cb = bb.groupby("h3").d.agg(bld_d05=lambda s: (s >= .5).sum(), bld_d1=lambda s: (s >= 1).sum(), bld_d2=lambda s: (s >= 2).sum())
ys, xs = np.nonzero(F); X = T.c + (xs + .5) * T.a; Y = T.f + (ys + .5) * T.e; lo, la = B2.transform(X, Y)
px = pd.DataFrame({"h3": [h3.latlng_to_cell(y, x, 8) for x, y in zip(lo, la)], "d": D[ys, xs]})
cp = px.groupby("h3").d.agg(dan_depth_mean="mean", dan_depth_max="max")
g = pd.read_parquet(DATA / "grid.parquet", columns=["h3"]); out = g.merge(cp, left_on="h3", right_index=True, how="left").merge(cb, left_on="h3", right_index=True, how="left")
out[["bld_d05", "bld_d1", "bld_d2"]] = out[["bld_d05", "bld_d1", "bld_d2"]].fillna(0).astype(int)
out.to_parquet(DATA / "depth_h3.parquet"); (DATA / "daniel_depth_summary.json").write_text(json.dumps(summ, indent=1)); print(summ)

# overlay
W0, S0, E0, N0 = 20.9, 38.8, 24.4, 40.3; TW, TH = 2800, 1200; TT = tfb(W0, S0, E0, N0, TW, TH)
dst = np.full((TH, TW), np.nan, "float32")
reproject(D, dst, src_transform=T, src_crs="EPSG:2100", dst_transform=TT, dst_crs="EPSG:4326", resampling=Resampling.average, src_nodata=np.nan, dst_nodata=np.nan)
o = np.zeros((TH, TW, 4), "uint8")
for lim, col in [(0, (170, 215, 245, 140)), (0.5, (110, 175, 235, 180)), (1, (55, 125, 215, 210)), (2, (30, 70, 175, 230)), (3, (20, 30, 110, 245))]:
    o[dst >= lim] = col
Image.fromarray(o, "RGBA").save(ROOT / "web/assets/ov_depth.png", optimize=True); print("ov_depth.png written")
