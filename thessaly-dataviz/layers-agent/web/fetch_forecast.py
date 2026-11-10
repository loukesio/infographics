"""Rain/temperature/wind forecast for the next 72 h over Thessaly from MET Norway Locationforecast 2.0
(api.met.no, ECMWF-based for Greece, CC BY 4.0). 0.25° point grid → assets/forecast.json.
Usage: python fetch_forecast.py [out_path]"""
import sys, json, time, datetime as dt, urllib.request
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/forecast.json"
UA = {"User-Agent": "thessaly-layers-agent/0.1 (github.com/loukesio/infographics)"}
lats = [round(38.9 + 0.25 * i, 2) for i in range(6)]; lons = [round(21.0 + 0.25 * j, 2) for j in range(14)]
pts = [(la, lo) for la in lats for lo in lons]
now = dt.datetime.now(dt.timezone.utc).replace(minute=0, second=0, microsecond=0)
steps = [now + dt.timedelta(hours=3 * k) for k in range(25)]          # 0..72 h
rain, temp, wind, sym = [], [], [], []
for la, lo in pts:
    for k in range(4):
        try:
            req = urllib.request.Request(f"https://api.met.no/weatherapi/locationforecast/2.0/compact?lat={la}&lon={lo}", headers=UA)
            js = json.load(urllib.request.urlopen(req, timeout=60)); break
        except Exception as e:
            time.sleep(3 * (k + 1)); js = None
    if js is None: raise SystemExit(f"failed {la},{lo}")
    hourly = {}                                               # hour -> mm
    tser = js["properties"]["timeseries"]
    temps = {}; winds = {}; syms = {}
    for e in tser:
        t = dt.datetime.fromisoformat(e["time"].replace("Z", "+00:00")); d = e["data"]
        temps[t] = d["instant"]["details"].get("air_temperature"); winds[t] = d["instant"]["details"].get("wind_speed")
        sm = (d.get("next_1_hours") or d.get("next_6_hours") or {}).get("summary", {}).get("symbol_code")
        if sm: syms[t] = sm
        if "next_1_hours" in d: hourly[t] = d["next_1_hours"]["details"].get("precipitation_amount", 0)
        elif "next_6_hours" in d:
            for h in range(6):
                hourly.setdefault(t + dt.timedelta(hours=h), d["next_6_hours"]["details"].get("precipitation_amount", 0) / 6)
    cum, acc = [], 0.0
    for k, s in enumerate(steps):
        if k: acc += sum(v for t, v in hourly.items() if steps[k - 1] <= t < s)
        cum.append(round(acc, 1))
    near = lambda d, s: d[min(d, key=lambda t: abs((t - s).total_seconds()))]
    sym.append([near(syms, s) if syms else "" for s in steps]); rain.append(cum); temp.append([round(near(temps, s) or 0, 1) for s in steps]); wind.append([round(near(winds, s) or 0, 1) for s in steps])
    time.sleep(0.1)
out = {"source": "MET Norway Locationforecast 2.0 (api.met.no), CC BY 4.0", "issued": now.isoformat(), "fetched": dt.datetime.now(dt.timezone.utc).isoformat(timespec="minutes"),
       "lats": lats, "lons": lons, "steps": [s.isoformat() for s in steps], "rain_cum_mm": rain, "temp_c": temp, "wind_ms": wind, "symbol": sym}
json.dump(out, open(OUT, "w"), separators=(",", ":"))
print("points", len(pts), "max 72h rain mm", max(r[-1] for r in rain), "fetched", out["fetched"])
