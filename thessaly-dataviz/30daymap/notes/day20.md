# Day 20 · Hexagons — Half of Thessaly lives in 8 hexagons

**Idea**
Kontur's 400 m hexagons summed into 397 H3 resolution-6 cells (~41 km² each) and drawn as hexagonal prisms in a
hand-built oblique view, height = residents. The 8 tallest prisms, which together hold half of the people, are in
orange; a strip of all 397 cells ranked shows how fast the rest falls away. Different from t12: chunky H3 cells,
pure ggplot (no rayshader), one accent + greys.

**Data**
- Kontur Population Greece 2023-11-01, 400 m H3 hexagons (res 8) — HDX, CC BY 4.0.
  https://data.humdata.org/dataset/kontur-population-greece
- H3 grid (Uber, Apache 2.0) via h3jsr · Eurostat GISCO NUTS 2021 EL61, mainland.

**How**
- Res-8 hexagons with centre in mainland Thessaly → `h3jsr::get_parent(res = 6)` → summed
  (`30daymap/data/day20_h3res6_population.csv`).
- Oblique projection screen_y = 0.62·y + z, z linear in population; only south-facing walls drawn; painter's order
  north → south. All in ggplot2 polygons (no 3D engine), patchwork for the strip.
- Labels = nearest of the 9 base towns within 12 km of a top cell; population summed per town.

**Finding**
**8 of 397 res-6 hexagons hold 51.5% of 678,559 people on 2.0% of the hexagon area (329 of 16,317 km²).**
Volos 103,000 (one cell), Larissa 139,500 (3 cells), Trikala 54,400, Karditsa 41,700 (2 cells), Tyrnavos 11,100.

**Caveats**
Kontur is modelled population (2023). Res-6 cells on the border stick out of the region, so the area base (16,317 km²)
is larger than the region (13,774 km²). Cell edges cut through towns (Larissa splits over 3 cells). The second
"Karditsa" cell (11,161 people) is the cell within 12 km of Karditsa, not necessarily the town itself. No rayshader
render was made — the hand-made ggplot prisms read more cleanly; a rayshader pass is possible if Loukas wants one.

**Status**
done
