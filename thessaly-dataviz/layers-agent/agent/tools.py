"""Spatial tools over the Thessaly H3 table. Every result carries the layers it used, so answers stay checkable.
Expressions are DuckDB SQL over the columns in catalog.yaml (e.g. "slope_mean_deg < 5 AND natura_any_share = 0")."""
import re, json, pathlib, duckdb, yaml, h3
ROOT = pathlib.Path(__file__).resolve().parents[1]
DB = ROOT / "data" / "thessaly_h3.duckdb"
CAT = yaml.safe_load(open(ROOT / "catalog.yaml"))
COLS = set(CAT["columns"])
BAD = re.compile(r";|--|/\*|\b(insert|update|delete|drop|create|alter|attach|copy|pragma|install|load|export|import|call|set)\b|read_\w+\s*\(", re.I)

def _con(): return duckdb.connect(str(DB), read_only=True)
def _check(expr: str) -> str:
    if not expr or not expr.strip(): return "TRUE"
    if BAD.search(expr): raise ValueError("expression not allowed")
    idents = set(re.findall(r"\b[a-z_][a-z0-9_]*\b", re.sub(r"'[^']*'", "", expr.lower())))
    kw = {"and", "or", "not", "in", "is", "null", "between", "like", "ilike", "true", "false", "case", "when", "then", "else", "end",
          "abs", "ln", "log", "sqrt", "least", "greatest", "coalesce", "round", "power", "exp", "as", "cast", "double", "integer", "nullif"}
    unknown = idents - COLS - kw
    if unknown: raise ValueError(f"unknown columns/functions: {sorted(unknown)}. See list_layers().")
    return expr
def _layers(*exprs): return sorted({c for e in exprs if e for c in COLS if re.search(rf"\b{c}\b", e)})
def _prov(cols):
    return {c: {k: v for k, v in CAT["columns"][c].items() if k in ("source", "date", "caveat", "unit")} for c in cols if c in CAT["columns"]}

def list_layers() -> dict:
    """Catalog: every column with unit, source, date and caveats, plus grid rules."""
    return {"grid": CAT["grid"], "columns": CAT["columns"], "not_included": CAT["not_included"]}

def area_stats(where: str = "", group_by: str = "") -> dict:
    """Area (km2), share of Thessaly, population and cell count for cells matching `where`, optionally grouped by a column."""
    w = _check(where); gb = group_by.strip()
    if gb and gb not in COLS: raise ValueError("group_by must be a column")
    sel = f"{gb}," if gb else ""
    q = f"""SELECT {sel} count(*) AS cells, round(sum(area_km2),1) AS area_km2,
      round(100*sum(area_km2)/(SELECT sum(area_km2) FROM cells),2) AS pct_of_thessaly, round(sum(population)) AS population,
      round(100*sum(population)/(SELECT sum(population) FROM cells),2) AS pct_of_population
      FROM cells WHERE {w} {'GROUP BY '+gb+' ORDER BY area_km2 DESC' if gb else ''}"""
    with _con() as c: rows = c.sql(q).df().to_dict("records")
    return {"rows": rows, "where": w, "layers": _prov(_layers(w, gb))}

def zonal_stats(columns: list[str], where: str = "", group_by: str = "") -> dict:
    """Area-weighted mean of each column (shares, elevations...) and sum where it is an amount (km, km2, persons, counts)."""
    w = _check(where); cols = [c for c in columns if c in COLS]
    if not cols: raise ValueError("no valid columns")
    sums = {"population", "solar_km2", "road_km_major", "road_km_minor", "road_km_track", "road_km_other", "threatened_records"}
    parts = []
    for c in cols:
        if c in sums: parts.append(f"round(sum({c}),2) AS {c}_sum"); continue
        parts.append(f"round(sum({c}*area_km2)/nullif(sum(CASE WHEN {c} IS NOT NULL THEN area_km2 END),0),4) AS {c}_wmean")
        if CAT["columns"][c].get("unit") == "share": parts.append(f"round(sum({c}*area_km2),1) AS {c}_km2")
    gb = group_by.strip()
    if gb and gb not in COLS: raise ValueError("group_by must be a column")
    q = f"SELECT {gb+',' if gb else ''} round(sum(area_km2),1) AS area_km2, {', '.join(parts)} FROM cells WHERE {w} {'GROUP BY '+gb if gb else ''}"
    with _con() as c: rows = c.sql(q).df().to_dict("records")
    return {"rows": rows, "where": w, "layers": _prov(_layers(w, gb, *cols))}

