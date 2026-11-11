const C = require('./cap.js'); const fs = require('fs');
(async () => { const { b, p } = await C.open({ dpr: 1 }); const D = 'cap/s7'; fs.mkdirSync(D, { recursive: true });
  await p.evaluate(() => { setCityView('3d', true); document.querySelector('.legendbox').open = false; });
  const V = { longitude: 22.4175, latitude: 39.6375, zoom: 15.3, pitch: 60 }, N = 135, ease = t => t < .5 ? 2 * t * t : 1 - Math.pow(-2 * t + 2, 2) / 2;
  for (const bb of [18, 36, 54]) { await C.view(p, { ...V, bearing: bb }); await p.waitForTimeout(9000); await C.raf(p, 3); }      // warm up: buildings + orthophoto patches for the whole sweep
  await C.view(p, { ...V, bearing: 18 }); await p.waitForTimeout(8000); await C.raf(p, 3);
  const t0 = Date.now();
  for (let i = 0; i < N; i++) { await C.view(p, { ...V, bearing: 18 + 36 * ease(i / (N - 1)), zoom: 15.3 + .25 * ease(i / (N - 1)) }); await C.raf(p, 3); await p.screenshot({ path: `${D}/f${String(i).padStart(3, '0')}.jpg`, type: 'jpeg', quality: 93 }); if (i % 15 === 0) console.log('s7', i, ((Date.now() - t0) / 1000).toFixed(0)); }
  await b.close(); })();
