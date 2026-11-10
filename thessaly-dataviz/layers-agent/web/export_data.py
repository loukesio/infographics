"""Export the H3 table as compact column arrays for the web demo."""
import json, pandas as pd, numpy as np, geopandas as gpd, pathlib
R = pathlib.Path(__file__).resolve().parents[1]
d = pd.read_parquet(R / "data/thessaly_h3.parquet").drop(columns="geometry")
ru = {"Larisa": 0, "Karditsa, Trikala": 1, "Magnisia, Sporades": 2}
cols = {  # web name: (column, decimals)
 "area": ("area_km2", 3), "elev": ("elev_mean_m", 0), "slope": ("slope_mean_deg", 1), "flat": ("slope_lt5_share", 2),
 "south": ("south_facing_share", 2), "crop": ("lc_crop_share", 2), "tree": ("lc_tree_share", 2), "grass": ("lc_grass_share", 2),
 "built": ("lc_built_share", 2), "water": ("lc_water_share", 2), "pop": ("population", 0), "flood": ("daniel_flood_share", 2),
 "mapped": ("daniel_mapped_share", 2), "floodn": ("daniel_products_flooded", 0), "lake": ("tempe_lake_share", 2),
 "lakedepth": ("tempe_lake_depth_m", 0), "natura": ("natura_any_share", 2), "dsub": ("dist_substation_km", 1),
 "dline": ("dist_hv_line_km", 1), "droad": ("dist_paved_road_km", 1), "dmajor": ("dist_major_road_km", 1),
 "solar": ("solar_share", 3), "dsolar": ("dist_solar_km", 1), "thr": ("threatened_records", 0), "thrsp": ("threatened_species", 0),
 "track": ("road_km_track", 1)}
off = pd.read_parquet(R / "data/official_h3.parquet"); d = d.merge(off, on="h3", how="left")
d["forest_proxy"] = (d.lc_tree_share.fillna(0) + d.lc_shrub_share.fillna(0)).clip(0, 1)
cols.update({"q50": ("official_flood_q50_share", 2), "q100": ("official_flood_q100_share", 2), "q1000": ("official_flood_q1000_share", 2),
 "archA": ("arch_zone_share", 2), "darch": ("dist_arch_zone_km", 1), "roadless": ("roadless_share", 2), "histfl": ("hist_flood_events", 0),
 "forest": ("forest_proxy", 2), "wetl": ("lc_wetland_share", 2)})
PE = ["Λάρισα", "Μαγνησία", "Σποράδες", "Καρδίτσα", "Τρίκαλα"]
DM = sorted(d.municipality.dropna().unique().tolist())
out = {"h3": d.h3.tolist(), "ru": d.regional_unit.map(ru).fillna(0).astype(int).tolist(),
       "pe": d.regional_unit_pe.map({k: i for i, k in enumerate(PE)}).fillna(-1).astype(int).tolist(), "pe_names": PE,
       "dimos": d.municipality.map({k: i for i, k in enumerate(DM)}).fillna(-1).astype(int).tolist(), "dimoi": DM}
for k, (c, dec) in cols.items():
    v = d[c].astype(float).round(dec).fillna(-1)
    out[k] = (v.astype(int) if dec == 0 else v).tolist()
b = gpd.read_file(R / "data/border_el61.geojson").geometry.iloc[0].simplify(0.004)
polys = [b] if b.geom_type == "Polygon" else list(b.geoms)
out["border"] = [[[round(x, 4), round(y, 4)] for x, y in p.exterior.coords] for p in polys if p.area > 1e-5]
s = json.dumps(out, separators=(",", ":"))
(R / "web/data.json").write_text(s); print(len(s) / 1e6, "MB", len(out["h3"]))
