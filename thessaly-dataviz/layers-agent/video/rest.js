const C = require('./cap.js'); const fs = require('fs');
const which = process.argv.slice(2), want = s => !which.length || which.includes(s);
const LAR = { longitude: 22.4185, latitude: 39.6385 };
(async () => {
  if (want('s3') || want('s4')) { const { b, p } = await C.open();
    if (want('s3')) { const D = 'cap/s3'; fs.mkdirSync(D, { recursive: true }); const s2 = JSON.parse(fs.readFileSync('cap/s2/info.json'));
      await C.view(p, { ...LAR, zoom: s2.to.zoom, pitch: 0, bearing: 0 }); await C.ready(p, 2000);
      await p.evaluate(() => { setMode('sim'); setSim(0); }); await C.view(p, { ...LAR, zoom: s2.to.zoom }); await C.ready(p, 2500);
      for (let k = 0; k <= 5; k++) { await p.evaluate(k => setSim(k), k); await C.raf(p, 3); await p.waitForTimeout(2500); await C.page(p, `${D}/k${k}.jpg`); console.log('s3 k', k); }
      const rr = await C.rect(p, '#simRange'); await p.evaluate(() => setSim(2)); await C.raf(p, 3); await p.waitForTimeout(2000);
      const home = await p.evaluate(() => { const v = homeView(); return { longitude: v.longitude, latitude: v.latitude, zoom: v.zoom }; });
      await C.ui(p, `${D}/ui0.png`);
      await C.zoomStills(p, D, { ...LAR, zoom: s2.to.zoom }, { ...home, zoom: s2.to.zoom - 5.5 }, 0.5);
      await C.ready(p, 2500); await C.ui(p, `${D}/ui1.png`);
      fs.writeFileSync(`${D}/info.json`, JSON.stringify({ range: rr, sim: await C.center(p, '#mode-sim'), time: await C.center(p, '#mode-time') })); }
    if (want('s4')) { const D = 'cap/s4'; fs.mkdirSync(D, { recursive: true });
      await p.evaluate(() => { setMode('time'); setTL(0); }); await C.view(p, { longitude: 22.25, latitude: 39.42, zoom: 8.75, pitch: 52, bearing: -18 }); await C.raf(p, 3); await p.waitForTimeout(4000);
      for (let k = 0; k < 12; k++) { await p.evaluate(k => setTL(k), k); await C.raf(p, 3); await p.waitForTimeout(2500); await C.page(p, `${D}/t${k}.jpg`); console.log('s4 t', k); }
      fs.writeFileSync(`${D}/info.json`, JSON.stringify({ play: await C.center(p, '#tlPlay'), range: await C.rect(p, '#tlRange'), query: await C.center(p, '#mode-query') })); }
    await b.close(); }
  if (want('s5') || want('s6') || want('s8')) {
    const stub = `window.__ans = null; window.__gate = null; window.claude = { use: async n => n === 'sample' ? { json: async () => { await new Promise(r => window.__gate = r); return window.__ans; } } : null };`;
    const { b, p } = await C.open({ focus: false, stub }); const V3 = await p.evaluate(() => { setCityView('3d', true); const v = homeView(); return { longitude: v.longitude, latitude: v.latitude, zoom: v.zoom, pitch: v.pitch, bearing: v.bearing }; });
    await C.view(p, V3); await C.raf(p, 3); await p.waitForTimeout(4000);
    const type = async (D, pre, text) => { let n = 0; for (let i = 1; i <= text.length; i++) { await p.evaluate(t => { document.getElementById('q').value = t; }, text.slice(0, i)); await p.screenshot({ path: `${D}/${pre}${String(n++).padStart(3, '0')}.jpg`, type: 'jpeg', quality: 93 }); } return n; };
    if (want('s5')) { const D = 'cap/s5'; fs.mkdirSync(D, { recursive: true }); const info = {};
      await C.page(p, `${D}/start.jpg`); info.q = await C.center(p, '#q'); info.ask = await C.center(p, '#askBtn');
      const P0 = await p.evaluate(() => ({ q: PRESETS[0].q, spec: structuredClone(PRESETS[0].spec) }));
      await p.evaluate(() => document.getElementById('q').focus()); info.n1 = await type(D, 'a', P0.q);
      await p.evaluate(s => { window.__ans = s; ask(); }, P0.spec); await p.waitForTimeout(400); await C.page(p, `${D}/think1.jpg`);
      await p.evaluate(() => window.__gate()); await p.waitForTimeout(800); await C.view(p, V3); await C.raf(p, 3); await p.waitForTimeout(4000); await C.page(p, `${D}/res1.jpg`);
      const max = await p.evaluate(() => { const s = document.querySelector('aside .scroll'); return Math.min(s.scrollHeight - s.clientHeight, 430); }); info.scroll = max;
      for (let i = 0; i <= 30; i++) { await p.evaluate(y => { document.querySelector('aside .scroll').scrollTop = y; }, max * i / 30); await p.screenshot({ path: `${D}/sc${String(i).padStart(3, '0')}.jpg`, type: 'jpeg', quality: 93 }); }
      await p.waitForTimeout(300); await p.evaluate(() => { document.querySelector('aside .scroll').scrollTop = 0; }); await C.page(p, `${D}/res1top.jpg`);
      const Q2 = 'Ποια χωριά θα πλημμυρίσουν τον επόμενο χειμώνα;'; await p.evaluate(() => document.getElementById('q').focus()); info.n2 = await type(D, 'b', Q2);
      await p.evaluate(() => { window.__ans = { title: 'Πρόβλεψη πλημμύρας ανά χωριό', refuse: 'Η ερώτηση ζητά πρόβλεψη. Τα δεδομένα δείχνουν τι πλημμύρισε το 2023, τις επίσημες ζώνες κινδύνου και σενάρια στάθμης· δεν λένε ποια χωριά θα πλημμυρίσουν μια συγκεκριμένη χρονιά. Μπορώ να δείξω ποιοι οικισμοί βρίσκονται σε χαμηλή γη δίπλα σε ποτάμι.' }; ask(); }); await p.waitForTimeout(400); await C.page(p, `${D}/think2.jpg`);
      await p.evaluate(() => window.__gate()); await p.waitForTimeout(800); await C.view(p, V3); await C.raf(p, 3); await p.waitForTimeout(3500); await C.page(p, `${D}/res2.jpg`);
      fs.writeFileSync(`${D}/info.json`, JSON.stringify(info)); console.log('s5 done'); }
    if (want('s6')) { const D = 'cap/s6'; fs.mkdirSync(D, { recursive: true });
      const k = await p.evaluate(() => PRESETS.findIndex(x => /έξω από τους χάρτες/.test(x.s) && /κτίρια/.test(x.s))); const chip = await p.evaluate(k => { const r = document.querySelectorAll('#presets .chip')[k].getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; }, k);
      await p.evaluate(k => document.querySelectorAll('#presets .chip')[k].click(), k); await p.waitForTimeout(800); await C.view(p, { longitude: 22.2, latitude: 39.5, zoom: 9.0, pitch: 50, bearing: -10 }); await C.raf(p, 3); await p.waitForTimeout(4500); await C.page(p, `${D}/res.jpg`);
      fs.writeFileSync(`${D}/info.json`, JSON.stringify({ chip, name: await p.evaluate(k => PRESETS[k].s, k) })); console.log('s6 done'); }
    if (want('s8')) { const D = 'cap/s8'; fs.mkdirSync(D, { recursive: true }); const info = {};
      await p.evaluate(() => { goHome(); setCityView('3d', true); }); await C.view(p, V3); await C.raf(p, 3); await p.waitForTimeout(4500); await C.page(p, `${D}/l0.jpg`);
      const tog = async (id, on) => { await p.evaluate(([id, on]) => { const c = document.getElementById('ov-' + id); if (c.checked !== on) c.click(); }, [id, on]); await C.raf(p, 3); await p.waitForTimeout(3500); };
      for (const id of ['official', 'natura', 'deddie']) { await p.evaluate(id => document.getElementById('ov-' + id).scrollIntoView({ block: 'center' }), id); }
      await p.evaluate(() => document.getElementById('ov-natura').scrollIntoView({ block: 'center' })); await p.waitForTimeout(300); await C.page(p, `${D}/l0.jpg`);
      for (const id of ['official', 'natura', 'deddie']) info[id] = await C.center(p, '#ov-' + id);
      await tog('official', true); await C.page(p, `${D}/l1.jpg`); await tog('natura', true); await C.page(p, `${D}/l2.jpg`);
      await tog('official', false); await tog('natura', false); await tog('deddie', true); await C.page(p, `${D}/l3.jpg`);
      for (const id of ['official', 'natura', 'deddie']) info[id + '2'] = await C.center(p, '#ov-' + id);
      fs.writeFileSync(`${D}/info.json`, JSON.stringify(info)); console.log('s8 done'); }
    await b.close(); }
})();