def rank_cells(score: str, where: str = "", top: int = 20, columns: list[str] | None = None) -> dict:
    """Top cells by a score expression (higher = better), e.g. a weighted site-suitability score."""
    s, w = _check(score), _check(where)
    cols = [c for c in (columns or []) if c in COLS]
    q = f"SELECT h3, lat, lon, regional_unit, round(area_km2,3) AS area_km2, {', '.join(cols)+',' if cols else ''} round({s},4) AS score FROM cells WHERE {w} ORDER BY score DESC LIMIT {min(int(top),500)}"
    with _con() as c: rows = c.sql(q).df().to_dict("records")
    return {"rows": rows, "score": s, "where": w, "layers": _prov(_layers(s, w, *cols))}

def describe_place(lat: float, lon: float, ring: int = 0) -> dict:
    """All layer values for the H3 cell at a point (ring>0 adds neighbours, area-weighted)."""
    cells = list(h3.grid_disk(h3.latlng_to_cell(lat, lon, 8), int(ring)))
    with _con() as c:
        df = c.sql(f"SELECT * FROM cells WHERE h3 IN ({','.join(repr(x) for x in cells)})").df()
    if df.empty: return {"error": "point outside Thessaly grid"}
    return {"cells": df.to_dict("records"), "layers": "all, see list_layers()"}

def cells_near(lat: float, lon: float, radius_km: float, where: str = "") -> dict:
    """Area stats for cells within radius_km of a point and matching `where`."""
    w = _check(where)
    q = f"""SELECT count(*) cells, round(sum(area_km2),1) area_km2, round(sum(population)) population FROM cells
      WHERE 6371*2*asin(sqrt(power(sin(radians(lat-{lat})/2),2)+cos(radians({lat}))*cos(radians(lat))*power(sin(radians(lon-{lon})/2),2))) <= {radius_km} AND {w}"""
    with _con() as c: rows = c.sql(q).df().to_dict("records")
    return {"rows": rows, "where": w, "layers": _prov(_layers(w))}

def render_map(value: str, where: str = "", title: str = "", out: str = "") -> dict:
    """HTML map (Leaflet) of cells matching `where`, coloured by the expression `value`."""
    import folium, branca.colormap as cm, geopandas as gpd
    v, w = _check(value), _check(where)
    with _con() as c: df = c.sql(f"SELECT h3, regional_unit, {v} AS value FROM cells WHERE {w}").df()
    if df.empty: return {"error": "no cells match"}
    from shapely.geometry import Polygon
    g = gpd.GeoDataFrame(df, geometry=[Polygon([(b, a) for a, b in h3.cell_to_boundary(x)]) for x in df.h3], crs=4326)
    lo, hi = float(df.value.quantile(.02)), float(df.value.quantile(.98))
    cmap = cm.LinearColormap(["#fff7ec", "#fdbb84", "#d7301f", "#7f0000"], vmin=lo, vmax=hi if hi > lo else lo + 1, caption=title or v)
    m = folium.Map(location=[39.55, 22.3], zoom_start=8, tiles="CartoDB positron")
    folium.GeoJson(g.to_json(), style_function=lambda f: {"fillColor": cmap(f["properties"]["value"]) if f["properties"]["value"] is not None else "#ccc",
        "color": None, "weight": 0, "fillOpacity": .75}, tooltip=folium.GeoJsonTooltip(["h3", "regional_unit", "value"])).add_to(m)
    border = ROOT / "data" / "border_el61.geojson"
    folium.GeoJson(str(border), style_function=lambda f: {"fill": False, "color": "#333", "weight": 1}).add_to(m)
    cmap.add_to(m)
    p = pathlib.Path(out) if out else ROOT / "maps" / (re.sub(r"\W+", "_", (title or v))[:60] + ".html")
    m.save(str(p))
    return {"file": str(p), "cells": len(df), "where": w, "layers": _prov(_layers(v, w))}

TOOLS = [list_layers, area_stats, zonal_stats, rank_cells, describe_place, cells_near, render_map]
