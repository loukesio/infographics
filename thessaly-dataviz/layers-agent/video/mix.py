"""Places the narration clips at their scene times and mixes them with the music bed (ducked under the voice); builds the final files."""
import json, subprocess, numpy as np, soundfile as sf
SC = [f"v{i:02d}" for i in range(15)]; SR = 44100
for lang in ("el", "en"):
    T = json.load(open(f"out/times_{lang}.json")); open(f"list2_{lang}.txt", "w").write("".join(f"file 'out/{s}_{lang}.mp4'\n" for s in SC))
    total = sum(T[s]["dur"] for s in SC); voice = np.zeros(int(total * 24000) + 24000, "float32"); t0 = 0.0
    for s in SC:
        for k, off in T[s]["vo"]:
            a, sr = sf.read(f"vo/{k}.wav", dtype="float32"); i = int((t0 + off) * sr); voice[i:i + len(a)] += a; print(lang, k, round(t0 + off, 2), "-", round(t0 + off + len(a) / sr, 2)) if lang == "en" else None
        t0 += T[s]["dur"]
    sf.write("vo/voice.wav", voice * (0.92 / np.abs(voice).max()), 24000); L = "EL" if lang == "el" else "EN"
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", f"list2_{lang}.txt", "-c", "copy", "v2.tmp.mp4"], check=True)
    if lang == "en":   # voice + music; the music drops under the voice and comes back in the pauses
        fc = "[1:a]aresample=44100,highpass=f=70,acompressor=threshold=-18dB:ratio=2.5:attack=8:release=120:makeup=2,asplit=2[v][vk];[2:a]volume=0.55[m];[m][vk]sidechaincompress=threshold=0.02:ratio=9:attack=60:release=700[md];[v][md]amix=inputs=2:normalize=0,alimiter=limit=0.95[a]"
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", "v2.tmp.mp4", "-i", "vo/voice.wav", "-i", "vo/music.wav", "-filter_complex", fc, "-map", "0:v", "-map", "[a]"]
    else:
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", "v2.tmp.mp4", "-i", "vo/music.wav", "-filter_complex", "[1:a]volume=0.6[a]", "-map", "0:v", "-map", "[a]"]
    out = f"Thessaly-Layers-Agent-demo-v2-{L}.mp4"
    subprocess.run(cmd + ["-c:v", "libx264", "-crf", "22", "-preset", "slow", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-t", f"{total:.3f}", "-movflags", "+faststart", "v2b.tmp.mp4"], check=True)
    import os; os.replace("v2b.tmp.mp4", out); print(out, round(total, 1), "s", os.path.getsize(out) // 10**6, "MB")
