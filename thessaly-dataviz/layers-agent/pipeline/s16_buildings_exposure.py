"""Building exposure: Overture buildings (OSM + ML footprints) × official flood zones Q100/Q1000 (ΥΠΕΝ EL08) × Daniel (EMSR692).
Point = building centroid, sampled on 20 m masks (EPSG:2100). Outputs per H3 cell and per municipality."""
import os, glob, pathlib, numpy as np, pandas as pd, geopandas as gpd, h3
from rasterio.features import rasterize
from rasterio.transform import from_origin
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"
b = pd.read_parquet(R / "cache/buildings.parquet")
b["h3"] = [h3.latlng_to_cell(la, lo, 8) for la, lo in zip(b.lat, b.lon)]
cells = pd.read_parquet(R / "data/thessaly_h3.parquet", columns=["h3"]); b = b[b.h3.isin(set(cells.h3))].copy()
pts = gpd.GeoSeries(gpd.points_from_xy(b.lon, b.lat), crs=4326).to_crs(2100)
x, y = pts.x.values, pts.y.values
RES = 20.0; x0, y0, x1, y1 = x.min() - 100, y.min() - 100, x.max() + 100, y.max() + 100
W, H = int((x1 - x0) / RES) + 1, int((y1 - y0) / RES) + 1; T = from_origin(x0, y1, RES, RES)
col = ((x - x0) / RES).astype(int); row = ((y1 - y) / RES).astype(int)
def sample(gdf):
    m = rasterize(((g, 1) for g in gdf.to_crs(2100).geometry.values if g is not None and not g.is_empty), out_shape=(H, W), transform=T, dtype="uint8")
    return m[row, col].astype(bool)
b["in_q100"] = sample(gpd.read_file(RAW / "official/el08_friv_0100_rev1.json"))
b["in_q1000"] = sample(gpd.read_file(RAW / "official/el08_friv_1000_rev1.json"))
b["in_daniel"] = sample(gpd.read_file(R / "data/daniel_flood_union.geojson"))
print(len(b), "buildings in grid;", b[["in_q100", "in_q1000", "in_daniel"]].sum().to_dict())
print("Daniel-flooded buildings outside Q1000:", int((b.in_daniel & ~b.in_q1000).sum()), "outside Q100:", int((b.in_daniel & ~b.in_q100).sum()))
g = b.groupby("h3").agg(bld=("id", "size"), bld_m2=("area_m2", "sum"), bld_q100=("in_q100", "sum"), bld_q1000=("in_q1000", "sum"), bld_daniel=("in_daniel", "sum"),
                        bld_daniel_out=("in_daniel", lambda s: int((s & ~b.loc[s.index, "in_q1000"]).sum())))
out = cells.merge(g.reset_index(), on="h3", how="left").fillna(0)
out.to_parquet(R / "data/buildings_h3.parquet")
off = pd.read_parquet(R / "data/official_h3.parquet", columns=["h3", "municipality", "regional_unit_pe"])
m = out.merge(off, on="h3").groupby(["regional_unit_pe", "municipality"])[["bld", "bld_q100", "bld_q1000", "bld_daniel", "bld_daniel_out"]].sum().astype(int)
m["q100_pct"] = (m.bld_q100 / m.bld * 100).round(1); m = m.sort_values("bld_q100", ascending=False)
m.to_csv(R / "data/buildings_exposure_by_municipality.csv"); print(m.head(12).to_string()); print(m.sum(numeric_only=True).astype(int).to_dict())
