# Live agent stress test

`run.mjs` builds the exact prompt the page sends (`promptFor()` + catalog from `web/index.html`), calls a
fast Claude model through the `claude` CLI, validates the returned spec and evaluates it on `web/data.json`.

```bash
cat qs.jsonl | xargs -d '\n' -P 6 -I{} node run.mjs '{}' > results_final.jsonl
```

`questions.json`: 36 cases — 20 answerable, 10 that must be refused (land prices, ownership, grid capacity,
schools, earthquakes, future flooding, ELGA payouts, crop types, heat), 6 follow-ups (narrow, relax, drop, add, refuse).

Result 2026-11-10 (claude-haiku-4-5, proxy for the page's "quick" tier): 36/36 valid specs, 10/10 refusals,
26/26 answerable answered, 0 invalid columns, 5/5 follow-ups modified the previous spec, median 18 s.
Quality fixes added to the prompt after a first run: every criterion must be a filter, default thresholds for vague
words, ru=1 merges Karditsa+Trikala, add `mapped>0` for flood questions, named rivers → `hand3` with a caveat.
The page now also refuses empty specs, reports dropped criteria, and explains zero-result answers.
