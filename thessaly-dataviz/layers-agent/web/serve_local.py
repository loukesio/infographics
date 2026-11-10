#!/usr/bin/env python3
"""Local demo server: serves this folder and relays aerial orthophotos from the Hellenic Cadastre viewing service
(gis.ktimanet.gr, WMS layer BASEMAP) so the page can drape them under the 3D buildings.

    python3 serve_local.py            # then open http://localhost:8765

The imagery is fetched live for viewing on this machine only (kept in memory, never written to disk or republished).
© Ελληνικό Κτηματολόγιο. Do not host copies without the Cadastre's permission."""
import sys, json, urllib.request, urllib.parse, pathlib, threading
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
ROOT = pathlib.Path(__file__).resolve().parent
WMS = "http://gis.ktimanet.gr/wms/wmsopen/wmsserver.aspx"
CACHE, LOCK = {}, threading.Lock()
class H(SimpleHTTPRequestHandler):
    def __init__(self, *a, **k): super().__init__(*a, directory=str(ROOT), **k)
    def log_message(self, *a): pass
    def do_GET(self):
        u = urllib.parse.urlparse(self.path)
        if u.path != "/ortho": return super().do_GET()
        q = urllib.parse.parse_qs(u.query)
        if "ping" in q: return self._send(200, "application/json", json.dumps({"ok": True}).encode())
        try:
            x0, y0, x1, y1 = [float(v) for v in q["bbox"][0].split(",")]; w, h = int(q["w"][0]), int(q["h"][0])
            assert 20.9 <= x0 < x1 <= 24.4 and 38.8 <= y0 < y1 <= 40.3 and x1 - x0 <= 0.05 and 64 <= w <= 2048 and 64 <= h <= 2048
        except Exception: return self._send(400, "text/plain", b"bad request")
        key = (x0, y0, x1, y1, w, h)
        with LOCK: data = CACHE.get(key)
        if data is None:
            url = WMS + "?" + urllib.parse.urlencode({"SERVICE": "WMS", "VERSION": "1.1.0", "REQUEST": "GetMap", "LAYERS": "BASEMAP", "STYLES": "", "SRS": "EPSG:4326",
                                                     "BBOX": f"{x0},{y0},{x1},{y1}", "WIDTH": w, "HEIGHT": h, "FORMAT": "image/jpeg"})
            try: data = urllib.request.urlopen(url, timeout=40).read()
            except Exception as e: return self._send(502, "text/plain", str(e).encode())
            with LOCK:
                if len(CACHE) > 150: CACHE.clear()
                CACHE[key] = data
        self._send(200, "image/jpeg", data)
    def _send(self, code, ctype, body):
        self.send_response(code); self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body))); self.send_header("Cache-Control", "no-store"); self.end_headers(); self.wfile.write(body)
if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    print(f"Thessaly Layers Agent (local, with Cadastre orthophotos): http://localhost:{port}")
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()
