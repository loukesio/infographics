const C = require('./cap.js'); const fs = require('fs');
(async () => { const stub = `window.claude = { use: async n => n === 'sample' ? { json: async () => ({}) } : null };`;
  const { b, p } = await C.open({ focus: false, stub }); const D = 'cap/n'; fs.mkdirSync(D, { recursive: true }); const info = {};
  const V3 = await p.evaluate(() => { setCityView('3d', true); const v = homeView(); return { longitude: v.longitude, latitude: v.latitude, zoom: v.zoom, pitch: v.pitch, bearing: v.bearing }; });
  const shot = async (name, ms = 4000) => { await C.view(p, V3); await C.raf(p, 3); await p.waitForTimeout(ms); await C.page(p, `${D}/${name}.jpg`); console.log(name); };
  const chip = k => p.evaluate(k => { const r = document.querySelectorAll('#presets .chip')[k].getBoundingClientRect(); return [r.left + r.width / 2, r.top + r.height / 2]; }, k);
  const preset = async k => { await p.evaluate(k => document.querySelectorAll('#presets .chip')[k].click(), k); await p.waitForTimeout(800); };
  await shot('base');
  // cell card + criterion toggle on the first example
  info.chip0 = await chip(0); await preset(0); await shot('q0');
  for (const [x, y] of [[490, 428], [500, 420], [480, 436], [520, 430], [470, 425], [505, 440], [540, 415], [830, 385]]) { const ok = await p.evaluate(([x, y]) => { const r = document.getElementById('stage').getBoundingClientRect(); const info = deck1.pickObject({ x: x - r.left, y: y - r.top, radius: 6 }); const i = info ? cellAt(info) : -1; if (i >= 0) { showCard(i); return true; } return false; }, [x, y]); if (ok) { info.cell = [x, y]; break; } }
  await p.mouse.move(1000, 80);
  await C.raf(p, 3); await p.waitForTimeout(2500); await C.page(p, `${D}/card.jpg`); console.log('card', info.cell);
  await p.evaluate(() => { document.getElementById('card').hidden = true; document.querySelector('aside .scroll').scrollTop = 360; }); await p.waitForTimeout(400); await C.page(p, `${D}/crit.jpg`);
  info.tog = await C.center(p, '#f1'); await p.evaluate(() => document.getElementById('f1').click()); await C.raf(p, 3); await p.waitForTimeout(3500); await p.evaluate(() => { document.querySelector('aside .scroll').scrollTop = 360; }); await p.waitForTimeout(300); info.tog2 = await C.center(p, '#f1'); await C.page(p, `${D}/crit_off.jpg`); console.log('crit');
  await p.evaluate(() => { document.querySelector('aside .scroll').scrollTop = 0; });
  // energy
  info.chip5 = await chip(5); await preset(5); await shot('pv'); info.chip6 = await chip(6); await preset(6); await shot('bess');
  await p.evaluate(() => { const c = document.getElementById('ov-deddie'); if (!c.checked) c.click(); }); await shot('bess_dd', 3500);
  await p.evaluate(() => { const c = document.getElementById('ov-deddie'); if (c.checked) c.click(); });
  // rain forecast
  info.wx = await C.center(p, '#mode-wx'); await p.evaluate(() => setMode('wx')); await p.waitForTimeout(5000); const n = await p.evaluate(() => typeof WX !== 'undefined' && WX && WX.steps ? WX.steps.length : 0); info.wxn = n; console.log('wx steps', n);
  if (n) { const ks = []; for (let k = 0; k < n; k += Math.max(1, Math.round(n / 9))) ks.push(k); info.wxk = ks; for (let i = 0; i < ks.length; i++) { await p.evaluate(k => setWx(k), ks[i]); await shot('wx' + i, 2500); } info.wxRange = await C.rect(p, '#wxRange'); }
  // today from satellite
  info.today = await C.center(p, '#mode-today'); await p.evaluate(() => setMode('today')); await p.waitForTimeout(4000); await shot('today', 5000);
  fs.writeFileSync(`${D}/info.json`, JSON.stringify(info)); await b.close(); })();
