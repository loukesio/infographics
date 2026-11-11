"""Demo video v2 (~3:50): scene lengths follow the English narration (vo/dur.json); Greek version uses the same timing with Greek captions."""
import sys, json, numpy as np, soundfile as sf
from compose import *
lang = sys.argv[1]; which = sys.argv[2:]
want = lambda s: not which or s in which
J = lambda p: json.load(open(p)); D = J("vo/dur.json"); LEAD = 0.5; times = {}
def sent(key):                       # start time of each sentence inside a narration clip (clips are joined with exact 0.30 s silences)
    a, sr = sf.read(f"vo/{key}.wav"); z = (a == 0).astype(int); d = np.diff(np.r_[0, z, 0]); st, en = np.flatnonzero(d == 1), np.flatnonzero(d == -1)
    return [0.0] + [e / sr for s, e in zip(st, en) if e - s >= int(0.29 * sr)]
def cards(paths, at, T, fin=0.5, fout=0.6):   # full-frame cards: fade in, switch at the given times, fade out
    ims = [Image.open(p).convert("RGB") for p in paths]; bl = Image.new("RGB", ims[0].size, (6, 10, 17)); n = round(T * FPS)
    for i in range(n):
        t = i / FPS; k = max(q for q, a in enumerate(at) if t >= a); im = ims[k]
        if k > 0 and t - at[k] < 0.45: im = blend(ims[k - 1], ims[k], ease((t - at[k]) / 0.45))
        yield blend(bl, im, ease(clamp(min(t / fin, (T - t) / fout))))
def go(name, gen, caps=(), cursor=None, full=False, vo=()):
    d = run(name, lang, gen, caps=caps, cursor=cursor, full=full); times[name] = {"dur": d, "vo": [[k, LEAD + off] for k, off in vo]}
last = lambda n: Image.open(f"out/{n}_last.png").convert("RGB")
blk = Image.new("RGB", (PW, PH), (13, 21, 34))

if want("v00"): go("v00", cards([f"art/card_title_{lang}.png"], [0], D["s0"] + 1.3), full=True, vo=[("s0", 0.1)])
if want("v01"):
    s = sent("s1"); go("v01", cards([f"art/card_hook{v}_{lang}.png" for v in range(4)], [0, LEAD + 1.6, LEAD + s[1] + 0.3, LEAD + s[2]], D["s1"] + 1.6), full=True, vo=[("s1", 0)])
if want("v02"):
    T = D["s2"] + 1.3; Z = Zoom("cap/s2", ["cap/s2/ui0.png", "cap/s2/ui0c.png", "cap/s2/ui1c.png", "cap/s2/ui1.png"]); I = J("cap/s2/info.json"); a = Z.at(0); n = round(.5 * FPS)
    g = seq(xfade(blk, a, 0.6), hold(a, 4.6), (Z.at(0, (i + 1) / n) for i in range(n)), Z.move(9.5, ui=lambda t: 1 + clamp((t - .8) / .2)), (Z.at(1, 2 + (i + 1) / n) for i in range(n)), hold(Z.at(1, 3), T - 15.7))
    sx, sy = I["sim"]; go("v02", g, caps=[("s2a", 0.5, 10.0), ("s2b", 10.4, T - 0.3)], cursor=Cursor([(T - 2.4, 900, 620), (T - 0.8, sx, sy + 4)]), vo=[("s2", 0)])
if want("v03"):
    T = D["s3"] + 1.3; I = J("cap/s3/info.json"); S2 = J("cap/s2/info.json"); K = [page(f"cap/s3/k{k}.jpg") for k in range(6)]; rx, ry, rw, rh = I["range"]; tx = lambda k: rx + 8 + (rw - 16) * k / 7; ty = ry + rh / 2
    Z = Zoom("cap/s3", ["cap/s3/ui0.png", "cap/s3/ui1.png"]); first = page("cap/s2/end.jpg"); sx, sy = S2["sim"]
    def drag(k0, k1, secs):
        n = round(secs * FPS)
        for i in range(n): d = k0 + (k1 - k0) * ease((i + 1) / n); a = int(math.floor(min(d, 4.999))); yield blend(K[a], K[a + 1], d - a)
    g = seq(prev("v02", first, 0.2), hold(first, 0.4), xfade(first, K[0], 0.5), hold(K[0], 2.4), drag(0, 5, 4.6), hold(K[5], 1.6), drag(5, 2, 1.6), hold(K[2], 1.0), xfade(K[2], Z.at(0), 0.3), Z.move(7.0, ui=lambda t: clamp((t - .5) / .3)), hold(Z.at(1, 1), T - 19.6))
    T0 = 3.5; c = Cursor([(0, sx, sy + 4), (0.4, sx, sy + 4), (2.4, sx + 40, sy + 60), (T0, tx(0), ty), (T0 + 4.6, tx(5), ty), (T0 + 6.2, tx(5), ty), (T0 + 7.8, tx(2), ty), (T0 + 9.0, tx(2) + 30, ty - 90), (T - 2.4, tx(2) + 30, ty - 90), (T - 0.8, I["time"][0], I["time"][1] + 4)], clicks=[0.4, T0])
    go("v03", g, caps=[("s3a", 1.0, 12.2), ("s3b", 12.6, T - 0.3)], cursor=c, vo=[("s3", 0)])
