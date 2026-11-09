# Thessaly layers agent (prototype, Phase 0)

The open data behind the *30 maps of Thessaly* turned into one queryable grid and an LLM agent that combines the
layers. Nothing in `30daymap/` is changed; this folder only re-uses its sources and methods.

## What is here

| Path | What |
|---|---|
| `pipeline/s01…s09_*.py` | Download + aggregate each source to an **H3 res-8 grid** (17,504 cells, ~0.74 km² each) |
| `pipeline/s99_assemble.py` | Merge into `data/thessaly_h3.parquet` (GeoParquet) and `data/thessaly_h3.duckdb` |
| `catalog.yaml` | Every column: unit, source, date, caveats. The agent reads this first. |
| `agent/tools.py` | 7 tools: `list_layers`, `area_stats`, `zonal_stats`, `rank_cells`, `describe_place`, `cells_near`, `render_map` |
| `agent/mcp_server.py` | Exposes the tools as an MCP server → Claude Desktop becomes the agent |
| `bench/run_bench.py` | A) reproduce the published map findings; B) combination questions vs. 90 m raster truth |

## Layers (columns)

Terrain (Copernicus GLO-90) · land cover (ESA WorldCover 10 m, 2021) · population (Kontur 2023, H3-native) ·
Storm Daniel flood (Copernicus EMS EMSR692) · roads, solar parks, power lines, substations (OSM via Overture Maps
2026-10-21) · Natura 2000 (EEA) · threatened-species records (GBIF, IUCN CR/EN/VU) · hypothetical Tempe lake
(day 15 method) · heat (ERA5 via Open-Meteo, 2015–2024, ~25 km).

## Run

```bash
pip install geopandas rasterio h3 duckdb exactextract pyarrow requests pyyaml folium mcp osmium
cd pipeline && for s in s0*.py s99_assemble.py; do python $s; done
python ../bench/run_bench.py
```
OSM comes from Overture's public S3 bucket via DuckDB (anonymous); unset AWS credentials if your shell has any.

## Use with Claude Desktop

`claude_desktop_config.json`:
```json
{"mcpServers": {"thessaly-layers": {"command": "python", "args": ["/ABS/PATH/layers-agent/agent/mcp_server.py"]}}}
```
Then ask, e.g. *"Find flat land (<5°) in Larisa outside Natura 2000, not flooded by Daniel, within 3 km of a
substation, and map it."*

## Known limits

- Cell-level thresholds (e.g. `elev_mean_m < 200`) differ from pixel-level answers; see `bench/results.csv`.
- Daniel = one event in 7 mapped AOIs, not a flood-hazard map. "Not flooded" only means something where `daniel_mapped_share > 0`.
- OSM completeness varies (Larissa buildings are "half in tatters", day 14). Power-line voltage and grid capacity unknown.
- ERA5 heat is ~25 km: no local detail.
- Licences: OSM/Overture ODbL (share-alike for derived databases), WorldCover CC BY 4.0, Copernicus DEM/EMS terms, Kontur CC BY 4.0, GBIF per-dataset.
