"""Region flood works (data/region_flood_works.csv, 83 rows) → approximate locations by matching published place names
to OSM localities (Overture) and rivers. Locations are APPROXIMATE: a village name gives the village, not the works site."""
import os, re, json, unicodedata, pathlib, numpy as np, pandas as pd, geopandas as gpd, shapely, h3
os.environ["OGR_GEOJSON_MAX_OBJ_SIZE"] = "0"
R = pathlib.Path(__file__).resolve().parents[1]
def norm(s):
    s = unicodedata.normalize("NFD", str(s).lower()); s = "".join(ch for ch in s if unicodedata.category(ch) != "Mn")
    s = re.sub(r"^(δ\.δ\.|δ\.κ\.|τ\.κ\.|κοιν\w*|οικισμ\w*|ποταμ\w*|ρεμα|ρεματος|χειμαρρ\w*)\s+", "", s.strip())
    return re.sub(r"[^\w ]", "", s).strip()
w = pd.read_csv(R / "data/region_flood_works.csv")
loc = pd.read_parquet(R / "cache/ov_localities.parquet"); loc["k"] = loc.nm.map(norm)
pe = gpd.read_file(R / "data/raw/official/adm_pol_perif_enotites.json").to_crs(4326)
pe = pe[pe.lektiko.str.contains("ΛΑΡΙΣ|ΜΑΓΝΗΣ|ΣΠΟΡΑΔ|ΚΑΡΔΙΤΣ|ΤΡΙΚΑΛ")]
thess = shapely.union_all(pe.geometry.values)
locg = gpd.GeoDataFrame(loc, geometry=gpd.points_from_xy(loc.lon, loc.lat), crs=4326)
locg = locg[locg.within(thess.buffer(0.02))]
PEK = {"Λάρισας": "ΛΑΡΙΣ", "Τρικάλων": "ΤΡΙΚΑΛ", "Καρδίτσας": "ΚΑΡΔΙΤΣ", "Μαγνησίας": "ΜΑΓΝΗΣ"}
riv = pd.read_parquet(R / "cache/ov_rivers.parquet"); riv["k"] = riv.nm.map(norm)
rivers = set(riv.k.dropna()) | {"πηνειος", "ενιπεας", "παμισος", "ληθαιος", "τιταρησιος", "φαρσαλιτης", "αχελωος", "ασπροποταμος", "καραμπαλης", "σοφαδιτης"}
rows, PTS = [], []
for i, r in w.iterrows():
    toks = [t for t in str(r.place_names).split(";") if t and t != "nan"]
    pts, rv = [], []
    area = thess
    if isinstance(r.regional_unit, str):
        keys = [PEK[x] for x in r.regional_unit.split(";") if x in PEK]
        if keys: area = shapely.union_all(pe[pe.lektiko.str.contains("|".join(keys))].geometry.values).buffer(0.02)
    for t in toks:
        k = norm(t)
        if not k: continue
        m = locg[(locg.k == k) & locg.within(area)]
        if len(m) == 1: pts.append((m.lon.iloc[0], m.lat.iloc[0], t))
        elif len(m) > 1 and float(m.distance(m.geometry.iloc[0]).max()) < 0.05: pts.append((m.lon.mean(), m.lat.mean(), t))
        if k in rivers: rv.append(t)
    lon = np.mean([p[0] for p in pts]) if pts else np.nan; lat = np.mean([p[1] for p in pts]) if pts else np.nan
    for p in pts: PTS.append({"row": i, "place": p[2], "lon": round(p[0], 5), "lat": round(p[1], 5), "budget_eur": r.budget_eur, "status": r.status, "name": r["name"]})
    rows.append({"row": i, "name": r["name"], "budget_eur": r.budget_eur, "status": r.status, "matched_places": "; ".join(p[2] for p in pts), "rivers": "; ".join(rv),
                 "lon": lon, "lat": lat, "geocode": "οικισμός" if pts else ("μόνο ποτάμι" if rv else "χωρίς θέση")})
g = pd.DataFrame(rows); print(g.geocode.value_counts().to_dict(), "budget located €", round(g.loc[g.geocode == "οικισμός", "budget_eur"].sum() / 1e6, 1), "M of", round(g.budget_eur.sum() / 1e6, 1))
g.to_csv(R / "data/region_flood_works_geocoded.csv", index=False)
P = pd.DataFrame(PTS); P.to_csv(R / "data/region_flood_works_points.csv", index=False); print(len(P), "place points")
# per-cell: works within 3 km of cell centre (approximate)
cells = gpd.read_parquet(R / "data/thessaly_h3.parquet")[["h3", "geometry"]].to_crs(2100); cent = cells.centroid
wp = P; wg = gpd.GeoSeries(gpd.points_from_xy(wp.lon, wp.lat), crs=4326).to_crs(2100)
tree = shapely.STRtree(wg.values); ci, wi = tree.query(cent.values, predicate="dwithin", distance=3000)
cnt = np.bincount(ci, minlength=len(cells)); eur = np.bincount(ci, weights=wp.budget_eur.values[wi], minlength=len(cells))
d = tree.query_nearest(cent.values, return_distance=True); dist = pd.Series(d[1]).groupby(d[0][0]).min().reindex(range(len(cells))).values
pd.DataFrame({"h3": cells.h3, "works_3km": cnt, "works_eur_3km": eur.round(0), "dist_work_km": (dist / 1000).round(1)}).to_parquet(R / "data/works_h3.parquet")
print(g[g.geocode == "οικισμός"][["matched_places", "budget_eur"]].head(10).to_string())
