"""Write the extra settlements (data/places.json) into web/index.html (const PLACES = {...})."""
import json, re, pathlib
R = pathlib.Path(__file__).resolve().parents[1]; P = json.load(open(R / "data/places.json"))
p = R / "web/index.html"; s = p.read_text()
s2, n = re.subn(r"const PLACES = \{.*?\};", "const PLACES = " + json.dumps(P, ensure_ascii=False, separators=(",", ":")) + ";", s, count=1)
assert n == 1; p.write_text(s2); print(len(P), "places inlined")
