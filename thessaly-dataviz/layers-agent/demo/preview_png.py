import geopandas as gpd, matplotlib.pyplot as plt, matplotlib as mpl, sys
g = gpd.read_parquet("data/thessaly_h3.parquet").to_crs(2100)
b = gpd.read_file("data/border_el61.geojson").to_crs(2100)
sub = sys.argv[1] if len(sys.argv) > 1 else "flood layer provisional"
hard = ("slope_mean_deg < 5 & natura_any_share < 0.05 & (daniel_mapped_share < 0.5 | daniel_flood_share < 0.05) & "
        "lc_crop_share > 0.5 & lc_built_share < 0.1 & dist_substation_km < 5")
panels = [("elev_mean_m", "Elevation (m) · Copernicus GLO-90", "cividis", None),
          ("lc_crop_share", "Cropland share · ESA WorldCover 2021", "YlOrBr", None),
          ("pop_density_km2", "People per km² · Kontur 2023", "magma_r", mpl.colors.LogNorm(1, 5000)),
          ("natura_any_share", "Natura 2000 share · EEA", "Greens", None),
          ("daniel_flood_share", f"Flooded by Daniel 2023 · EMSR692 ({sub})", "Blues", None),
          ("dist_substation_km", "Km to nearest substation · OSM", "viridis_r", None)]
fig, ax = plt.subplots(3, 3, figsize=(18, 17), facecolor="white")
ax = ax.ravel()
for a, (c, t, cm, nm) in zip(ax, panels):
    d = g[g[c].notna()]
    if c == "pop_density_km2": d = d[d[c] > 0]
    nm = nm or mpl.colors.Normalize(float(d[c].quantile(.01)), float(d[c].quantile(.99)))
    d.plot(color=plt.get_cmap(cm)(nm(d[c].values)), ax=a, linewidth=.15, edgecolor="face")
    fig.colorbar(mpl.cm.ScalarMappable(norm=nm, cmap=cm), ax=a, shrink=.6)
    b.boundary.plot(ax=a, color="#333", lw=.5); a.set_title(t, fontsize=12, loc="left"); a.axis("off")
q = g.query(hard, engine="python")
a = plt.subplot2grid((3, 3), (2, 0), colspan=3, fig=fig); [x.remove() for x in ax[6:]]
g.plot(ax=a, color="#eeeeee", linewidth=.15, edgecolor="face"); b.boundary.plot(ax=a, color="#333", lw=.6)
n2 = mpl.colors.Normalize(0, 5); q.plot(ax=a, color=plt.get_cmap("autumn")(n2(q.dist_substation_km.values)), linewidth=.15, edgecolor="face")
fig.colorbar(mpl.cm.ScalarMappable(norm=n2, cmap="autumn"), ax=a, shrink=.6, label="km to substation")
a.set_title(f"Agent query: flat (<5°) farmland, outside Natura, not flooded by Daniel, <5 km to a substation → {q.area_km2.sum():.0f} km²",
            fontsize=13, loc="left"); a.axis("off")
fig.suptitle("Thessaly layers agent — 17,504 H3 cells, 40+ layers, one query", fontsize=20, x=.02, ha="left", weight="bold")
plt.tight_layout(); plt.savefig("maps/preview.png", dpi=80); print(q.area_km2.sum())
