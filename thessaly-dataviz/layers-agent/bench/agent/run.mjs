// Builds the exact prompt the page sends (catalog + rules), calls a Claude model via the CLI, validates the spec and evaluates it on the data.
import fs from "fs"; import { execFileSync } from "child_process";
const html = fs.readFileSync("../../web/index.html", "utf8");
const grab = (start, end) => { const a = html.indexOf(start); return html.slice(a, html.indexOf(end, a) + end.length); };
const CAT = eval("(" + grab("const CAT = {", "\n};").replace("const CAT = ", "").replace(/;$/, "") + ")");
const L = html.split("\n"); const a0 = L.findIndex(l => l.startsWith("function catalogText()")); const fnSrc = L.slice(a0, a0 + 4).join("\n");
const { catalogText, promptFor } = new Function("CAT", fnSrc + "; return { catalogText, promptFor };")(CAT);
const D = JSON.parse(fs.readFileSync("../../web/data.json", "utf8"));
const H = JSON.parse(fs.readFileSync("../../web/assets/hand.json", "utf8"));
const N = D.h3.length; D.hand3 = new Array(N).fill(0); const k3 = H.levels.indexOf(3); H.cells.idx.forEach((i, j) => D.hand3[i] = H.cells.share[j][k3] / 100);
// lat/lon from h3 cell centres (precomputed by python helper)
const LL = JSON.parse(fs.readFileSync("latlon.json", "utf8")); D.lat = LL.lat; D.lon = LL.lon;
const OPS = { "<": (a, b) => a < b, "<=": (a, b) => a <= b, ">": (a, b) => a > b, ">=": (a, b) => a >= b, "==": (a, b) => a == b, "!=": (a, b) => a != b };
const [kind, q0, fu] = JSON.parse(process.argv[2]); const model = process.argv[3] || "claude-haiku-4-5";
const t0 = Date.now(); let raw = "", spec = null, err = null, res0 = null;
const call = p => { const r = execFileSync("claude", ["-p", p + "\n\nΑπάντησε ΜΟΝΟ με το JSON, χωρίς κείμενο γύρω του.", "--model", model], { encoding: "utf8", timeout: 180000 }); return JSON.parse(r.match(/\{[\s\S]*\}/)[0]); };
let q = q0; try { if (fu) { const s0 = call(promptFor(q0)); q = fu;
  const cur = `\n\nΤΡΕΧΟΥΣΑ ΠΡΟΔΙΑΓΡΑΦΗ (απάντηση στην ερώτηση «${q0}»):\n${JSON.stringify({ title: s0.title, filters: s0.filters, score: s0.score })}\n\nΑν το νέο μήνυμα τροποποιεί την τρέχουσα προδιαγραφή (π.χ. «μόνο στη Λάρισα», «χαλάρωσε την κλίση», «πρόσθεσε…», «βγάλε…»), επέστρεψε ΟΛΗ την τροποποιημένη προδιαγραφή και πρόσθεσε "followup": true. Αν είναι νέο ερώτημα, νέα προδιαγραφή με "followup": false.`;
  spec = call(promptFor(fu) + cur); res0 = s0; } else spec = call(promptFor(q)); } catch (e) { err = String(e).slice(0, 200); }
const res = { kind, q: fu ? q0 + " → " + fu : q, ms: Date.now() - t0, err };
if (res0) { res.followup = spec && spec.followup; res.before = (res0.filters||[]).map(f => `${f.col}${f.op}${f.value}`).join(" & "); }
if (spec) {
  res.refused = !!spec.refuse; res.refuse = spec.refuse;
  const fl = spec.filters || []; res.n_filters = fl.length;
  res.bad = fl.filter(f => !D[f.col] || !OPS[f.op] || typeof f.value !== "number").map(f => JSON.stringify(f));
  res.bad_score = (spec.score || []).filter(t => !D[t.col]).map(t => t.col);
  if (!spec.refuse) { let km2 = 0, pop = 0, c = 0; for (let i = 0; i < N; i++) { if (fl.every(f => !D[f.col] || !OPS[f.op] || OPS[f.op](D[f.col][i], f.value))) { km2 += D.area[i]; pop += D.pop[i]; c++; } }
    res.cells = c; res.km2 = Math.round(km2); res.pop = Math.round(pop); res.filters = fl.map(f => `${f.col}${f.op}${f.value}`).join(" & "); res.caveats = (spec.caveats || []).length; res.score = (spec.score||[]).map(t=>t.col).join(","); }
}
console.log(JSON.stringify(res));
