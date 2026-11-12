"""Checks of the layers added on 12/11/2026 against independent evidence. Writes bench/checks.csv.
1. Fire: FSim fuels end in 2018-2020, so the EFFIS burns of 2021-2026 are an out-of-sample test. Do they fall in the cells
   FSim ranks high? (lift = share of burned cells in the top quarter of hazard / 25 %).
2. Ground motion: the fastest-sinking cell near Platykampos must be sinking (literature: tens of mm/yr in the Larissa plain).
3. Access: villages reported cut off in Storm Daniel must come out cut off when the Daniel roads are closed."""
import pathlib, json, numpy as np, pandas as pd, h3
R = pathlib.Path(__file__).resolve().parents[1]; D = R / "data"
g = pd.read_parquet(D / "thessaly_h3.parquet", columns=["h3", "in_region", "population"])
f = g.merge(pd.read_parquet(D / "fire_h3.parquet"), on="h3"); f = f[(f.in_region > .5) & (f.fire_burnable > .2)]
q75 = f.fire_hazard.quantile(.75); burned = f[f.burned_2021_share > .3]
share = (burned.fire_hazard >= q75).mean(); lift = share / .25
rows = [dict(check="Fire: EFFIS burns 2021-2026 in the top quarter of FSim hazard", value=round(share * 100, 1), unit="% of burned cells",
             reference="25 % if FSim had no skill", ok=bool(share > .25), note=f"lift {lift:.2f}x, {len(burned)} burned cells")]
gm = pd.read_parquet(D / "ground_h3.parquet").set_index("h3")
near = [c for c in h3.grid_disk(h3.latlng_to_cell(39.57, 22.545, 8), 2) if c in gm.index]
v = gm.loc[near].query("gm_cover >= .15").gm_vel_mm.min()
rows.append(dict(check="Ground: fastest sinking near Platykampos (2021-2025)", value=round(float(v), 1), unit="mm/yr",
                 reference="sinking (Vassilopoulou 2013: up to -25 mm/yr in the Larissa plain, earlier period)", ok=bool(v < -10), note="EGMS Ortho vertical"))
ac = pd.read_parquet(D / "access_h3.parquet").set_index("h3")
VIL = {"Βλοχός": (39.4693, 21.9832), "Μεταμόρφωση": (39.3833, 22.0667), "Κοσκινάς": (39.4342, 22.0600)}
for n, (la, lo) in VIL.items():
    cs = [c for c in h3.grid_disk(h3.latlng_to_cell(la, lo, 8), 1) if c in ac.index]
    cut = bool(ac.loc[cs].cut_dan.max() == 1) if cs else False
    rows.append(dict(check=f"Access: {n} cut off with Daniel roads closed", value=int(cut), unit="0/1", reference="1 (reported cut off in Sept 2023, press)", ok=cut, note="village point +-1 cell"))
out = pd.DataFrame(rows); out.to_csv(R / "bench/checks.csv", index=False); print(out.to_string())
