const C = require('./cap.js'); const fs = require('fs');
(async () => { const { b, p } = await C.open(); const D = 'cap/s2'; fs.mkdirSync(D, { recursive: true });
  const home = await p.evaluate(() => { const v = homeView(); return { longitude: v.longitude, latitude: v.latitude, zoom: v.zoom }; });
  const from = { ...home, zoom: Math.round(home.zoom * 2) / 2 }, to = { longitude: 22.4185, latitude: 39.6385, zoom: from.zoom + 5.5 };
  await C.view(p, { ...from, pitch: 0, bearing: 0 }); await C.ready(p, 2500); await C.ui(p, `${D}/ui0.png`);
  const m = await C.zoomStills(p, D, from, to, 0.5);
  await C.ready(p, 2500); await C.ui(p, `${D}/ui1.png`); await C.page(p, `${D}/end.jpg`);
  fs.writeFileSync(`${D}/info.json`, JSON.stringify({ from, to, viewSw: await C.rect(p, '#viewSw'), sim: await C.center(p, '#mode-sim') })); await b.close(); })();
