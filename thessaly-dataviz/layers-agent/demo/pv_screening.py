"""Showcase: the kind of multi-layer question the agent answers by calling tools (no LLM needed to run this file).
Q: Where in Thessaly is flat, non-protected, non-flooded farmland close to the grid, i.e. a first screen for agrivoltaics?"""
import sys, pathlib, json
ROOT = pathlib.Path(__file__).resolve().parents[1]; sys.path.insert(0, str(ROOT / "agent"))
import tools as T
hard = ("slope_mean_deg < 5 AND natura_any_share < 0.05 AND (daniel_mapped_share < 0.5 OR daniel_flood_share < 0.05) "
        "AND tempe_lake_share < 0.5 AND lc_crop_share > 0.5 AND lc_built_share < 0.1 AND dist_substation_km < 5")
print("Hard constraints:", hard)
print(json.dumps(T.area_stats(hard, "regional_unit")["rows"], indent=1, ensure_ascii=False))
score = "1 - least(dist_substation_km,5)/5*0.5 - least(dist_paved_road_km,2)/2*0.2 + south_facing_share*0.1 - least(threatened_records,5)/5*0.2"
top = T.rank_cells(score, hard, top=10, columns=["dist_substation_km", "dist_paved_road_km", "lc_crop_share", "daniel_mapped_share"])
for r in top["rows"]: print(r)
print(T.render_map("dist_substation_km", hard, "PV screen: candidate cells, km to substation", str(ROOT / "maps" / "pv_screen.html")))
print("Caveat: grid capacity, land price, cadastre and official flood-hazard maps are NOT in the data.")
