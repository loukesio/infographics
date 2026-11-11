// UI overlays with the legend collapsed, for the zoom moves
const C = require('./cap.js'); const fs = require('fs');
(async () => { const { b, p } = await C.open(); const s2 = JSON.parse(fs.readFileSync('cap/s2/info.json'));
  await p.evaluate(() => { document.querySelector('.legendbox').open = false; });
  await C.view(p, { ...s2.from, pitch: 0, bearing: 0 }); await C.ready(p, 1500); await C.ui(p, 'cap/s2/ui0c.png');
  await C.view(p, { ...s2.to, pitch: 0, bearing: 0 }); await C.ready(p, 1500); await C.ui(p, 'cap/s2/ui1c.png');
  await p.evaluate(() => { setMode('sim'); setSim(2); }); await C.view(p, { ...s2.to }); await C.ready(p, 1500); await C.ui(p, 'cap/s3/ui0c.png');
  await b.close(); })();
