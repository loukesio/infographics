// Capture helpers: full-page stills, map-only stills and UI overlays (transparent map hole), all at 2x.
const { chromium } = require('playwright'); const fs = require('fs');
const W = 1600, H = 900, URL = 'http://127.0.0.1:8766/index.html';
async function open({ dpr = 2, focus = true, stub = null } = {}) {
  const b = await chromium.launch({ args: ['--use-gl=swiftshader', '--enable-webgl', '--ignore-gpu-blocklist'] });
  const p = await b.newPage({ viewport: { width: W, height: H }, deviceScaleFactor: dpr, reducedMotion: 'reduce' });
  p.on('pageerror', e => console.log('PAGEERR', e.message));
  if (stub) await p.addInitScript(stub);
  await p.goto(URL); await p.waitForFunction(() => typeof deck1 !== 'undefined' && deck1 && !document.getElementById('loading'), null, { timeout: 90000 }); await p.waitForTimeout(3000);
  await p.addStyleTag({ content: `body.focus .app{grid-template-columns:292px minmax(0,1fr) 0}body.focus aside{display:none}
    body.vmap .legendbox,body.vmap #viewSw,body.vmap .card,body.vmap .tour{visibility:hidden}
    body.vui{background:transparent!important}body.vui #map,body.vui #map2,body.vui .loading{visibility:hidden}
    ::-webkit-scrollbar{width:0;height:0}` });
  await p.evaluate(f => { if (f) document.body.classList.add('focus');
    window.vview = v => { viewState = { ...viewState, ...v, transitionDuration: 0, transitionInterpolator: null }; deck1.props.onViewStateChange({ viewState }); };
    window.vready = () => { const ks = stTiles(viewState); return !street() || !ST.man || ks.every(k => ST.r[k] && ST.r[k].items && (viewState.zoom < 13.6 || !ST.has.b.has(k) || (ST.b[k] && ST.b[k].items))); }; }, focus);
  await p.waitForTimeout(1500); return { b, p };
}
const raf = (p, n = 3) => p.evaluate(n => new Promise(r => { const f = () => --n <= 0 ? r() : requestAnimationFrame(f); requestAnimationFrame(f); }), n);
async function ready(p, ms = 1200) { await p.waitForFunction(() => vready(), null, { timeout: 120000 }); await raf(p, 3); await p.waitForTimeout(ms); await raf(p, 2); }
const view = (p, v) => p.evaluate(v => vview(v), v);
const rect = (p, sel) => p.evaluate(s => { const r = document.querySelector(s).getBoundingClientRect(); return [r.left, r.top, r.width, r.height]; }, sel);
const center = async (p, sel) => { const r = await rect(p, sel); return [r[0] + r[2] / 2, r[1] + r[3] / 2]; };
async function page(p, file) { await p.screenshot({ path: file, type: 'jpeg', quality: 93 }); }
async function mapOnly(p, file) { await p.evaluate(() => document.body.classList.add('vmap')); await raf(p, 2); const r = await rect(p, '#stage'); await p.screenshot({ path: file, type: 'jpeg', quality: 93, clip: { x: r[0], y: r[1], width: r[2], height: r[3] } }); await p.evaluate(() => document.body.classList.remove('vmap')); return r; }
async function ui(p, file) { await p.evaluate(() => document.body.classList.add('vui')); await p.waitForTimeout(150); await p.screenshot({ path: file, type: 'png', omitBackground: true }); await p.evaluate(() => document.body.classList.remove('vui')); }
const merc = (lon, lat, z) => { const s = 512 * 2 ** z; return [(lon + 180) / 360 * s, (1 - Math.log(Math.tan(Math.PI / 4 + lat * Math.PI / 360)) / Math.PI) / 2 * s]; };
const unmerc = (x, y, z) => { const s = 512 * 2 ** z; return [x / s * 360 - 180, Math.atan(Math.sinh(Math.PI * (1 - 2 * y / s))) * 180 / Math.PI]; };
// zoom path toward a target: stills every `dz` zoom levels, centre converging so the target stays on a straight screen path
async function zoomStills(p, dir, from, to, dz = 0.5, each) {
  fs.mkdirSync(dir, { recursive: true }); const n = Math.round(Math.abs(to.zoom - from.zoom) / dz), meta = { stills: [] }; const sg = Math.sign(to.zoom - from.zoom);
  const zin = sg > 0 ? from : to, zout = sg > 0 ? to : from;       // zin = wide end, zout = close end
  for (let k = 0; k <= n; k++) { const z = from.zoom + sg * dz * k, f = (2 ** (zin.zoom - z) - 2 ** (zin.zoom - zout.zoom)) / (1 - 2 ** (zin.zoom - zout.zoom));   // 1 at wide end, 0 at close end
    const a = merc(zin.longitude, zin.latitude, 0), c = merc(zout.longitude, zout.latitude, 0), [lon, lat] = unmerc(c[0] + (a[0] - c[0]) * f, c[1] + (a[1] - c[1]) * f, 0);
    await view(p, { longitude: lon, latitude: lat, zoom: z, pitch: 0, bearing: 0 }); await ready(p); if (each) await each(k, z);
    const r = await mapOnly(p, `${dir}/m${k}.jpg`); meta.stills.push({ lon, lat, z }); meta.rect = r; console.log(dir, k, z.toFixed(2)); }
  fs.writeFileSync(`${dir}/meta.json`, JSON.stringify(meta)); return meta;
}
module.exports = { open, ready, raf, view, rect, center, page, mapOnly, ui, zoomStills, merc, W, H };
