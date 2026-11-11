"""Original ambient bed, synthesized (no samples): warm pad chords + sparse soft pings + reverb. python3 music.py <seconds> → vo/music.wav"""
import sys, numpy as np, soundfile as sf
from scipy.signal import fftconvolve, butter, sosfilt
SR = 44100; T = float(sys.argv[1]) if len(sys.argv) > 1 else 240.0; N = int(T * SR); t = np.arange(N) / SR; rng = np.random.default_rng(7)
hz = lambda m: 440.0 * 2 ** ((m - 69) / 12)
CH = [([38, 45], [57, 60, 64, 65, 69]), ([34, 41], [58, 62, 65, 69]), ([41, 48], [57, 60, 64, 67, 72]), ([36, 43], [55, 62, 64, 67, 71])]   # Dm9, Bbmaj7, Fmaj9, Cmaj9
BAR = 9.0; out = np.zeros((N, 2))
def tone(f, det):                     # soft pad voice: sine + a little 2nd/3rd harmonic, slow vibrato
    ph = 2 * np.pi * f * (1 + det) * t + 0.6 * np.sin(2 * np.pi * (0.11 + 0.07 * rng.random()) * t + rng.random() * 6)
    return np.sin(ph) + 0.22 * np.sin(2 * ph) + 0.08 * np.sin(3 * ph)
for k in range(int(T / BAR) + 1):
    bass, notes = CH[k % 4]; t0 = k * BAR; env = np.clip((t - t0 + 2.5) / 3.5, 0, 1) * np.clip((t0 + BAR + 2.5 - t) / 3.5, 0, 1); env = np.sin(env * np.pi / 2) ** 2
    if not env.any(): continue
    for m in notes:
        for ch, det in ((0, -0.0018), (1, 0.0018)): out[:, ch] += env * 0.11 * tone(hz(m), det + rng.normal(0, 0.0004))
    for m in bass:
        b = env * 0.20 * np.sin(2 * np.pi * hz(m) * t); out[:, 0] += b; out[:, 1] += b
    for j in range(int(BAR / 1.5)):   # sparse pings on chord tones, an octave up, with a long soft decay
        if rng.random() < 0.55:
            ts = t0 + j * 1.5 + rng.choice([0, 0.75]); i0 = int(ts * SR)
            if i0 >= N: continue
            m = rng.choice(notes) + 12; d = np.arange(min(N - i0, int(3.0 * SR))) / SR; p = np.sin(2 * np.pi * hz(m) * d) * np.exp(-d * 2.6) * (1 - np.exp(-d * 180)) * 0.10 * (0.5 + 0.5 * rng.random()); pan = rng.random()
            out[i0:i0 + len(d), 0] += p * (1 - 0.6 * pan); out[i0:i0 + len(d), 1] += p * (0.4 + 0.6 * pan)
sos = butter(2, 2600, "low", fs=SR, output="sos"); out = sosfilt(sos, out, axis=0)
ir_t = np.arange(int(3.2 * SR)) / SR; wet = np.zeros_like(out)
for ch in (0, 1): ir = rng.normal(0, 1, len(ir_t)) * np.exp(-ir_t * 2.1); ir = sosfilt(butter(2, 3500, "low", fs=SR, output="sos"), ir); wet[:, ch] = fftconvolve(out[:, ch], ir, mode="full")[:N]
wet *= 0.5 * np.abs(out).max() / np.abs(wet).max(); mix = out * 0.7 + wet
mix *= np.clip(t / 2.5, 0, 1)[:, None] * np.clip((T - t) / 5.0, 0, 1)[:, None]; mix *= 0.7 / np.abs(mix).max()
sf.write("vo/music.wav", mix.astype("float32"), SR); print("music", T, "s")
