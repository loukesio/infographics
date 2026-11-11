"""English narration v2: one clip per scene part (Kokoro neural TTS, sentence by sentence so the pacing is natural) → vo/<key>.wav + dur.json"""
import sys, json, re, numpy as np, soundfile as sf
from kokoro_onnx import Kokoro
VOICE = sys.argv[1] if len(sys.argv) > 1 else "af_heart"; SPEED = float(sys.argv[2]) if len(sys.argv) > 2 else 1.0; SR = 24000
T = {
 "s0": "This is Resilient Thessaly. One map, built entirely on open data, that answers questions about flood risk, land and energy.",
 "s1": "In September 2023, Storm Daniel flooded more than nine hundred square kilometres of Thessaly. Almost a fifth of that land lay outside every official hazard map. The data existed. It simply was not in one place.",
 "s2": "So we put it in one place. The opening view shows every road in the region, forty-eight thousand kilometres, and more than half a million buildings, each coloured by its flood exposure. Red is where Daniel's water went beyond the official maps. Zoom in, and the same picture holds down to street level, with schools, hospitals and public services marked.",
 "s3": "From here, you can run a scenario. Raise the river by one metre, by three, by six, and the map shows at once which roads, buildings and critical facilities end up under water. Across the region, a three metre rise covers seven thousand kilometres of roads and sixty thousand buildings. Tested against Daniel, the model captures eighty-three percent of what really flooded. It is a first filter for planning, not a hydraulic model.",
 "s4": "The storm itself can be replayed day by day, from twelve Copernicus satellite acquisitions, to see where the water arrived first, and where it stayed longest.",
 "s4b": "Looking ahead, the latest rainfall forecast is laid over the same low ground, so the areas to watch stand out before the rain arrives.",
 "s4c": "And a recent Sentinel-2 image shows the ground as it is today.",
 "s5a": "The heart of the tool is the agent. You ask in plain language: where do most people live on low ground, next to a river? The A.I. turns the question into criteria over more than forty layers, and the map answers: four hundred and sixty-seven square kilometres, home to a hundred and twelve thousand people. The numbers are computed from the data, never invented by the model, and each criterion is listed with its source.",
 "s5r": "And when the data cannot support an answer, such as predicting which villages will flood next winter, the agent says so, instead of guessing.",
 "s5b": "Every result can be taken apart. Click any cell to see all of its values, or switch a criterion off, and watch the answer change.",
 "s6": "This is how one finding surfaced. Forty percent of the buildings Daniel flooded, about six thousand eight hundred, stood outside even the thousand-year zone. Almost half of them are in the Municipality of Larissa.",
 "s7": "In twenty-four towns and villages, the view goes down to single buildings, in 3D, over orthophotos from the Hellenic Cadastre.",
 "s8": "The same grid serves energy planning. It shows where new solar could go under the new national spatial framework, and where batteries make sense: next to a substation that still has capacity. Today, twenty-one of the fifty-one transformers serving Thessaly have no room left for new renewables.",
 "s8a": "Every layer comes from an official or open source: the Ministry of Environment, Copernicus, the grid operator, the Cadastre and OpenStreetMap.",
 "s9": "And this is only what open data allows. Connect the region's live sensors, and the map can warn, street by street, as the water rises. Add precise terrain from LiDAR, and the scenarios gain the accuracy of an engineering study. Add the locations of flood protection works, and you can see whether money is going where the risk is. Add property and crop records, and damage can be estimated the day after a flood.",
 "s10": "The platform is ready. We propose a pilot with the Region of Thessaly.",
}
k = Kokoro("kokoro-v1.0.onnx", "voices-v1.0.bin"); dur = {}; only = sys.argv[3:]
try: dur = json.load(open("dur.json"))
except Exception: pass
for key, txt in T.items():
    if only and key not in only: continue
    parts = []
    for s in re.split(r"(?<=[.?!])\s+", txt):
        lg = "en-us" if VOICE[0] == "a" else "en-gb"; ph = k.tokenizer.phonemize(s, lg).replace("θˈɛsəli", "θˈɛsɐli")     # "Thessaly" with a clear second vowel: THE-sa-li
        a, sr = k.create(ph, voice=VOICE, speed=SPEED, lang=lg, is_phonemes=True); assert sr == SR
        nz = np.flatnonzero(np.abs(a) > 0.004); a = a[max(0, nz[0] - 600): nz[-1] + 1800] if len(nz) else a       # trim the silence the model pads with, keep a short natural tail
        parts += [a, np.zeros(int(0.30 * SR), "float32")]
    w = np.concatenate(parts[:-1]); sf.write(f"{key}.wav", w, SR); dur[key] = round(len(w) / SR, 2); print(key, dur[key], flush=True)
json.dump(dur, open("dur.json", "w"), indent=1); print("total", round(sum(dur.values()), 1))
