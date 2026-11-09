"""Step 6: OpenStreetMap via Overture Maps release 2026-10-21.0 (ODbL):
roads by class, solar plants/generators, HV power lines, substations -> per-cell lengths, areas and distances."""
import geopandas as gpd, pandas as pd, numpy as np, shapely
from overture import con, path, BB
from common import CACHE, DATA, CRS_GR

c = con()
f_roads, f_pow = CACHE / "ov_roads.parquet", CACHE / "ov_power.parquet"
if not f_roads.exists():
    c.sql(f"""COPY (SELECT id, class, subtype, ST_AsWKB(geometry) AS wkb FROM read_parquet('{path('transportation','segment')}', hive_partitioning=1)
      WHERE {BB} AND subtype='road') TO '{f_roads}' (FORMAT parquet)""")
if not f_pow.exists():
    c.sql(f"""COPY (SELECT id, class, source_tags, ST_AsWKB(geometry) AS wkb FROM read_parquet('{path('base','infrastructure')}', hive_partitioning=1)
      WHERE {BB} AND subtype='power') TO '{f_pow}' (FORMAT parquet)""")

def load(f):
    d = pd.read_parquet(f); d["geometry"] = shapely.from_wkb(d.pop("wkb"))
    return gpd.GeoDataFrame(d, geometry="geometry", crs=4326).to_crs(CRS_GR)
roads, pw = load(f_roads), load(f_pow)
g = gpd.read_parquet(DATA / "grid.parquet").to_crs(CRS_GR)[["h3", "geometry", "cell_km2"]]
out = pd.DataFrame({"h3": g.h3})

# --- roads: km per cell, by group
grp = {"motorway": "major", "trunk": "major", "primary": "major", "secondary": "major", "tertiary": "minor",
       "residential": "minor", "unclassified": "minor", "living_street": "minor", "service": "minor", "track": "track"}
roads["grp"] = roads["class"].map(grp).fillna("other")
print(roads["class"].value_counts().head(12))
ov = gpd.overlay(roads[["grp", "geometry"]], g[["h3", "geometry"]], how="intersection", keep_geom_type=True)
ov["km"] = ov.length / 1000
pv = ov.pivot_table(index="h3", columns="grp", values="km", aggfunc="sum").add_prefix("road_km_").add_suffix("").reset_index()
out = out.merge(pv, on="h3", how="left").fillna(0)
cen = g.copy(); cen["geometry"] = g.centroid
def dist(src, col):
    j = gpd.sjoin_nearest(cen[["h3", "geometry"]], src[["geometry"]], distance_col=col)
    return j.groupby("h3")[col].min()
paved = roads[roads.grp.isin(["major", "minor"])]
out["dist_paved_road_km"] = out.h3.map(dist(paved, "d")) / 1000
out["dist_major_road_km"] = out.h3.map(dist(roads[roads.grp == "major"], "d")) / 1000

# --- solar: plant/generator with solar source, polygonal
def tag(t, k):
    try: return dict(t).get(k) if t is not None else None
    except Exception: return None
pw["src"] = [tag(t, "plant:source") or tag(t, "generator:source") for t in pw.source_tags]
sol = pw[(pw.src == "solar") & pw.geom_type.isin(["Polygon", "MultiPolygon"])].copy()
sol = sol[sol["class"] == "plant"] if (sol["class"] == "plant").sum() > 500 else sol
print("solar polygons:", len(sol), "class:", sol["class"].value_counts().to_dict(), f"area {sol.area.sum()/1e6:.1f} km2")
solu = gpd.GeoDataFrame(geometry=[sol.geometry.make_valid().union_all()], crs=CRS_GR)
inter = gpd.overlay(g[["h3", "geometry"]], solu, how="intersection")
out["solar_km2"] = out.h3.map(inter.set_index("h3").area / 1e6).fillna(0)
out["solar_share"] = out.solar_km2 / g.cell_km2.values
out["dist_solar_km"] = out.h3.map(dist(sol, "d")) / 1000

# --- grid connection
lines = pw[pw["class"].isin(["power_line"])]
subs = pw[pw["class"] == "substation"]
print("power lines", len(lines), "substations", len(subs))
out["dist_hv_line_km"] = out.h3.map(dist(lines, "d")) / 1000
out["dist_substation_km"] = out.h3.map(dist(subs, "d")) / 1000
out.to_parquet(DATA / "l_osm.parquet")
sol.to_crs(4326)[["id", "geometry"]].to_file(DATA / "solar_plants.geojson")
r = gpd.read_file(DATA / "border_el61.geojson").to_crs(CRS_GR).geometry.iloc[0]
rc = roads.clip(r); print(f"roads in Thessaly: {rc.length.sum()/1000:,.0f} km, track share {rc[rc.grp=='track'].length.sum()/rc.length.sum()*100:.0f}% (day24: 42,400 km, 53% dirt)")
print(f"solar in Thessaly: {sol.clip(r).area.sum()/1e6:.1f} km2 (day12: 22 km2, 1,644 parks)")
print(out.describe().T[["mean", "max"]])
