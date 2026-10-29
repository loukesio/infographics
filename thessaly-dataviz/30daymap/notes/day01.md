# Day 01 · Points — Nearly a third of Thessaly's settlements sit above 500 m

**Idea**
Every city, town, village and hamlet of Thessaly as one dot, coloured by the height it sits at. Pale dots fill the
plain, dark ones ring it in the mountains; a dot histogram below stacks all settlements by elevation.

**Data**
- OpenStreetMap, nodes with `place = city/town/village/hamlet`, Geofabrik Greece extract of 28 Oct 2026,
  https://download.geofabrik.de/europe/greece.html — ODbL. Compact copy: `30daymap/data/day01_settlements.csv`.
- Copernicus GLO-90 DEM, https://registry.opendata.aws/copernicus-dem/ — free licence (© DLR/Airbus, ESA).
- Border: Eurostat GISCO NUTS 2021 (EL61, with Sporades).

**How**
- `m30_osm("points", ...)` clipped to the region (incl. Sporades); DEM value sampled at every node (`terra::extract`).
- Six elevation classes, one brown sequential ramp; dot size by place type; faint multi-direction hillshade underneath.
- Dot histogram: 50 m bins, four dots wide; `patchwork`, `shadowtext`, `ggnewscale`.

**Finding**
1,002 settlements; 309 (30.8%) above 500 m; median elevation 227 m; villages + hamlets only: 31.9% above 500 m.
Highest: the hamlet Στεφάνι (W Pindos, 21.30 E 39.68 N), 1,358 m.

**Caveats**
- `village` vs `hamlet` is a mapper's choice, not the ELSTAT list of local communities; some abandoned or seasonal
  (summer) settlements may be tagged.
- Elevation = 90 m DEM cell under the OSM node (usually the village square).

**Status**
done
