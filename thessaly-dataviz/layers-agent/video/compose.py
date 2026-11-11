"""Compositor: draws every output frame (window background, page content, cursor, caption) and pipes it to ffmpeg. One file per scene and language."""
import sys, os, json, math, subprocess, numpy as np
from PIL import Image, ImageDraw
W, H, FPS = 1920, 1080, 30; PX, PY, PW, PH = 160, 52, 1600, 900
ease = lambda t: 4 * t ** 3 if t < .5 else 1 - (-2 * t + 2) ** 3 / 2
clamp = lambda t: max(0.0, min(1.0, t))
_cache = {}
def page(path):                      # full-page still → 1600x900 RGB
    if path not in _cache: _cache[path] = Image.open(path).convert("RGB").resize((PW, PH), Image.LANCZOS)
    return _cache[path]
def rgba(path, size=None):
    k = (path, size)
    if k not in _cache: im = Image.open(path).convert("RGBA"); _cache[k] = im.resize(size, Image.LANCZOS) if size else im
    return _cache[k]
def blend(a, b, t): return a if t <= 0 else b if t >= 1 else Image.blend(a, b, t)
MASK = Image.new("L", (PW, PH), 0); ImageDraw.Draw(MASK).rounded_rectangle((0, -20, PW - 1, PH - 1), 12, fill=255)
CUR = rgba("art/cursor.png", (30, 30))

class Cursor:                        # keyframed pointer: pts = [(t, x, y)], clicks = [t]; coordinates in page px
    def __init__(self, pts, clicks=()): self.p = sorted(pts); self.c = list(clicks)
    def at(self, t):
        p = self.p
        if t < p[0][0] or t > p[-1][0] + 0.6: return None
        for (t0, x0, y0), (t1, x1, y1) in zip(p, p[1:]):
            if t0 <= t <= t1: f = ease((t - t0) / max(t1 - t0, 1e-6)); x, y = x0 + (x1 - x0) * f, y0 + (y1 - y0) * f; break
        else: x, y = p[-1][1], p[-1][2]
        ring = min((t - c for c in self.c if 0 <= t - c < 0.45), default=None)
        return x, y, ring

def frame(bg, pg, cur, caps):
    f = bg.copy(); f.paste(pg, (PX, PY), MASK)
    if cur:
        x, y, ring = cur; X, Y = PX + x, PY + y
        if ring is not None: r = 10 + 46 * ring / 0.45; a = int(230 * (1 - ring / 0.45)); ov = Image.new("RGBA", f.size, (0, 0, 0, 0)); ImageDraw.Draw(ov).ellipse((X - r, Y - r, X + r, Y + r), outline=(242, 163, 58, a), width=4); f.paste(ov, (0, 0), ov)
        f.paste(CUR, (int(X - 5), int(Y - 3)), CUR)
    for im, a in caps:
        if a > 0: c = im if a >= 1 else Image.fromarray((np.asarray(im) * np.array([1, 1, 1, a])).astype("uint8"), "RGBA"); f.paste(c, (0, 952), c)
    return f

class Out:
    def __init__(self, name):
        os.makedirs("out", exist_ok=True); self.tmp, self.final = f"out/{name}.tmp.mp4", f"out/{name}.mp4"
        self.ff = subprocess.Popen(["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-", "-c:v", "libx264", "-crf", "17", "-preset", "medium", "-pix_fmt", "yuv420p", "-movflags", "+faststart", self.tmp], stdin=subprocess.PIPE)
        self.n = 0
    def write(self, im): self.ff.stdin.write(im.tobytes()); self.n += 1
    def close(self):
        self.ff.stdin.close(); assert self.ff.wait() == 0; os.replace(self.tmp, self.final); print(self.final, self.n, "frames", round(self.n / FPS, 2), "s", flush=True)

def run(name, lang, gen, caps=(), cursor=None, full=False):
    """gen yields page images (or full 1920x1080 frames if full). caps = [(id, t0, t1)] in scene seconds."""
    bg = Image.open(f"art/bg_{lang}.png").convert("RGB"); o = Out(f"{name}_{lang}"); ci = [(rgba(f"art/cap_{i}_{lang}.png"), a, b) for i, a, b in caps]; last = None
    for k, pg in enumerate(gen):
        t = k / FPS
        if full: o.write(pg); continue
        cs = [(im, clamp(min((t - a) / .35, (b - t) / .35))) for im, a, b in ci]
        o.write(frame(bg, pg, cursor.at(t) if cursor else None, cs)); last = pg
    o.close()
    if last is not None: last.save(f"out/{name}_last.png")
    return o.n / FPS

# ---------- primitives (generators of page images) ----------
def hold(im, secs):
    for _ in range(round(secs * FPS)): yield im
def xfade(a, b, secs):
    n = round(secs * FPS)
    for i in range(n): yield blend(a, b, ease((i + 1) / n))
def seq(*gens):
    for g in gens: yield from g
