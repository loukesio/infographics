"""Shared paths and helpers for the Thessaly layers pipeline."""
import os, json, urllib.request, pathlib
ROOT = pathlib.Path(__file__).resolve().parents[1]
CACHE = ROOT / "cache"; DATA = ROOT / "data"
CACHE.mkdir(exist_ok=True); DATA.mkdir(exist_ok=True)
H3_RES = 8
CRS_GR = 2100

def fetch(url, name=None, tries=3):
    p = CACHE / (name or url.rstrip("/").split("/")[-1].split("?")[0])
    if p.exists() and p.stat().st_size > 0:
        return p
    last = None
    for _ in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "thessaly-layers-agent/0.1"})
            with urllib.request.urlopen(req, timeout=300) as r, open(str(p) + ".part", "wb") as f:
                while chunk := r.read(1 << 20):
                    f.write(chunk)
            os.replace(str(p) + ".part", p)
            return p
        except Exception as e:  # retry
            last = e
    raise RuntimeError(f"download failed {url}: {last}")
