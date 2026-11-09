"""Step 7: Natura 2000 (EEA discomap service, SCI/SAC + SPA) and GBIF records of globally threatened species
(IUCN CR/EN/VU, coordinate uncertainty <= 10 km)."""
import json, urllib.parse, geopandas as gpd, pandas as pd, requests
from common import CACHE, DATA, CRS_GR

def natura(layer):
    f = CACHE / f"natura_{layer}.geojson"
    if not f.exists():
        feats, off = [], 0
        while True:
            q = dict(where="1=1", geometry="20.9,38.8,24.4,40.3", geometryType="esriGeometryEnvelope", inSR=4326, outSR=4326,
                     spatialRel="esriSpatialRelIntersects", outFields="*", f="geojson", resultOffset=off, resultRecordCount=200)
            r = requests.get(f"https://bio.discomap.eea.europa.eu/arcgis/rest/services/ProtectedSites/Natura2000Sites/MapServer/{layer}/query", params=q, timeout=300).json()
            feats += r["features"]; off += len(r["features"])
            if len(r["features"]) < 200: break
        json.dump({"type": "FeatureCollection", "features": feats}, open(f, "w"))
    return gpd.read_file(f).to_crs(CRS_GR)
sci, spa = natura(0), natura(1)
print("SCI/SAC", len(sci), "SPA", len(spa)); print(sci.columns.tolist()[:12])
g = gpd.read_parquet(DATA / "grid.parquet").to_crs(CRS_GR)[["h3", "geometry"]]
a = g.area
out = pd.DataFrame({"h3": g.h3})
for name, d in [("natura_habitats_share", sci), ("natura_birds_share", spa), ("natura_any_share", pd.concat([sci, spa]))]:
    u = d.geometry.make_valid().union_all()
    out[name] = g.intersection(u).area.values / a.values
# names of Natura sites per cell (for answers)
nm = next(c for c in sci.columns if c.lower() in ("sitename", "site_name", "name"))
allp = pd.concat([sci[[nm, "geometry"]], spa[[nm, "geometry"]]])
j = gpd.sjoin(g, allp, predicate="intersects").groupby("h3")[nm].agg(lambda s: "; ".join(sorted(set(s))))
out["natura_sites"] = out.h3.map(j).fillna("")

# GBIF threatened species
f = CACHE / "gbif_threatened.parquet"
if not f.exists():
    rows, off = [], 0
    base = "https://api.gbif.org/v1/occurrence/search?hasCoordinate=true&hasGeospatialIssue=false&decimalLatitude=38.8,40.3&decimalLongitude=20.9,24.4&iucnRedListCategory=CR&iucnRedListCategory=EN&iucnRedListCategory=VU"
    while True:
        r = requests.get(base + f"&limit=300&offset={off}", timeout=120).json()
        rows += [dict(species=x.get("species"), cat=x.get("iucnRedListCategory"), unc=x.get("coordinateUncertaintyInMeters"), lat=x["decimalLatitude"], lon=x["decimalLongitude"], year=x.get("year")) for x in r["results"]]
        off += 300
        if r["endOfRecords"] or off >= 100000: break
    pd.DataFrame(rows).to_parquet(f)
sp = pd.read_parquet(f); sp = sp[sp.unc.isna() | (sp.unc <= 10000)]; print("GBIF threatened records:", len(sp), "species:", sp.species.nunique())
spg = gpd.GeoDataFrame(sp, geometry=gpd.points_from_xy(sp.lon, sp.lat), crs=4326).to_crs(CRS_GR)
j = gpd.sjoin(spg, g, predicate="within")
out["threatened_records"] = out.h3.map(j.groupby("h3").size()).fillna(0).astype(int)
out["threatened_species"] = out.h3.map(j.groupby("h3").species.nunique()).fillna(0).astype(int)
out.to_parquet(DATA / "l_nature.parquet")
print(out.drop(columns="natura_sites").describe().T[["mean", "max"]])