if want("v04"):
    T = max(D["s4"] + 1.3, 11.0); I = J("cap/s4/info.json"); S3 = J("cap/s3/info.json"); Tl = [page(f"cap/s4/t{k}.jpg") for k in range(12)]; first = last("v03")
    g = seq(hold(first, 0.4), xfade(first, Tl[0], 0.6), hold(Tl[0], 1.4), steps(Tl, 0.55), hold(Tl[11], T - 8.45))
    px_, py_ = I["play"]; N = J("cap/n/info.json"); c = Cursor([(0, S3["time"][0], S3["time"][1] + 4), (0.4, S3["time"][0], S3["time"][1] + 4), (2.0, px_, py_), (T - 2.2, px_, py_), (T - 0.8, N["wx"][0], N["wx"][1] + 4)], clicks=[0.4, 2.1])
    go("v04", g, caps=[("s4", 1.0, T - 0.3)], cursor=c, vo=[("s4", 0)])
if want("v05"):
    T = D["s4b"] + 1.3; N = J("cap/n/info.json"); Wx = [page(f"cap/n/wx{i}.jpg") for i in range(len(N["wxk"]))]; first = last("v04"); per = min(0.6, (T - 3.4) / (len(Wx) - 1))
    g = seq(hold(first, 0.4), xfade(first, Wx[0], 0.6), hold(Wx[0], 1.0), steps(Wx, per)); g = list(g); g += [Wx[-1]] * max(0, round(T * FPS) - len(g))
    c = Cursor([(0, N["wx"][0], N["wx"][1] + 4), (0.4, N["wx"][0], N["wx"][1] + 4), (1.6, N["wx"][0] + 30, N["wx"][1] + 70), (T - 2.0, N["wx"][0] + 30, N["wx"][1] + 70), (T - 0.7, N["today"][0], N["today"][1] + 4)], clicks=[0.4])
    go("v05", iter(g), caps=[("s4b", 1.0, T - 0.3)], cursor=c, vo=[("s4b", 0)])
if want("v06"):
    T = max(D["s4c"] + 1.6, 5.6); N = J("cap/n/info.json"); S4 = J("cap/s4/info.json"); td = page("cap/n/today.jpg"); first = last("v05")
    c = Cursor([(0, N["today"][0], N["today"][1] + 4), (0.4, N["today"][0], N["today"][1] + 4), (1.8, N["today"][0] + 20, N["today"][1] + 80), (T - 2.0, N["today"][0] + 20, N["today"][1] + 80), (T - 0.7, S4["query"][0], S4["query"][1] + 4)], clicks=[0.4])
    go("v06", seq(hold(first, 0.4), xfade(first, td, 0.7), hold(td, T - 1.1)), caps=[("s4c", 1.0, T - 0.3)], cursor=c, vo=[("s4c", 0.3)])
if want("v07"):
    I = J("cap/s5/info.json"); S4 = J("cap/s4/info.json"); Dd = "cap/s5"; st = page(f"{Dd}/start.jpg"); first = last("v06")
    A = [f"{Dd}/a{i:03d}.jpg" for i in range(I["n1"])]; Bf = [f"{Dd}/b{i:03d}.jpg" for i in range(I["n2"])]; SC = [f"{Dd}/sc{i:03d}.jpg" for i in range(31)]
    th1, r1, r1t, th2, r2 = (page(f"{Dd}/{n}.jpg") for n in ("think1", "res1", "res1top", "think2", "res2")); lastA, lastB, lastS = load(A[-1]), load(Bf[-1]), load(SC[-1])
    tA = I["n1"] * 2 / FPS; tB = I["n2"] * 2 / FPS; s = sent("s5a"); t1 = 3.2 + tA          # typing starts 3.2 s in, as the narration reaches "you ask in plain language"
    tSc = max(t1 + 9.0, LEAD + s[-1] + 2.2); t2 = max(tSc + 2.07 + 3.0, LEAD + D["s5a"] + 0.4) + 1.1; Tend = t2 + max(tB + 0.9 + 1.4 + 0.6 + 3.0, D["s5r"] + 1.0)
    g = seq(hold(first, 0.4), xfade(first, st, 0.6), hold(st, 2.2), frames(A, 2), hold(lastA, 0.9), hold(th1, 1.7), xfade(th1, r1, 0.6), hold(r1, tSc - (t1 + 3.2)), frames(SC, 2), hold(lastS, t2 - 1.1 - (tSc + 62 / FPS)), xfade(lastS, r1t, 0.5), hold(r1t, 0.6),
            frames(Bf, 2), hold(lastB, 0.9), hold(th2, 1.4), xfade(th2, r2, 0.6), hold(r2, Tend - (t2 + tB + 2.9)))
    qx, qy = I["q"]; ax, ay = I["ask"]; t3 = t2 + tB
    c = Cursor([(0, S4["query"][0], S4["query"][1] + 4), (0.4, S4["query"][0], S4["query"][1] + 4), (2.6, qx - 60, qy), (t1, qx + 120, qy + 46), (t1 + 0.7, ax, ay), (t1 + 2.6, ax + 30, ay + 40), (tSc - 0.6, 1380, 520), (t2 - 1.2, 1380, 520), (t2 - 0.3, qx - 60, qy), (t3, qx + 120, qy + 46), (t3 + 0.7, ax, ay), (t3 + 3, ax + 40, ay + 50)], clicks=[0.4, 2.7, t1 + 0.8, t2 - 0.2, t3 + 0.8])
    go("v07", g, caps=[("s5a", 1.0, tSc - 0.6), ("s5b", tSc - 0.2, t2 - 0.5), ("s5c", t2 + 0.1, Tend - 0.3)], cursor=c, vo=[("s5a", 0), ("s5r", t2 - 0.3 - LEAD)])
