"""Step 1: region border (NUTS-2 EL61, GISCO 2021 1:1M, incl. Sporades) and H3 res-8 grid."""
import geopandas as gpd, h3, pandas as pd
from shapely.geometry import Polygon
from common import fetch, DATA, H3_RES, CRS_GR

f = fetch("https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/NUTS_RG_01M_2021_4326_LEVL_2.geojson")
nuts = gpd.read_file(f)
th = nuts[nuts.NUTS_ID == "EL61"].to_crs(4326)
f3 = fetch("https://gisco-services.ec.europa.eu/distribution/v2/nuts/geojson/NUTS_RG_01M_2021_4326_LEVL_3.geojson")
n3 = gpd.read_file(f3); n3 = n3[n3.NUTS_ID.str.startswith("EL61")][["NUTS_ID", "NAME_LATN", "geometry"]]
th.to_file(DATA / "border_el61.geojson"); n3.to_file(DATA / "nuts3_el61.geojson")

cells = set()
for poly in th.geometry.iloc[0].geoms if th.geometry.iloc[0].geom_type == "MultiPolygon" else [th.geometry.iloc[0]]:
    cells |= set(h3.geo_to_cells(poly.__geo_interface__, H3_RES))
    # include cells that intersect the border, not only centroids inside
    cells |= set(h3.h3shape_to_cells_experimental(h3.geo_to_h3shape(poly.__geo_interface__), H3_RES, contain="overlap"))
cells = sorted(cells)
geoms = [Polygon([(lng, lat) for lat, lng in h3.cell_to_boundary(c)]) for c in cells]
g = gpd.GeoDataFrame({"h3": cells}, geometry=geoms, crs=4326)
# share of each cell inside the region (for edge cells)
gm = g.to_crs(CRS_GR); bm = th.to_crs(CRS_GR).geometry.iloc[0]
g["cell_km2"] = gm.area / 1e6
g["in_region"] = gm.intersection(bm).area / gm.area
g = g[g.in_region > 0.001].reset_index(drop=True)
lat, lng = zip(*[h3.cell_to_latlng(c) for c in g.h3])
g["lat"], g["lon"] = lat, lng
# NUTS-3 regional unit by centroid
cen = gpd.GeoDataFrame(g[["h3"]], geometry=gpd.points_from_xy(g.lon, g.lat), crs=4326)
j = gpd.sjoin_nearest(cen, n3, how="left")[["h3", "NAME_LATN"]].drop_duplicates("h3")
g = g.merge(j.rename(columns={"NAME_LATN": "regional_unit"}), on="h3", how="left")
g.to_parquet(DATA / "grid.parquet")
print(f"{len(g)} cells; region area from cells = {(g.cell_km2*g.in_region).sum():.0f} km2; border area = {bm.area/1e6:.0f} km2")
print(g.regional_unit.value_counts())
