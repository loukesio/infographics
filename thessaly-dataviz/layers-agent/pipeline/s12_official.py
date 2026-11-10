"""Official / authoritative layers added Nov 2026 → data/official_h3.parquet (one row per H3 cell).

Sources (downloaded to data/raw/, see README):
- Official flood-hazard extents, 2nd cycle (1st revision) Floods Directive, River Basin District EL08 (Thessaly),
  return periods 50/100/1000 y — ΥΠΕΝ / Γ.Δ. Υδάτων WFS gis.floods.ypeka.gr (floods_rev1:el08_friv_*_rev1)
- Historical flood events (points) EL08 — same WFS (v_hyd_poi_all_floods_v1_EL08)
- Regional units (Περιφερειακές Ενότητες) — same WFS (adm_pol_perif_enotites)
- Municipalities — OSM via Overture divisions (data/thessaly_municipalities.geojson)
- Archaeological protection zones A/B — ΥΠΠΟΑ Αρχαιολογικό Κτηματολόγιο via ΥΠΕΝ ΘαλΧωρ-2 GeoNode (download 973, 2020)
- Roadless areas of Greece v2 (May 2022) — Univ. Ioannina, Mendeley Data doi 10.17632/s6zh89fb5c.2, CC BY 4.0
"""
import os, glob, pathlib, numpy as np, pandas as pd, geopandas as gpd, shapely
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]; RAW = R / "data/raw"
cells = gpd.read_parquet(R / "data/thessaly_h3.parquet")[["h3", "geometry"]].to_crs(2100)
cells["a"] = cells.area

from rasterio.features import rasterize
from rasterio.transform import from_origin
RES = 40.0  # metres; shares from a 40 m raster (EPSG:2100), fast and accurate to ~1% per 0.74 km² cell
x0, y0, x1, y1 = cells.total_bounds; W, H = int((x1 - x0) / RES) + 1, int((y1 - y0) / RES) + 1
TR = from_origin(x0, y1, RES, RES)
CID = rasterize(((g, i + 1) for i, g in enumerate(cells.geometry.values)), out_shape=(H, W), transform=TR, dtype="int32").ravel()
NPX = np.bincount(CID, minlength=len(cells) + 1)[1:]

def share(g, name):
    """Share of each cell covered by polygons g (via 40 m raster)."""
    g = g.to_crs(2100); geoms = [x for x in g.geometry.values if x is not None and not x.is_empty]
    m = rasterize(((x, 1) for x in geoms), out_shape=(H, W), transform=TR, dtype="uint8").ravel().astype(bool)
    out = np.bincount(CID[m], minlength=len(cells) + 1)[1:] / np.maximum(NPX, 1)
    print(name, f"{(out * cells.a.values).sum() / 1e6:,.0f} km² in grid", flush=True)
    return np.clip(out, 0, 1).round(3)

o = pd.DataFrame({"h3": cells.h3})
for rp in ["0050", "0100", "1000"]:
    o[f"official_flood_q{int(rp)}_share"] = share(gpd.read_file(RAW / f"official/el08_friv_{rp}_rev1.json"), f"Q{int(rp)}")

# regional unit + municipality by cell centroid
cent = gpd.GeoDataFrame(o[["h3"]], geometry=cells.geometry.centroid, crs=2100)
pe = gpd.read_file(RAW / "official/adm_pol_perif_enotites.json").to_crs(2100)
pe = pe[pe.lektiko.str.contains("ΛΑΡΙΣ|ΜΑΓΝΗΣ|ΣΠΟΡΑΔ|ΚΑΡΔΙΤΣ|ΤΡΙΚΑΛ")][["lektiko", "geometry"]]
PE = {"ΛΑΡΙΣ": "Λάρισα", "ΜΑΓΝΗΣ": "Μαγνησία", "ΣΠΟΡΑΔ": "Σποράδες", "ΚΑΡΔΙΤΣ": "Καρδίτσα", "ΤΡΙΚΑΛ": "Τρίκαλα"}
pe["pe"] = pe.lektiko.map(lambda s: next(v for k, v in PE.items() if k in s))
dm = gpd.read_file(R / "data/thessaly_municipalities.geojson").to_crs(2100)[["name", "pe", "geometry"]].rename(columns={"pe": "pe_osm"})
j = gpd.sjoin_nearest(cent, pe[["pe", "geometry"]], how="left", max_distance=3000).drop_duplicates("h3")
k = gpd.sjoin_nearest(cent, dm, how="left", max_distance=3000).drop_duplicates("h3")
o["regional_unit_pe"] = j.pe.values; o["municipality"] = k.name.str.replace("Δήμος ", "", regex=False).values
print(o.regional_unit_pe.value_counts(dropna=False).to_dict())
pe_area = pe.assign(km2=pe.area / 1e6).groupby("pe").km2.sum().round(1); print("ΠΕ km²", pe_area.to_dict())

# archaeological protection zones, roadless areas
arch = gpd.read_file(RAW / "arch/ZONES_POLYGONS_CHECK.shp", encoding="utf-8")
arch = arch[arch.GEOMETRYNA.str.contains(r"Ζώνη Α", na=False)]  # RES framework excludes Zone A; viewshed study within 1 km of it
o["arch_zone_share"] = share(arch, "archaeological zones A")
road = gpd.read_file(glob.glob(str(RAW / "roadless/Roadless_Areas_WGS84/*.kml"))[0])
o["roadless_share"] = share(road, "roadless areas")
cent4326 = cent.to_crs(4326)
arch_c = arch.to_crs(2100); d = arch_c.sindex.nearest(cent.geometry, return_distance=True)
o["dist_arch_zone_km"] = (pd.Series(d[1]).groupby(d[0][0]).min().reindex(range(len(o))).values / 1000).round(1)

# historical flood events (points) per cell
hf = gpd.read_file(RAW / "official/v_hyd_poi_all_floods_v1_EL08.json").to_crs(2100)
hj = gpd.sjoin(hf[["geometry"]], gpd.GeoDataFrame(o[["h3"]], geometry=cells.geometry, crs=2100), predicate="within")
o["hist_flood_events"] = o.h3.map(hj.h3.value_counts()).fillna(0).astype(int)
print("historical events in grid", o.hist_flood_events.sum())

o.to_parquet(R / "data/official_h3.parquet"); pe_area.to_csv(R / "data/pe_area_official.csv")
print(o.describe().round(3).T)
