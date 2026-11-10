# region_flood_works.csv: Region of Thessaly flood works (post-Daniel)

Compiled 2026-11-10. There are 83 rows, one per project or sub-project. The columns are `name, budget_eur, status, place_names, municipality, regional_unit, funding, source_url, source_date`.

## Sources
1. **Τεχνικό Πρόγραμμα Περιφέρειας Θεσσαλίας 2026** (Περιφερειακό Συμβούλιο, πρακτικό 23/22-10-2025, ΑΔΑ 9ΝΛΕ7ΛΡ-0Σ9, signed 27-10-2025). This is the backbone. It lists every flood, stream and river line with its approved budget. The tables were extracted with pdfplumber, and the titles are copied verbatim.
2. **Region tender portal** (thessaly.gov.gr → Διακηρύξεις, category "Τεχνικά Έργα", years 2025 and 2026). This gave the tender date, the budget (incl. VAT) and the exact title for 37 flood-related tenders.
3. **Decision ΑΔΑ 9ΟΞΠ7ΛΡ-ΖΔ7** (16-06-2025): Karditsa "Daniel–Elias" restoration, €5.771M. Its 58 sub-positions (Α1–Α58) name the river or stream and the village (ΤΚ). Those names are folded into `place_names` for that one row.
4. **Press releases** f47984 (26-06-2026, totals €116.19M / €38.72M / 432 sites), f47607 (24-01-2026), f47740 (24-03-2026, Karditsa master plan €600k) and f48033 (16-07-2026). Of these, only f47740 is cited in the CSV, for the master-plan row. f48033 contains no project list (it is the water-strategy release).
5. **Press**: taxydromos.gr (17-09-2026, Pamisos contract €3.5M), neosagon.gr (10-07-2025, €15M programme split into Ενιπέας/Φαρσαλίτης/Πάμισος/Πηνειός; 15-08-2026, Φαρσαλίτης left embankment contract), ertnews.gr (20-04-2026, Karditsa €72M overview, which has no titles).

## Field rules
- `place_names` holds only toponyms that appear literally in the title or source text: rivers, streams, ΤΚ/Δ.Δ., bridges. Nothing was geocoded or inferred. The Karditsa row keeps the source's uppercase genitive forms (e.g. "ΤΚ ΒΛΟΧΟΥ").
- `municipality` and `regional_unit` are filled **only when the source names them**. They are left blank otherwise, even where the answer is obvious (e.g. Κλοκοτός → Τρίκαλα). Fill them later from a gazetteer join, not from this file.
- `status` was assigned by rule, because the Region does not publish a per-project status:
  - **νέο 2026**: the tender was published in 2026, or the project is marked "ΝΕΟ ΕΡΓΟ 2026" in the Technical Programme.
  - **σε εξέλιξη**: a tender or contract from 2025, or a contract signature reported in the press, or a project with an older MIS code that still carries 2026 credits.
  - **ένταξη**: a 2025 MIS code in the Technical Programme with no tender or contract evidence found.
  - **ολοκληρωμένο**: never used. No source confirms completion of a specific project.
- `budget_eur` is the approved or tender budget incl. VAT. It is not contract value or spend.
- `source_url` may list two URLs separated by " ; ". The first is the primary source and the one that `source_date` refers to.

## Coverage against the Region's announced totals
| Announced (f47984, 26-06-2026) | Itemised here | Comment |
|---|---|---|
| 30 new 2026 projects, €38.722M | 12 rows tagged νέο 2026, €9.26M (~24% of €) | The Region has published no list of the 30. These 12 are the 2026 flood tenders and Technical Programme entries I could find. It is not confirmed that they belong to the announced set. Note also that f47740 says €37.722M, not €38.722M. |
| €116.19M implemented or ongoing | 71 rows (σε εξέλιξη + ένταξη), €112.3M nominal | These two figures **cannot be reconciled**. The €116M includes the €75.7M of temporary restorations at 432 sites (Τρίκαλα 137, Λάρισα 78, Μαγνησία 58, Καρδίτσα 99, Περιφέρεια 60) and the €42M negotiated programme. Neither is itemised anywhere public, and the 432 sites are mostly emergency (κατεπείγουσες) contracts. My rows also include studies (Πηνειός operational plans €4.7M, Karditsa master plan €0.6M), two region-wide umbrella lines (€8.4M) and a few pre-Daniel flood works that are still running (Μέγας €1.97M, Καλέντζης–Καράμπαλης €1M, Κερασιώτης €3.4M, Ληθαίος dam lines). |
| 432 restoration sites | Not itemised | The only site-level detail found is the Karditsa decision (58 sub-positions). |

Larger works (≥ €0.5M): 54 rows. Every flood line of ≥ €0.5M in the 2026 Technical Programme is included, so coverage is good for anything that went through regular tendering or ΠΔΕ/ΠΠΑ. Emergency or negotiated contracts are poorly covered.

## Known gaps and caveats
- **There is no list of the 30 new 2026 projects.** The best next step is diavgeia.gov.gr: search the Region's decisions (ΑΔΑ suffix 7ΛΡ) for "έγκριση ένταξης" or "ΠΠΑ" with "ρέματ"/"αναχ" for 2026, or ask the ΔΤΕ.
- **The €42M negotiated "αποκατάσταση ποταμών και ρεμάτων" programme (2023-24) is not itemised.** The ΝΠ817 Daniel lines (Φαρσαλίτης €6M, Ενιπέας €6M, Πηνειός Λάρισα–Τρίκαλα €3M, Ληθαίος, Πορταϊκός ×2, Κιλελέρ, Φάρσαλα, Τέμπη, Magnesia streams) probably make up much of it. This is unconfirmed.
- **Some rows may overlap.** The Trikala "κατά θέσεις" €5M line (ΤΠ, ένταξη) may be the same as the Ληθαίος €5M tender (2025-07-07). Phase A and phase B Larissa municipal stream lines are separate contracts, not duplicates.
- **The Pamisos sub-project amount is inconsistent across sources.** The portal lists €350,000, but the signed contract (taxydromos) and the €15M split both give €3.5M. €3.5M is used, so the four sub-projects sum to €15M.
- **Excluded**: Aqua Montis mountain hydronomy (€212.3M, Υπερταμείο); the Ενιπέα/Μουζακίου/Πύλης dams (state); TOEB irrigation contracts; restorations from pre-Daniel storms (2018–2022: Ιανός, Διομήδης, Αθηνά); road-only maintenance; €37,200 boundary-delineation (οριοθέτηση) studies in Νότιο Πήλιο; the ΓΟΕΒ "Αντλιοστάσιο Α4" is **included**.
- **ΠΕΠ/ΕΣΠΑ open data (anaptyxi.gov.gr) and diavgeia were not queried directly** because of the tool-call budget. They should be checked to firm up statuses.
