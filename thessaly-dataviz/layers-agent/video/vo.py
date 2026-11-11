"""English narration: Kokoro neural TTS (kokoro-onnx, Apache-2.0), one clip per line placed at fixed times, mixed to one track."""
import sys, json, numpy as np, soundfile as sf
from kokoro_onnx import Kokoro
VOICE = sys.argv[1] if len(sys.argv) > 1 else "bm_george"; TOTAL = 134.64; SR = 24000
L = [  # (start s, latest end s, text)
 (0.5, 4.4, "Thessaly Layers Agent. Open data, on one map."),
 (4.8, 12.7, "In 2023, Storm Daniel flooded Thessaly. Nearly a fifth of that land lay outside every official hazard map."),
 (13.0, 28.9, "This map brings the data together. Forty-eight thousand kilometres of roads and half a million buildings, coloured by flood risk. Red marks what flooded outside the official zones. Zoom in, and you reach street level: schools, hospitals, public services."),
 (29.8, 51.7, "Now raise the water. The slider recolours roads, buildings and critical facilities instantly. At three metres above the river, seven thousand kilometres of roads and sixty thousand buildings are under water. Checked against Daniel, the model captures eighty-three percent of the real flood. It is a first filter, not a hydraulic model."),
 (53.0, 63.0, "You can replay the storm itself, day by day, from twelve Copernicus satellite acquisitions."),
 (64.2, 75.2, "Ask a question in plain language. The A.I. turns it into criteria across more than forty data layers."),
 (75.6, 82.6, "The numbers are computed from the data, not by the model. Every criterion is visible, and carries its source."),
 (83.2, 93.8, "And when the data cannot answer, it says so."),
 (95.6, 102.9, "One finding: forty percent of the buildings that flooded were off the map. About six thousand eight hundred of them."),
 (103.8, 111.5, "In twenty-four settlements you can go building by building, with national cadastre orthophotos."),
 (112.6, 119.6, "Everything comes from official and open sources, on one common grid."),
 (120.0, 125.5, "It works for energy too: where new capacity still fits on the network."),
 (126.2, 134.4, "The next step: live sensors, project locations and accurate terrain. We propose a pilot with the Region of Thessaly."),
]
k = Kokoro("kokoro-v1.0.onnx", "voices-v1.0.bin"); out = np.zeros(int(TOTAL * SR), "float32")
for t0, t1, txt in L:
    sp = 1.0
    for _ in range(4):
        a, sr = k.create(txt, voice=VOICE, speed=sp, lang="en-gb" if VOICE.startswith("b") else "en-us"); d = len(a) / sr
        if d <= t1 - t0: break
        sp *= min(1.12, d / (t1 - t0) + 0.01)
    assert sr == SR; i = int(t0 * SR); n = min(len(a), len(out) - i); out[i:i + n] += a[:n]; print(f"{t0:6.1f} {d:5.1f}s / {t1 - t0:4.1f}s speed {sp:.2f} {'OVER' if d > t1 - t0 else ''} {txt[:50]}", flush=True)
out *= 0.9 / max(1e-6, np.abs(out).max()); sf.write(f"vo_{VOICE}.wav", out, SR)