def prev(name, first, secs=0.5):     # crossfade in from the previous scene's last page
    p = f"out/{name}_last.png"
    if os.path.exists(p): yield from xfade(Image.open(p).convert("RGB"), first, secs)
merc = lambda lon, lat, z: ((lon + 180) / 360 * 512 * 2 ** z, (1 - math.log(math.tan(math.pi / 4 + lat * math.pi / 360)) / math.pi) / 2 * 512 * 2 ** z)
class Zoom:
    """Map-only stills along a zoom path + UI overlays with a transparent map hole → smooth camera move at any speed."""
    def __init__(self, d, uis):
        self.m = json.load(open(f"{d}/meta.json")); self.st = self.m["stills"]; self.im = [Image.open(f"{d}/m{k}.jpg").convert("RGB") for k in range(len(self.st))]
        self.r = [round(v) for v in self.m["rect"]]; self.ui = [rgba(u, (PW, PH)) for u in uis]; self.sc = self.im[0].width / self.m["rect"][2]
    def cam(self, f):                # f in 0..1 along the path: zoom linear, centre on the same convergence path as the stills
        s = self.st; z = s[0]["z"] + (s[-1]["z"] - s[0]["z"]) * f; a, b = (s[0], s[-1]) if s[-1]["z"] > s[0]["z"] else (s[-1], s[0])
        g = (2 ** (a["z"] - z) - 2 ** (a["z"] - b["z"])) / (1 - 2 ** (a["z"] - b["z"])); A, B = merc(a["lon"], a["lat"], 0), merc(b["lon"], b["lat"], 0)
        return (B[0] + (A[0] - B[0]) * g) * 2 ** z, (B[1] + (A[1] - B[1]) * g) * 2 ** z, z
    def still(self, k, cx, cy, z, w, h):
        s = self.st[k]; sc = 2 ** (z - s["z"]); kx, ky = merc(s["lon"], s["lat"], s["z"]); q = self.sc; a = q / sc
        im = self.im[k].transform((w, h), Image.AFFINE, (a, 0, q * ((cx - w / 2) / sc - kx + w / 2), 0, a, q * ((cy - h / 2) / sc - ky + h / 2)), Image.BICUBIC)
        cov = Image.new("L", self.im[k].size, 255).transform((w, h), Image.AFFINE, (a, 0, q * ((cx - w / 2) / sc - kx + w / 2), 0, a, q * ((cy - h / 2) / sc - ky + h / 2)), Image.BILINEAR)
        return im, cov
    def at(self, f, uimix=0.0):
        x, y, w, h = self.r; cx, cy, z = self.cam(f); s = self.st; pos = (z - s[0]["z"]) / (s[1]["z"] - s[0]["z"]); k = min(len(s) - 2, max(0, int(math.floor(pos + 1e-9)))); fr = pos - k
        closer, wider = (k + 1, k) if s[1]["z"] > s[0]["z"] else (k, k + 1); fc = fr if closer == k + 1 else 1 - fr       # fc: 0 at the wider still, 1 at the closer one
        base, _ = self.still(wider, cx, cy, z, w, h)
        if fc > 0.02: top, cov = self.still(closer, cx, cy, z, w, h); al = clamp((fc - 0.15) / 0.6); base.paste(top, (0, 0), cov.point(lambda v: int(v * al)))
        pg = Image.new("RGB", (PW, PH), (13, 21, 34)); pg.paste(base, (x, y))
        u = self.uimix(uimix); pg.paste(u, (0, 0), u); return pg
    def uimix(self, m):              # m = position along the list of UI overlays (0 = first, 1.5 = halfway between the 2nd and 3rd)
        k = min(len(self.ui) - 1, max(0, int(math.floor(m)))); f = m - k
        return self.ui[k] if f <= 0 or k + 1 >= len(self.ui) else Image.blend(self.ui[k], self.ui[k + 1], f)
    def move(self, secs, f0=0.0, f1=1.0, ui=lambda t: 0.0):
        n = round(secs * FPS)
        for i in range(n): t = i / max(n - 1, 1); yield self.at(f0 + (f1 - f0) * ease(t), ui(t))
def card(path, secs, fin=0.5, fout=0.5):
    im = Image.open(path).convert("RGB"); bl = Image.new("RGB", im.size, (6, 10, 17)); n = round(secs * FPS)
    for i in range(n): t = i / FPS; a = clamp(min(t / fin, (secs - t) / fout)); yield blend(bl, im, ease(a))

def load(path): return Image.open(path).convert("RGB").resize((PW, PH), Image.LANCZOS)     # uncached, for long frame sequences
def frames(paths, per=1):
    for q in paths:
        im = load(q)
        for _ in range(per): yield im
def steps(imgs, secs_each, fade=0.6):    # a row of states: crossfade into each, then rest on it
    for a, b in zip(imgs, imgs[1:]): yield from xfade(a, b, secs_each * fade); yield from hold(b, secs_each * (1 - fade))