if want("v08"):
    T = D["s5b"] + 1.4; N = J("cap/n/info.json"); q0, cd, cr, co = (page(f"cap/n/{n}.jpg") for n in ("q0", "card", "crit", "crit_off")); first = last("v07"); cx, cy = N["cell"]; tg = N["tog"]
    g = seq(xfade(first, q0, 0.7), hold(q0, 1.0), xfade(q0, cd, 0.4), hold(cd, 2.5), xfade(cd, cr, 0.5), hold(cr, 1.2), xfade(cr, co, 0.6), hold(co, T - 6.9))
    c = Cursor([(0.3, 1100, 600), (1.6, cx, cy), (4.2, cx + 30, cy + 40), (6.2, tg[0], tg[1]), (T, tg[0] + 20, tg[1] + 30)], clicks=[1.7, 6.3])
    go("v08", g, caps=[("s5d", 0.8, T - 0.3)], cursor=c, vo=[("s5b", 0)])
if want("v09"):
    T = D["s6"] + 1.3; first = last("v08"); r = page("cap/s6/res.jpg")
    go("v09", seq(hold(first, 0.3), xfade(first, r, 0.8), hold(r, T - 1.1)), caps=[("s6", 1.0, T - 0.3)], vo=[("s6", 0)])
if want("v10"):
    T = D["s7"] + 1.3; F = [f"cap/s7/f{i:03d}.jpg" for i in range(135)]; first = last("v09"); f0, f1 = load(F[0]), load(F[-1])
    go("v10", seq(xfade(first, f0, 0.7), hold(f0, 0.5), frames(F), hold(f1, T - 5.7)), caps=[("s7", 0.9, T - 0.3)], vo=[("s7", 0)])
if want("v11"):
    T = D["s8"] + 1.3; s = sent("s8"); pv, bs, bd = (page(f"cap/n/{n}.jpg") for n in ("pv", "bess", "bess_dd")); first = last("v10"); tb = LEAD + s[1] + 3.2; td = LEAD + s[2] - 0.2
    g = seq(xfade(first, pv, 0.7), hold(pv, tb - 0.7), xfade(pv, bs, 0.7), hold(bs, td - tb - 0.7), xfade(bs, bd, 0.6), hold(bd, T - td - 0.6))
    go("v11", g, caps=[("s8p", 0.8, tb - 0.2), ("s8c", tb + 0.3, T - 0.3)], vo=[("s8", 0)])
if want("v12"):
    T = D["s8a"] + 1.3; I = J("cap/s8/info.json"); Lr = [page(f"cap/s8/l{k}.jpg") for k in range(3)]; first = last("v11"); o, n = I["official"], I["natura"]
    g = seq(xfade(first, Lr[0], 0.7), hold(Lr[0], 1.3), xfade(Lr[0], Lr[1], 0.6), hold(Lr[1], 2.2), xfade(Lr[1], Lr[2], 0.6), hold(Lr[2], T - 5.4))
    go("v12", g, caps=[("s8", 1.0, T - 0.3)], cursor=Cursor([(0.6, 700, 500), (1.9, o[0], o[1]), (3.6, o[0], o[1]), (4.7, n[0], n[1]), (7.0, n[0] + 50, n[1] + 30)], clicks=[2.0, 4.8]), vo=[("s8a", 0)])
if want("v13"):
    s = sent("s9"); go("v13", cards([f"art/card_future{v}_{lang}.png" for v in range(5)], [0] + [LEAD + x + 0.2 for x in s[1:5]], D["s9"] + 1.5), full=True, vo=[("s9", 0)])
if want("v14"): go("v14", cards([f"art/card_end_{lang}.png"], [0], D["s10"] + 6.5, fout=1.0), full=True, vo=[("s10", 0.2)])
if times:
    try: old = J(f"out/times_{lang}.json")
    except Exception: old = {}
    old.update(times); json.dump(old, open(f"out/times_{lang}.json", "w"), indent=1)
