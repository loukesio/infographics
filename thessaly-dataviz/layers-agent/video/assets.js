// Renders the static artwork: window background, captions and full-screen cards, for both languages.
const { chromium } = require('playwright'); const fs = require('fs'); const T = require('./text.json');
const FONT = `<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Commissioner:wght@500;650;800&family=Fira+Sans:wght@400;500;600&family=JetBrains+Mono:wght@400;600&display=swap">`;
const CSS = `*{box-sizing:border-box;margin:0}html,body{width:1920px;height:1080px;overflow:hidden}body{font-family:"Fira Sans",sans-serif;color:#E7ECF3}
.bg{position:absolute;inset:0;background:radial-gradient(1200px 700px at 50% 35%,#132036 0%,#0A111C 70%)}
.win{position:absolute;left:160px;top:16px;width:1600px;height:936px;border-radius:12px;background:#0D1522;box-shadow:0 30px 80px rgba(0,0,0,.55),0 0 0 1px #233149}
.bar{height:36px;display:flex;align-items:center;gap:8px;padding:0 14px;font:500 13px "Fira Sans";color:#8C9BB0;border-bottom:1px solid #233149}
.bar i{width:11px;height:11px;border-radius:50%;background:#2A3A55}.bar b{flex:1;text-align:center;font-weight:500;margin-right:50px}
.cap{position:absolute;left:160px;top:952px;width:1600px;height:128px;display:flex;flex-direction:column;justify-content:center;gap:8px;padding-left:22px;border-left:0}
.cap h1{font:650 33px/1.15 "Commissioner";letter-spacing:-.01em;color:#F3F6FA}.cap h1::before{content:"";display:inline-block;width:6px;height:28px;background:#F2A33A;border-radius:2px;margin-right:16px;vertical-align:-4px}
.cap p{font:400 20px/1.3 "Fira Sans";color:#A9B6C8;padding-left:22px}
.card{position:absolute;inset:0;display:flex;flex-direction:column;justify-content:center;padding:0 220px;gap:28px}
.k{font:600 17px "Fira Sans";letter-spacing:.22em;color:#F2A33A}.card h1{font:800 104px/1.02 "Commissioner";letter-spacing:-.02em}.card h1 span{color:#F2A33A}
.card h2{font:800 72px/1.05 "Commissioner";letter-spacing:-.02em;max-width:1300px}.lead{font:400 36px/1.3 "Fira Sans";color:#C5CFDC;max-width:1300px}
.foot{position:absolute;left:220px;bottom:90px;font:600 22px "Commissioner";letter-spacing:.14em;color:#8C9BB0}
.nums{display:grid;grid-template-columns:repeat(3,1fr);gap:48px;margin:12px 0}.nums b{display:block;font:600 96px/1 "JetBrains Mono";color:#F2A33A;letter-spacing:-.03em}.nums span{display:block;margin-top:16px;font:400 26px/1.3 "Fira Sans";color:#C5CFDC}
.src{font:400 17px "JetBrains Mono";color:#6F7F96}.punch{font:650 44px/1.2 "Commissioner"}
ul{list-style:none;display:grid;gap:16px}li{font:400 32px/1.3 "Fira Sans";color:#C5CFDC}li::before{content:"";display:inline-block;width:10px;height:10px;border-radius:50%;background:#4FA3E0;margin-right:18px;vertical-align:4px}
.cta{font:650 40px/1.2 "Commissioner";color:#F2A33A;margin-top:10px}`;
(async () => { const b = await chromium.launch(); const p = await b.newPage({ viewport: { width: 1920, height: 1080 } }); fs.mkdirSync('art', { recursive: true });
  const shot = async (body, file, transparent, clip) => { await p.setContent(`<!doctype html><meta charset="utf-8">${FONT}<style>${CSS}${transparent ? 'html,body{background:transparent}' : ''}</style>${body}`); await p.evaluate(() => document.fonts.ready); await p.waitForTimeout(250); await p.screenshot({ path: file, omitBackground: !!transparent, clip }); };
  for (const lang of ['el', 'en']) {
    await shot(`<div class="bg"></div><div class="win"><div class="bar"><i></i><i></i><i></i><b>${T.bar[lang]}</b></div></div>`, `art/bg_${lang}.png`);
    for (const [id, c] of Object.entries(T.caps)) await shot(`<div class="cap"><h1>${c[lang][0]}</h1><p>${c[lang][1]}</p></div>`, `art/cap_${id}_${lang}.png`, true, { x: 0, y: 952, width: 1920, height: 128 });
    let c = T.cards.title[lang]; await shot(`<div class="bg"></div><div class="card"><div class="k">${c.k}</div><h1>${c.h}</h1><div class="lead">${c.p}</div></div><div class="foot">${c.f}</div>`, `art/card_title_${lang}.png`);
    c = T.cards.hook[lang]; await shot(`<div class="bg"></div><div class="card"><div class="k">${c.k}</div><div class="nums">${c.n.map(x => `<div><b>${x[0]}</b><span>${x[1]}</span></div>`).join('')}</div><div class="punch">${c.p}</div><div class="src">${c.s}</div></div>`, `art/card_hook_${lang}.png`);
    c = T.cards.end[lang]; await shot(`<div class="bg"></div><div class="card"><div class="k">${c.k}</div><h2>${c.h}</h2><ul>${c.l.map(x => `<li>${x}</li>`).join('')}</ul><div class="cta">${c.p}</div></div><div class="foot">${c.f}</div>`, `art/card_end_${lang}.png`);
  }
  await p.setContent(`<style>html,body{background:transparent;margin:0}</style><svg viewBox="0 0 24 24" width="56" height="56"><path d="M4 2l15 9.5-6.6 1.3L16 20l-2.8 1.2-3.6-7.1L5 18z" fill="#fff" stroke="#0D1522" stroke-width="1.5" stroke-linejoin="round"/></svg>`); await p.screenshot({ path: 'art/cursor.png', omitBackground: true, clip: { x: 0, y: 0, width: 56, height: 56 } });
  await b.close(); })();
