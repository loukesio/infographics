"""Step 9: ERA5 reanalysis via Open-Meteo archive API, 0.5 deg points (~50 km), 2015-2024: heat days and 2 Aug 2021.
Every H3 cell takes the value of its nearest point. Resumable: one JSON per point in cache/era5/ (Open-Meteo throttles)."""
import requests, numpy as np, pandas as pd, time, json
from scipy.spatial import cKDTree
from common import CACHE, DATA
d = CACHE / "era5"; d.mkdir(exist_ok=True)
pts = [(la, lo) for la in np.arange(39.0, 40.5, 0.5) for lo in np.arange(21.0, 24.5, 0.5)]
for la, lo in pts:
    f = d / f"{la:.2f}_{lo:.2f}.json"
    if f.exists(): continue
    q = dict(latitude=la, longitude=lo, start_date="2015-01-01", end_date="2024-12-31",
             daily="temperature_2m_max,apparent_temperature_max", timezone="Europe/Athens")
    for k in range(10):
        try:
            r = requests.get("https://archive-api.open-meteo.com/v1/archive", params=q, timeout=120)
            if r.status_code == 200: f.write_text(r.text); print("ok", la, lo, flush=True); break
            print("status", r.status_code, flush=True)
        except Exception as ex: print("retry", type(ex).__name__, flush=True)
        time.sleep(45 * (k + 1))
rows = []
for la, lo in pts:
    f = d / f"{la:.2f}_{lo:.2f}.json"
    if not f.exists(): continue
    dd = pd.DataFrame(json.loads(f.read_text())["daily"]); t = dd.temperature_2m_max
    rows.append(dict(lat=la, lon=lo, heat_days_35=(t >= 35).sum() / 10, heat_days_40=(t >= 40).sum() / 10,
                     tmax_jja_mean=t[pd.to_datetime(dd.time).dt.month.isin([6, 7, 8])].mean(),
                     app_tmax_2021_08_02=float(dd.loc[dd.time == "2021-08-02", "apparent_temperature_max"].iloc[0])))
e = pd.DataFrame(rows); print(len(e), "of", len(pts), "points")
g = pd.read_parquet(DATA / "grid.parquet", columns=["h3", "lat", "lon"])
_, idx = cKDTree(e[["lat", "lon"]].values).query(g[["lat", "lon"]].values)
out = pd.concat([g[["h3"]].reset_index(drop=True), e.iloc[idx][["heat_days_35", "heat_days_40", "tmax_jja_mean", "app_tmax_2021_08_02"]].reset_index(drop=True)], axis=1)
out.to_parquet(DATA / "l_heat.parquet"); print(out.describe().T[["mean", "min", "max"]])
