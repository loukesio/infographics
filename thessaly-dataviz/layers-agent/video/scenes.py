import sys, json
from compose import *
lang = sys.argv[1]; which = sys.argv[2:] 
def want(s): return not which or s in which
J = lambda p: json.load(open(p))
if want("s0"): run("s0", lang, card(f"art/card_title_{lang}.png", 4.5), full=True)
if want("s1"): run("s1", lang, card(f"art/card_hook_{lang}.png", 8.0), full=True)
if want("s2"):
    Z = Zoom("cap/s2", ["cap/s2/ui0.png", "cap/s2/ui0c.png", "cap/s2/ui1c.png", "cap/s2/ui1.png"]); I = J("cap/s2/info.json"); a = Z.at(0)
    blk = Image.new("RGB", (PW, PH), (13, 21, 34)); n = round(.5 * FPS)
    g = seq(xfade(blk, a, 0.6), hold(a, 2.6), (Z.at(0, (i + 1) / n) for i in range(n)), Z.move(9.0, ui=lambda t: 1 + clamp((t - .8) / .2)), (Z.at(1, 2 + (i + 1) / n) for i in range(n)), hold(Z.at(1, 3), 3.4))
    sx, sy = I["sim"]; c = Cursor([(14.0, 900, 620), (15.6, sx, sy + 4)])
    run("s2", lang, g, caps=[("s2a", 0.5, 7.4), ("s2b", 7.8, 16.4)], cursor=c)
if want("s3"):
    I = J("cap/s3/info.json"); S2 = J("cap/s2/info.json"); K = [page(f"cap/s3/k{k}.jpg") for k in range(6)]; rx, ry, rw, rh = I["range"]; tx = lambda k: rx + 8 + (rw - 16) * k / 7; ty = ry + rh / 2
    Z = Zoom("cap/s3", ["cap/s3/ui0.png", "cap/s3/ui1.png"]); first = page("cap/s2/end.jpg"); sx, sy = S2["sim"]
    def drag(k0, k1, secs):
        n = round(secs * FPS)
        for i in range(n): d = k0 + (k1 - k0) * ease((i + 1) / n); a = int(math.floor(min(d, 4.999))); yield blend(K[a], K[a + 1], d - a)
    z0 = Z.at(0)
    g = seq(prev("s2", first, 0.2), hold(first, 0.4), xfade(first, K[0], 0.5), hold(K[0], 2.0), drag(0, 5, 4.2), hold(K[5], 1.4), drag(5, 2, 1.6), hold(K[2], 1.0), xfade(K[2], z0, 0.3), Z.move(7.0, ui=lambda t: clamp((t - .5) / .3)), hold(Z.at(1, 1), 4.2))
    T0 = 3.1; c = Cursor([(0, sx, sy + 4), (0.4, sx, sy + 4), (2.2, sx + 40, sy + 60), (T0, tx(0), ty), (T0 + 4.2, tx(5), ty), (T0 + 5.6, tx(5), ty), (T0 + 7.2, tx(2), ty), (T0 + 8.4, tx(2) + 30, ty - 90), (21.0, tx(2) + 30, ty - 90), (22.6, I["time"][0], I["time"][1] + 4)], clicks=[0.4, T0])
    run("s3", lang, g, caps=[("s3a", 1.0, 11.6), ("s3b", 12.0, 22.8)], cursor=c)
if want("s4"):
    I = J("cap/s4/info.json"); S3 = J("cap/s3/info.json"); T = [page(f"cap/s4/t{k}.jpg") for k in range(12)]; first = Image.open("out/s3_last.png").convert("RGB")
    g = seq(hold(first, 0.4), xfade(first, T[0], 0.6), hold(T[0], 1.4), steps(T, 0.55), hold(T[11], 2.6))
    px_, py_ = I["play"]; c = Cursor([(0, S3["time"][0], S3["time"][1] + 4), (0.4, S3["time"][0], S3["time"][1] + 4), (2.0, px_, py_), (9.4, px_, py_), (10.8, I["query"][0], I["query"][1] + 4)], clicks=[0.4, 2.1])
    run("s4", lang, g, caps=[("s4", 1.0, 11.0)], cursor=c)
