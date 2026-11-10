"""ΔΕΔΔΗΕ hosting margins → per H3 cell: distance to nearest substation with free capacity (≥2 MVA), and margin of nearest substation."""
import pathlib, numpy as np, pandas as pd, geopandas as gpd
R = pathlib.Path(__file__).resolve().parents[1]
s = pd.read_csv(R / "data/deddie/deddie_substations_thessaly_2026-11-10.csv")
sg = gpd.GeoDataFrame(s, geometry=gpd.points_from_xy(s.lon, s.lat), crs=4326).to_crs(2100)
c = gpd.read_parquet(R / "data/thessaly_h3.parquet")[["h3", "geometry"]].to_crs(2100); c["geometry"] = c.centroid
n = gpd.sjoin_nearest(c, sg[["substation", "margin_mva", "geometry"]], distance_col="d").drop_duplicates("h3")
ok = sg[sg.max_tr_margin_mva >= 2]
m = gpd.sjoin_nearest(c, ok[["substation", "geometry"]], distance_col="d").drop_duplicates("h3")
o = pd.DataFrame({"h3": c.h3, "deddie_nearest": n.substation.values, "deddie_nearest_km": (n.d.values / 1000).round(1),
                  "deddie_nearest_margin_mva": n.margin_mva.values.round(1), "dist_sub_free_km": (m.d.values / 1000).round(1)})
o.to_parquet(R / "data/deddie_h3.parquet"); print(o.describe().round(1))
