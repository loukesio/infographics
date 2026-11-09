"""Step 5: Storm Daniel flood extent, Copernicus EMS rapid mapping EMSR692 (6-22 Sep 2023).
Union of 'observedEventA' polygons over all DEL products; AOI union records where mapping exists."""
import json, zipfile, glob, geopandas as gpd, pandas as pd
from common import fetch, CACHE, DATA, CRS_GR

d = json.load(open(fetch("https://rapidmapping.emergency.copernicus.eu/backend/dashboard-api/public-activations/?code=EMSR692", "emsr692.json")))
d = d["results"][0] if "results" in d else d
ev, aoi = [], []
for a in d["aois"]:
    for p in a["products"]:
        u = p.get("downloadPath")
        if not u: continue
        z = fetch(u); x = CACHE / "emsr692" / z.stem
        if not x.exists(): zipfile.ZipFile(z).extractall(x)
        for f in glob.glob(str(x / "**/*observedEventA*.shp"), recursive=True):
            e = gpd.read_file(f).to_crs(CRS_GR); e["product"] = z.stem; ev.append(e)
        for f in glob.glob(str(x / "**/*areaOfInterestA*.shp"), recursive=True):
            aoi.append(gpd.read_file(f).to_crs(CRS_GR)[["geometry"]])
ev = pd.concat(ev, ignore_index=True)
print(ev.columns.tolist()); print(ev.filter(regex="(?i)notation|event_type|obj_desc").drop_duplicates().head(10))
col = next(c for c in ev.columns if c.lower() == "notation")
fl = ev[ev[col] == "Flooded area"]   # excludes "Flood trace"
flood = fl.geometry.make_valid().union_all(); mapped = pd.concat(aoi).geometry.make_valid().union_all()
gpd.GeoDataFrame(geometry=[flood], crs=CRS_GR).to_crs(4326).to_file(DATA / "daniel_flood_union.geojson")
g = gpd.read_parquet(DATA / "grid.parquet").to_crs(CRS_GR)
a = g.area
out = pd.DataFrame({"h3": g.h3,
    "daniel_flood_share": g.intersection(flood).area / a,
    "daniel_mapped_share": g.intersection(mapped).area / a})
# number of products in which the cell was flooded (persistence proxy)
cnt = gpd.sjoin(g[["h3", "geometry"]], fl[["product", "geometry"]], predicate="intersects").groupby("h3")["product"].nunique()
out["daniel_products_flooded"] = out.h3.map(cnt).fillna(0).astype(int)
out.to_parquet(DATA / "l_flood.parquet")
reg = gpd.read_file(DATA / "border_el61.geojson").to_crs(CRS_GR).geometry.iloc[0]
print(f"flooded union total {flood.area/1e6:.0f} km2; inside Thessaly {flood.intersection(reg).area/1e6:.0f} km2 (day26: 926)")