if want("s5"):
    I = J("cap/s5/info.json"); S4 = J("cap/s4/info.json"); D = "cap/s5"; st = page(f"{D}/start.jpg"); first = Image.open("out/s4_last.png").convert("RGB")
    A = [f"{D}/a{i:03d}.jpg" for i in range(I["n1"])]; Bf = [f"{D}/b{i:03d}.jpg" for i in range(I["n2"])]; SC = [f"{D}/sc{i:03d}.jpg" for i in range(31)]
    th1, r1, r1t, th2, r2 = (page(f"{D}/{n}.jpg") for n in ("think1", "res1", "res1top", "think2", "res2")); lastA, lastB, lastS = load(A[-1]), load(Bf[-1]), load(SC[-1])
    tA = I["n1"] * 2 / FPS; tB = I["n2"] * 2 / FPS
    g = seq(hold(first, 0.4), xfade(first, st, 0.6), hold(st, 1.2), frames(A, 2), hold(lastA, 0.9), hold(th1, 1.7), xfade(th1, r1, 0.6), hold(r1, 3.6), frames(SC, 2), hold(lastS, 3.4), xfade(lastS, r1t, 0.5), hold(r1t, 0.6),
            frames(Bf, 2), hold(lastB, 0.9), hold(th2, 1.4), xfade(th2, r2, 0.6), hold(r2, 5.0))
    qx, qy = I["q"]; ax, ay = I["ask"]; t1 = 2.2 + tA; t2 = t1 + 0.9 + 1.7 + 0.6 + 3.6 + 62 / FPS + 3.4 + 0.5 + 0.6; t3 = t2 + tB
    c = Cursor([(0, S4["query"][0], S4["query"][1] + 4), (0.4, S4["query"][0], S4["query"][1] + 4), (1.6, qx - 60, qy), (t1, qx + 120, qy + 46), (t1 + 0.7, ax, ay), (t1 + 2.6, ax + 30, ay + 40), (t1 + 6.4, 1380, 520), (t2 - 1.2, 1380, 520), (t2 - 0.3, qx - 60, qy), (t3, qx + 120, qy + 46), (t3 + 0.7, ax, ay), (t3 + 3, ax + 40, ay + 50)], clicks=[0.4, 1.7, t1 + 0.8, t2 - 0.2, t3 + 0.8])
    run("s5", lang, g, caps=[("s5a", 1.0, t1 + 5.6), ("s5b", t1 + 6.0, t2 - 0.4), ("s5c", t2 + 0.2, t3 + 8.2)], cursor=c)
if want("s6"):
    I = J("cap/s6/info.json"); S5 = J("cap/s5/info.json"); first = Image.open("out/s5_last.png").convert("RGB"); r = page("cap/s6/res.jpg"); cx, cy = I["chip"]
    g = seq(hold(first, 1.5), xfade(first, r, 0.7), hold(r, 6.8))
    run("s6", lang, g, caps=[("s6", 1.8, 8.8)], cursor=Cursor([(0, S5["ask"][0] + 40, S5["ask"][1] + 50), (1.2, cx, cy + 3), (3.0, cx + 60, cy + 90)], clicks=[1.3]))
if want("s7"):
    F = [f"cap/s7/f{i:03d}.jpg" for i in range(135)]; first = Image.open("out/s6_last.png").convert("RGB"); f0, f1 = load(F[0]), load(F[-1])
    g = seq(xfade(first, f0, 0.7), hold(f0, 0.5), frames(F), hold(f1, 3.0))
    run("s7", lang, g, caps=[("s7", 0.9, 8.5)])
if want("s8"):
    I = J("cap/s8/info.json"); Lr = [page(f"cap/s8/l{k}.jpg") for k in range(4)]; first = Image.open("out/s7_last.png").convert("RGB"); o, n, d = I["official"], I["natura"], I["deddie"]
    g = seq(xfade(first, Lr[0], 0.7), hold(Lr[0], 1.3), xfade(Lr[0], Lr[1], 0.6), hold(Lr[1], 2.2), xfade(Lr[1], Lr[2], 0.6), hold(Lr[2], 2.6), xfade(Lr[2], Lr[3], 1.0), hold(Lr[3], 5.0))
    c = Cursor([(0.6, 700, 500), (1.9, o[0], o[1]), (3.6, o[0], o[1]), (4.7, n[0], n[1]), (7.2, n[0], n[1]), (7.9, d[0], d[1]), (9.5, d[0] + 60, d[1] + 30)], clicks=[2.0, 4.8, 8.0])
    run("s8", lang, g, caps=[("s8", 1.0, 7.6), ("s8b", 8.2, 13.6)], cursor=c)
if want("s9"): run("s9", lang, card(f"art/card_end_{lang}.png", 9.0, fout=0.8), full=True)
