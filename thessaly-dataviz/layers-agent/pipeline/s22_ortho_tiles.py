"""Aerial orthophoto tiles (Hellenic Cadastre viewing service, WMS BASEMAP) for the cities and selected settlements.
→ web/assets/ortho/<i>_<j>.jpg (1280 px, ~1.3 m/px) and web/assets/ortho/lo/<i>_<j>.jpg (320 px previews) + manifest.json.
© Ελληνικό Κτηματολόγιο. Hosting copies requires the Cadastre's permission (see data/raw/README.md). Tiles are kept out of git."""
import math, json, time, io, urllib.request, urllib.parse, pathlib
from PIL import Image
R = pathlib.Path(__file__).resolve().parents[1]; OUT = R / "web/assets/ortho"; (OUT / "lo").mkdir(parents=True, exist_ok=True)
AREAS = {"larisa": (22.355, 39.595, 22.475, 39.675), "volos": (22.895, 39.335, 22.995, 39.405), "trikala": (21.725, 39.525, 21.805, 39.585), "karditsa": (21.885, 39.34, 21.955, 39.39)}
AREAS.update({k: tuple(v[1:]) for k, v in json.load(open(R / "data/places.json")).items()})
ODX, ODY = 0.02, 0.015; WMS = "http://gis.ktimanet.gr/wms/wmsopen/wmsserver.aspx"; keys = set()
for name, (a, b, c, d) in AREAS.items():
    for i in range(math.floor(a / ODX), math.floor(c / ODX) + 1):
        for j in range(math.floor(b / ODY), math.floor(d / ODY) + 1):
            k = f"{i}_{j}"; f = OUT / f"{k}.jpg"; keys.add(k)
            if not f.exists():
                x0, y0 = round(i * ODX, 4), round(j * ODY, 4)
                u = WMS + "?" + urllib.parse.urlencode({"SERVICE": "WMS", "VERSION": "1.1.0", "REQUEST": "GetMap", "LAYERS": "BASEMAP", "STYLES": "", "SRS": "EPSG:4326",
                    "BBOX": f"{x0},{y0},{round(x0 + ODX, 4)},{round(y0 + ODY, 4)}", "WIDTH": 1280, "HEIGHT": 1242, "FORMAT": "image/jpeg"})
                for t in range(3):
                    try: Image.open(io.BytesIO(urllib.request.urlopen(u, timeout=60).read())).convert("RGB").save(f, quality=80, optimize=True); break
                    except Exception as e: print("retry", k, e, flush=True); time.sleep(5)
                time.sleep(0.6)
            lo = OUT / "lo" / f"{k}.jpg"
            if f.exists() and not lo.exists(): Image.open(f).resize((320, 310), Image.LANCZOS).save(lo, quality=72, optimize=True)
    print(name, len(keys), flush=True)
m = json.load(open(OUT / "manifest.json")) if (OUT / "manifest.json").exists() else {}
m.update({"keys": sorted(k for k in keys if (OUT / f"{k}.jpg").exists()), "lo": True, "w": 1280, "h": 1242}); json.dump(m, open(OUT / "manifest.json", "w"), ensure_ascii=False)
