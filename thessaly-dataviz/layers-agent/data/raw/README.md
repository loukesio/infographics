# Raw official layers (downloaded 2026-11-10)

| Folder / file | What | Source | Licence / terms |
|---|---|---|---|
| `official/el08_friv_{0050,0100,1000}_rev1.json` | Flood-hazard extents, return periods 50/100/1000 y, River Basin District EL08 (Thessaly), 2nd cycle of the Floods Directive (1st revision; rainfall up to 2022, i.e. before Storm Daniel) | ΥΠΕΝ Γ.Δ. Υδάτων WFS `https://gis.floods.ypeka.gr/geoserver/wfs`, layers `floods_rev1:el08_friv_*_rev1` | Public OGC service of the Ministry; cite ΥΠΕΝ |
| `official/v_hyd_poi_all_floods_v1_EL08.json` | Historical flood events (points) in EL08 | same WFS | same |
| `official/adm_pol_perif_enotites.json` | Regional units (Περιφερειακές Ενότητες) of Greece | same WFS | same |
| `arch/ZONES_POLYGONS_CHECK.*` | Delimited archaeological protection zones A/B (956 nationally, 28 in/near Thessaly) | ΥΠΠΟ Αρχαιολογικό Κτηματολόγιο via ΥΠΕΝ ΘαλΧωρ-2 GeoNode, `https://thalchor-2.ypen.gov.gr/download/973` (metadata 2020) | Metadata is inconsistent: "no restrictions" but also "no redistribution without ΥΠΠΟΑ consent" → **do not redistribute the polygons; derived cell shares only** |
| `roadless/` | Roadless map of Greece v2 (May 2022): roadless core areas >1 km² at ≥1 km from roads, and roadless areas (core + 1 km) | Univ. Ioannina Biodiversity Conservation Lab, Mendeley Data doi:10.17632/s6zh89fb5c.2 | CC BY 4.0 |

Not used (checked):
- Ratified forest maps (κυρωμένοι δασικοί χάρτες): `gis.ktimanet.gr/gis/forestfinal` allows shapefile download only per small area (scale ≥1:20,000). No bulk service found → WorldCover tree+shrub used as a flagged proxy.
- ΔΕΔΔΗΕ "Περιθώρια ΑΠΕ" (`apps.deddie.gr/WebAPE`): public viewer, per-substation margins; no open bulk download → needs a manual export or ΔΕΔΔΗΕ permission.
- Official 3rd-cycle (post-Daniel) flood maps: not yet published as GIS.


## Ορθοφωτογραφίες Κτηματολογίου (web/assets/ortho/, εκτός git)
130 κομμάτια για Λάρισα, Βόλο, Τρίκαλα, Καρδίτσα από την υπηρεσία θέασης gis.ktimanet.gr (WMS BASEMAP), 2026-11-10. © Ελληνικό Κτηματολόγιο.
Άδεια: ο Σ. Μουστακίδης δήλωσε στις 2026-11-10 ότι έλαβε άδεια από το Κτηματολόγιο για δημόσια φιλοξενία αντιγράφων με αναφορά «© Ελληνικό Κτηματολόγιο». Το κείμενο της άδειας δεν έχει κατατεθεί εδώ· να προστεθεί.
