/* Thessaly wall exhibit — charts & maps. d3 v7 + topojson-client. */
(function () {
  const C = {
    paper: '#f2eee3', paper2: '#e7e1d1', ink: '#191713', ink2: '#4a463d',
    mute: '#8b8474', rule: '#c7bfa9', red: '#b3241f', teal: '#1c4b52',
    ochre: '#c08a1e', wheat: '#d9bd6a', deep: '#141d1c', snow: '#dfe6e4',
    water: '#2b6b76', land: '#e9e4d4', darkland: '#1e2a28', darksea: '#0d1413'
  };
  const SER = "'Alegreya',serif", SAN = "'IBM Plex Sans',sans-serif", MON = "'IBM Plex Mono',monospace";
  const ATLAS = 'https://cdn.jsdelivr.net/npm/world-atlas@2.0.2/countries-50m.json';

  /* ---------- data ---------- */
  const PEAKS = [
    { n: 'ΟΛΥΜΠΟΣ', en: 'Olympus', lon: 22.3583, lat: 40.0885, h: 2917 },
    { n: 'ΑΓΡΑΦΑ', en: 'Agrafa', lon: 21.60, lat: 39.15, h: 2184 },
    { n: 'ΟΣΣΑ', en: 'Ossa', lon: 22.6822, lat: 39.7936, h: 1978 },
    { n: 'ΚΟΖΙΑΚΑΣ', en: 'Koziakas', lon: 21.6167, lat: 39.5333, h: 1901 },
    { n: 'ΟΘΡΥΣ', en: 'Othrys', lon: 22.50, lat: 39.05, h: 1726 },
    { n: 'ΠΗΛΙΟ', en: 'Pelion', lon: 23.0333, lat: 39.4167, h: 1624 },
    { n: 'ΧΑΣΙΑ', en: 'Chasia', lon: 21.75, lat: 39.90, h: 1564 },
    { n: 'ΜΑΥΡΟΒΟΥΝΙ', en: 'Mavrovouni', lon: 22.75, lat: 39.62, h: 1054 }
  ];
  const CITIES = [
    { n: 'ΛΑΡΙΣΑ', lon: 22.4191, lat: 39.6390, p: 148562, big: 1, dx: 10, dy: -8 },
    { n: 'Βόλος', lon: 22.9422, lat: 39.3622, p: 83000, dx: 11, dy: 14 },
    { n: 'Τρίκαλα', lon: 21.7683, lat: 39.5556, p: 62000, dx: 11, dy: -8 },
    { n: 'Καρδίτσα', lon: 21.9214, lat: 39.3644, p: 38000, dx: -9, dy: 12, an: 'end' },
    { n: 'Τύρναβος', lon: 22.2872, lat: 39.7378, p: 11000, dx: -8, dy: -6, an: 'end' },
    { n: 'Ελασσόνα', lon: 22.188, lat: 39.895, p: 7000, dx: -8, dy: 4, an: 'end' },
    { n: 'Φάρσαλα', lon: 22.3833, lat: 39.2917, p: 9000, dx: 8, dy: 12 },
    { n: 'Καλαμπάκα', lon: 21.6278, lat: 39.7053, p: 8000, dx: -22, dy: 30, an: 'end' }
  ];
  const SITES = [
    { n: 'ΜΕΤΕΩΡΑ', lon: 21.6306, lat: 39.7217, dx: 8, dy: -6 },
    { n: 'ΤΕΜΠΗ', lon: 22.5667, lat: 39.8667, dx: 9, dy: 4 },
    { n: 'ΣΕΣΚΛΟ', lon: 22.8167, lat: 39.3167, dx: -8, dy: -4, an: 'end' },
    { n: 'ΔΙΜΗΝΙ', lon: 22.8917, lat: 39.3583, dx: -8, dy: -14, an: 'end' }
  ];
  const WATERS = [
    { n: 'Λ. ΚΑΡΛΑ', lon: 22.70, lat: 39.533, km: 5.0, flat: .55, dx: 16, dy: 34 },
    { n: 'Λ. ΠΛΑΣΤΗΡΑ', lon: 21.7667, lat: 39.25, km: 3.0, flat: .75, dx: -12, dy: -6, an: 'end' }
  ];

  /* ---------- helpers ---------- */
  function setup(id, pad) {
    const el = document.getElementById(id);
    if (!el) return null;
    const w = el.parentElement.offsetWidth || el.offsetWidth;
    const h = el.parentElement.offsetHeight || el.offsetHeight;
    if (!w || !h) return null;
    el.setAttribute('viewBox', `0 0 ${w} ${h}`);
    el.setAttribute('preserveAspectRatio', 'xMidYMid meet');
    const svg = d3.select(el);
    svg.selectAll('*').remove();
    return { svg, w, h, u: w / 100 };
  }
  function txt(g, x, y, s, o) {
    o = o || {};
    return g.append('text').attr('x', x).attr('y', y)
      .attr('font-family', o.f || SAN).attr('font-size', o.s || 12)
      .attr('font-weight', o.w || 400).attr('fill', o.c || C.ink)
      .attr('text-anchor', o.a || 'start').attr('letter-spacing', o.ls || 0)
      .attr('dominant-baseline', o.b || 'auto').text(s);
  }
  /* Label families are emitted by independent passes (peaks, cities, waters,
     sites …) that cannot see each other, so geographically close features
     collide. This runs once after placement: walk the labelled groups in
     priority order and slide each lower-priority group along y until its box
     clears everything already placed. */
  function declutter(svg, step, W, H) {
    const items = svg.selectAll('g.lbl').nodes().map(n => ({
      n, p: +(n.getAttribute('data-pri') || 5), b: n.getBBox()
    })).sort((a, b) => a.p - b.p);
    const olap = (a, b) =>
      Math.max(0, Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x)) *
      Math.max(0, Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y));
    const outside = b => b.x < 0 || b.y < 0 || b.x + b.width > W || b.y + b.height > H;
    step = step || 9;
    // Marks are obstacles — but only OTHER features' marks. A label abutting
    // its own symbol is correct cartography; a label sitting on a neighbour's
    // symbol is an error, and thin grazes matter more than their area suggests,
    // hence the weight.
    const marks = svg.selectAll('.mk').nodes().map(n => ({ f: n.getAttribute('data-f'), b: n.getBBox() }));
    const placed = [];
    items.forEach(it => {
      const self = it.n.getAttribute('data-f');
      const obstacles = placed.concat(
        marks.filter(m => m.f !== self).map(m => ({ x: m.b.x, y: m.b.y, width: m.b.width, height: m.b.height, wt: 8 })));
      // getBBox() reports the element's OWN user space and ignores the
      // transform we are about to set, so candidate boxes are computed
      // arithmetically. Both terms of the score are normalised (overlap as a
      // fraction of the label's own area, travel as a fraction of the cap) so
      // a small residual overlap always beats flinging the label onto a
      // neighbouring feature. Nothing is ever deleted.
      const own = Math.max(1, it.b.width * it.b.height);
      const maxOff = Math.max(step, it.b.height * 1.25);
      const fine = Math.max(4, it.b.height * .22);
      const offs = [0];
      for (let o = fine; o <= maxOff; o += fine) offs.push(o, -o);
      const flip = +(it.n.getAttribute('data-flip') || 0);
      if (flip) offs.push(flip);
      let bestOff = 0, bestCost = Infinity, bestBox = null;
      for (const o of offs) {
        const cand = { x: it.b.x, y: it.b.y + o, width: it.b.width, height: it.b.height };
        let cost = obstacles.reduce((s, p) => s + olap(cand, p) * (p.wt || 1), 0) / own;
        if (outside(cand)) cost += 100;
        // Travel is capped, so it can stay cheap relative to overlap: a label
        // should move rather than sit on another feature's mark.
        cost += (Math.abs(o) / Math.max(maxOff, Math.abs(flip))) * .30;
        if (cost < bestCost) { bestCost = cost; bestOff = o; bestBox = cand; }
        if (cost === 0) break;
      }
      if (bestOff) it.n.setAttribute('transform', 'translate(0,' + bestOff + ')');
      placed.push(bestBox);
    });
  }

  function drawable(sel) {
    sel.each(function () {
      const L = this.getTotalLength ? this.getTotalLength() : 0;
      if (L) { this.style.setProperty('--len', L); this.classList.add('draw'); }
    });
    return sel;
  }
  const ANIM = () => document.documentElement.classList.contains('anim');
  const fmt = d3.format(',');
  const grk = n => fmt(n).replace(/,/g, '.');

  /* ══════════ 01 · Greece locator ══════════ */
  function mapGreece(land) {
    const s = setup('mapGreece'); if (!s) return;
    const { svg, w, h } = s;
    const gr = land.find(f => f.properties.name === 'Greece');
    const proj = d3.geoMercator().fitExtent([[w * .14, h * .07], [w * .86, h * .93]], gr);
    const path = d3.geoPath(proj);
    svg.append('rect').attr('width', w).attr('height', h).attr('fill', C.darksea);
    svg.append('g').selectAll('path').data(land).join('path').attr('d', path)
      .attr('fill', C.darkland).attr('stroke', '#2c3a37').attr('stroke-width', .8);
    svg.append('path').datum(gr).attr('d', path).attr('fill', '#2f3f3c')
      .attr('stroke', C.paper).attr('stroke-width', 1.2);

    // Thessaly window
    const a = proj([21.0, 40.30]), b = proj([23.55, 38.85]);
    const bw = b[0] - a[0], bh = b[1] - a[1];
    svg.append('rect').attr('x', a[0]).attr('y', a[1]).attr('width', bw).attr('height', bh)
      .attr('fill', 'rgba(217,189,106,.16)').attr('stroke', C.wheat).attr('stroke-width', 2);
    const gWin = svg.append('g').attr('class', 'lbl').attr('data-pri', 1).attr('data-f', 'win');
    txt(gWin, a[0] + w * .018, b[1] - w * .022, 'ΘΕΣΣΑΛΙΑ', { f: SER, s: w * .055, w: 900, c: C.wheat, ls: '-.02em' });

    const la = proj([22.4191, 39.639]);
    svg.append('circle').attr('cx', la[0]).attr('cy', la[1]).attr('r', 4).attr('fill', C.red).attr('class', 'mk').attr('data-f', 'gLa');
    svg.append('circle').attr('cx', la[0]).attr('cy', la[1]).attr('r', 11)
      .attr('fill', 'none').attr('stroke', C.red).attr('stroke-width', 1.4).attr('opacity', .7);
    const gLa = svg.append('g').attr('class', 'lbl').attr('data-pri', 2).attr('data-f', 'gLa');
    txt(gLa, la[0] + 16, la[1] + 4, 'Λάρισα', { s: w * .026, w: 600, c: C.paper });

    [['Αθήνα', 23.727, 37.983], ['Θεσσαλονίκη', 22.94, 40.64]].forEach(([n, lo, lt]) => {
      const p = proj([lo, lt]);
      svg.append('circle').attr('cx', p[0]).attr('cy', p[1]).attr('r', 2.6).attr('fill', C.mute).attr('class', 'mk').attr('data-f', 'g' + n);
      const g = svg.append('g').attr('class', 'lbl').attr('data-pri', 6).attr('data-f', 'g' + n);
      txt(g, p[0] + 9, p[1] + 3, n, { s: w * .019, c: C.mute });
    });
    declutter(svg, Math.round(w * .022), w, h);
    txt(svg, w * .05, h - w * .022, 'Η θέση της Θεσσαλίας στην Ελλάδα · Location within Greece',
      { f: MON, s: w * .016, c: C.mute, ls: '.1em' });
  }

  /* ══════════ 02 · Thessaly region map ══════════ */
  function mapThess(land) {
    const s = setup('mapThess'); if (!s) return;
    const { svg, w, h } = s;
    const box = { type: 'MultiPoint', coordinates: [[21.02, 40.28], [23.52, 38.88]] };
    const proj = d3.geoMercator().fitSize([w, h], box);
    const path = d3.geoPath(proj);
    const P = (lo, lt) => proj([lo, lt]);

    svg.append('rect').attr('width', w).attr('height', h).attr('fill', C.snow);
    svg.append('g').selectAll('path').data(land).join('path').attr('d', path)
      .attr('fill', C.land).attr('stroke', C.water).attr('stroke-width', 1.1);

    // graticule
    const gl = svg.append('g').attr('opacity', .35);
    d3.range(21, 24, .5).forEach(lo => {
      const t = P(lo, 40.4), b2 = P(lo, 38.8);
      gl.append('line').attr('x1', t[0]).attr('y1', t[1]).attr('x2', b2[0]).attr('y2', b2[1])
        .attr('stroke', C.rule).attr('stroke-dasharray', '2 5');
    });
    d3.range(39, 40.5, .5).forEach(lt => {
      const l = P(20.9, lt), r = P(23.6, lt);
      gl.append('line').attr('x1', l[0]).attr('y1', l[1]).attr('x2', r[0]).attr('y2', r[1])
        .attr('stroke', C.rule).attr('stroke-dasharray', '2 5');
    });

    // ring of mountains (convex hull of peaks) — explicitly schematic
    const pts = PEAKS.map(p => P(p.lon, p.lat));
    const hull = d3.polygonHull(pts.map(p => [p[0], p[1]]));
    if (hull) {
      drawable(svg.append('path').attr('d', 'M' + hull.join('L') + 'Z')
        .attr('fill', 'rgba(192,138,30,.07)').attr('stroke', C.ochre)
        .attr('stroke-width', 1.6).attr('stroke-dasharray', '9 7'));
    }

    // waters
    WATERS.forEach(k => {
      const fid = 'w' + k.n;
      const dLon = k.km / (111.32 * Math.cos(k.lat * Math.PI / 180));
      const c = P(k.lon, k.lat), e = P(k.lon + dLon, k.lat);
      const rr = Math.abs(e[0] - c[0]);
      svg.append('ellipse').attr('cx', c[0]).attr('cy', c[1]).attr('rx', rr).attr('ry', rr * k.flat)
        .attr('fill', C.water).attr('opacity', .85).attr('class', 'shim mk').attr('data-f', fid);
      const gw = svg.append('g').attr('class', 'lbl').attr('data-pri', 4).attr('data-f', fid);
      txt(gw, c[0] + k.dx, c[1] + k.dy, k.n, { f: MON, s: w * .0135, w: 600, c: C.teal, ls: '.09em', a: k.an || 'start' })
        .attr('paint-order', 'stroke').attr('stroke', C.land).attr('stroke-width', 3);
    });

    // peaks
    const hs = d3.scaleSqrt().domain([1000, 2917]).range([w * .009, w * .026]);
    PEAKS.forEach(p => {
      const c = P(p.lon, p.lat), r = hs(p.h);
      svg.append('path')
        .attr('d', `M${c[0]} ${c[1] - r} L${c[0] + r * .95} ${c[1] + r * .62} L${c[0] - r * .95} ${c[1] + r * .62} Z`)
        .attr('fill', p.h > 2000 ? C.ink : C.ink2).attr('opacity', .92).attr('class', 'mk').attr('data-f', 'p' + p.n);
      // A label pinned below the triangle has only one possible home; offering
      // the classic flip above the apex gives declutter a real alternative
      // that still reads as belonging to this summit.
      const gp = svg.append('g').attr('class', 'lbl').attr('data-pri', p.h > 1900 ? 3 : 5)
        .attr('data-flip', -(r * 1.62 + w * .0435)).attr('data-f', 'p' + p.n);
      txt(gp, c[0], c[1] + r * .62 + w * .019, p.n,
        { f: MON, s: w * .0135, w: 600, c: C.ink, ls: '.1em', a: 'middle' })
        .attr('paint-order', 'stroke').attr('stroke', C.land).attr('stroke-width', 3);
      txt(gp, c[0], c[1] + r * .62 + w * .034, grk(p.h) + ' m',
        { f: MON, s: w * .0125, c: C.mute, a: 'middle' })
        .attr('paint-order', 'stroke').attr('stroke', C.land).attr('stroke-width', 3);
    });

    // sites
    SITES.forEach(k => {
      const c = P(k.lon, k.lat), r = w * .006;
      svg.append('rect').attr('x', c[0] - r).attr('y', c[1] - r).attr('width', r * 2).attr('height', r * 2)
        .attr('fill', 'none').attr('stroke', C.red).attr('stroke-width', 2).attr('class', 'mk').attr('data-f', 's' + k.n).attr('transform', `rotate(45 ${c[0]} ${c[1]})`);
      const gs = svg.append('g').attr('class', 'lbl').attr('data-pri', 3).attr('data-f', 's' + k.n);
      txt(gs, c[0] + k.dx, c[1] + k.dy, k.n, { f: MON, s: w * .0135, w: 600, c: C.red, ls: '.09em', a: k.an || 'start' })
        .attr('paint-order', 'stroke').attr('stroke', C.land).attr('stroke-width', 3);
    });

    // cities
    const ps = d3.scaleSqrt().domain([0, 150000]).range([0, w * .017]);
    CITIES.forEach(c0 => {
      const c = P(c0.lon, c0.lat), r = Math.max(w * .0035, ps(c0.p));
      svg.append('circle').attr('cx', c[0]).attr('cy', c[1]).attr('r', r)
        .attr('fill', c0.big ? C.red : C.ink).attr('opacity', c0.big ? 1 : .8).attr('class', 'mk').attr('data-f', 'c' + c0.n);
      if (c0.big) svg.append('circle').attr('cx', c[0]).attr('cy', c[1]).attr('r', r + w * .012)
        .attr('fill', 'none').attr('stroke', C.red).attr('stroke-width', 1.3).attr('opacity', .55);
      const gc = svg.append('g').attr('class', 'lbl').attr('data-pri', c0.big ? 1 : 2).attr('data-f', 'c' + c0.n);
      txt(gc, c[0] + c0.dx, c[1] + c0.dy, c0.n,
        { f: c0.big ? SER : SAN, s: c0.big ? w * .028 : w * .017, w: c0.big ? 900 : 600, c: C.ink, a: c0.an || 'start' })
        .attr('paint-order', 'stroke').attr('stroke', C.land).attr('stroke-width', 3.5);
    });
    declutter(svg, Math.round(w * .017), w, h);

    // legend + scale
    // Anchored off the viewBox BOTTOM, not a fraction of h: the box is sized in
    // w units, so a fractional-h origin pushes it out of frame at some aspects.
    const lg = svg.append('g').attr('transform', `translate(${w * .035},${h - w * .143})`);
    lg.append('rect').attr('x', -w * .018).attr('y', -w * .022).attr('width', w * .30).attr('height', w * .135)
      .attr('fill', 'rgba(242,238,227,.88)').attr('stroke', C.rule);
    txt(lg, 0, 0, 'ΥΠΟΜΝΗΜΑ · KEY', { f: MON, s: w * .0125, w: 600, c: C.mute, ls: '.16em' });
    const rows = [
      ['peak', 'Κορυφή · summit'], ['city', 'Πόλη (μέγεθος = πληθυσμός)'],
      ['site', 'Αρχαιολογικός χώρος'], ['water', 'Λίμνη'], ['ring', 'Το δαχτυλίδι των βουνών (σχηματικό)']
    ];
    rows.forEach((r, i) => {
      const y = w * .022 + i * w * .021;
      if (r[0] === 'peak') lg.append('path').attr('d', `M${w * .008} ${y - w * .007} L${w * .015} ${y + w * .004} L${w * .001} ${y + w * .004} Z`).attr('fill', C.ink);
      if (r[0] === 'city') lg.append('circle').attr('cx', w * .008).attr('cy', y).attr('r', w * .005).attr('fill', C.red);
      if (r[0] === 'site') lg.append('rect').attr('x', w * .004).attr('y', y - w * .004).attr('width', w * .008).attr('height', w * .008).attr('fill', 'none').attr('stroke', C.red).attr('stroke-width', 1.6).attr('transform', `rotate(45 ${w * .008} ${y})`);
      if (r[0] === 'water') lg.append('ellipse').attr('cx', w * .008).attr('cy', y).attr('rx', w * .008).attr('ry', w * .005).attr('fill', C.water);
      if (r[0] === 'ring') lg.append('line').attr('x1', w * .001).attr('y1', y).attr('x2', w * .016).attr('y2', y).attr('stroke', C.ochre).attr('stroke-width', 1.8).attr('stroke-dasharray', '6 5');
      txt(lg, w * .024, y + w * .005, r[1], { s: w * .0135, c: C.ink2 });
    });

    // scale bar (20 km)
    const k0 = P(22.0, 39.0), k1 = P(22.0 + 20 / (111.32 * Math.cos(39 * Math.PI / 180)), 39.0);
    const sx = w * .70, sy = h * .93, len = k1[0] - k0[0];
    const sb = svg.append('g');
    sb.append('line').attr('x1', sx).attr('y1', sy).attr('x2', sx + len).attr('y2', sy).attr('stroke', C.ink).attr('stroke-width', 2.5);
    [0, len].forEach(dx0 => sb.append('line').attr('x1', sx + dx0).attr('y1', sy - 5).attr('x2', sx + dx0).attr('y2', sy + 5).attr('stroke', C.ink).attr('stroke-width', 2.5));
    txt(sb, sx + len / 2, sy - 9, '20 km', { f: MON, s: w * .0135, w: 600, a: 'middle' });
    txt(svg, w - w * .028, h * .06, 'Ν', { f: SER, s: w * .03, w: 900, a: 'middle', c: C.ink2 });
    svg.append('path').attr('d', `M${w - w * .028} ${h * .075} L${w - w * .028} ${h * .115}`).attr('stroke', C.ink2).attr('stroke-width', 2);
  }

  /* ══════════ 02 · cross-section ══════════ */
  function xsec() {
    const s = setup('xsec'); if (!s) return;
    const { svg, w, h } = s;
    const D = [[21.30, 1500], [21.45, 1250], [21.60, 700], [21.75, 260], [21.95, 120],
    [22.15, 95], [22.42, 74], [22.60, 100], [22.74, 900], [22.84, 420],
    [22.94, 60], [23.05, 1300], [23.14, 500], [23.22, 0]];
    const m = { t: h * .12, r: w * .02, b: h * .22, l: w * .05 };
    const x = d3.scaleLinear().domain([21.28, 23.24]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([0, 1650]).range([h - m.b, m.t]);
    const area = d3.area().x(d => x(d[0])).y0(y(0)).y1(d => y(d[1])).curve(d3.curveBasis);
    const line = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveBasis);

    svg.append('rect').attr('x', m.l).attr('y', y(0)).attr('width', w - m.r - m.l).attr('height', h - m.b - y(0) + 1).attr('fill', C.snow);
    svg.append('path').datum(D).attr('d', area).attr('fill', C.paper2).attr('class', 'fade');
    drawable(svg.append('path').datum(D).attr('d', line).attr('fill', 'none').attr('stroke', C.ink).attr('stroke-width', 2.4));

    [0, 500, 1000, 1500].forEach(v => {
      svg.append('line').attr('x1', m.l).attr('y1', y(v)).attr('x2', w - m.r).attr('y2', y(v))
        .attr('stroke', C.rule).attr('stroke-width', .8).attr('opacity', v ? .6 : 1);
      txt(svg, m.l - 6, y(v) + 4, grk(v), { f: MON, s: w * .011, c: C.mute, a: 'end' });
    });
    const L = [[21.42, 'ΠΙΝΔΟΣ', 1250], [22.42, 'ΛΑΡΙΣΑ 74 m', 74], [22.74, 'ΜΑΥΡΟΒΟΥΝΙ', 900],
    [22.94, 'ΒΟΛΟΣ', 60], [23.05, 'ΠΗΛΙΟ', 1300], [23.21, 'ΑΙΓΑΙΟ', 0]];
    L.forEach(([lo, n, v]) => {
      svg.append('line').attr('x1', x(lo)).attr('y1', y(v)).attr('x2', x(lo)).attr('y2', h - m.b + h * .05)
        .attr('stroke', C.mute).attr('stroke-width', .8).attr('stroke-dasharray', '3 3').attr('class', 'fade');
      txt(svg, x(lo), h - m.b + h * .12, n, { f: MON, s: w * .0115, w: 600, c: C.ink2, a: 'middle', ls: '.08em' });
    });
    txt(svg, m.l, m.t - h * .04, 'ΥΨΟΜΕΤΡΟ (m) · σχηματική τομή στο ύψος του 39,6° Β',
      { f: MON, s: w * .0115, c: C.mute, ls: '.14em' });
    txt(svg, w - m.r, m.t - h * .04, 'ΔΥΣΗ → ΑΝΑΤΟΛΗ', { f: MON, s: w * .0115, c: C.mute, ls: '.14em', a: 'end' });
  }

  /* ══════════ 03 · Greek summits ══════════ */
  function peaks() {
    const s = setup('peaks'); if (!s) return;
    const { svg, w, h } = s;
    const D = [
      { n: 'Όλυμπος', r: 'Θεσσαλία / Μακεδονία', v: 2917, t: 1 },
      { n: 'Σμόλικας', r: 'Ήπειρος', v: 2637 },
      { n: 'Βόρας', r: 'Μακεδονία', v: 2524 },
      { n: 'Γράμμος', r: 'Ήπειρος', v: 2520 },
      { n: 'Γκιώνα', r: 'Στερεά Ελλάδα', v: 2510 },
      { n: 'Τύμφη', r: 'Ήπειρος', v: 2497 },
      { n: 'Παρνασσός', r: 'Στερεά Ελλάδα', v: 2457 },
      { n: 'Τζουμέρκα', r: 'Ήπειρος', v: 2429 },
      { n: 'Άγραφα', r: 'Θεσσαλία', v: 2184, t: 1 },
      { n: 'Όσσα', r: 'Θεσσαλία', v: 1978, t: 1 },
      { n: 'Κοζιάκας', r: 'Θεσσαλία', v: 1901, t: 1 },
      { n: 'Πήλιο', r: 'Θεσσαλία', v: 1624, t: 1 }
    ];
    const m = { t: h * .03, r: w * .17, b: h * .04, l: w * .32 };
    const y = d3.scaleBand().domain(D.map(d => d.n)).range([m.t, h - m.b]).padding(.42);
    const x = d3.scaleLinear().domain([0, 3000]).range([m.l, w - m.r]);
    D.forEach(d => {
      const yy = y(d.n), bh = y.bandwidth();
      svg.append('rect').attr('x', m.l).attr('y', yy).attr('width', x(d.v) - m.l).attr('height', bh)
        .attr('fill', d.t ? C.red : C.ink2).attr('opacity', d.t ? 1 : .38)
        .attr('class', 'gw').style('transform-origin', `${m.l}px 0`);
      // All three families must clear the 12pt print floor at this panel's
      // scale; .28 put the region line at 7pt. Baselines re-spaced to suit.
      txt(svg, m.l - w * .014, yy + bh * .72, d.n, { f: SER, s: bh * .78, w: 700, a: 'end', c: C.ink, b: 'auto' });
      // Region rides INSIDE the bar: two stacked lines in one band cannot both
      // clear the 12pt floor, and the bar is empty space already paid for.
      // Colour follows the SAME flag as the fill — solid red takes paper (5.7:1),
      // the 38%-opacity grey composites to ~#b2aea4 and needs ink (8.1:1).
      txt(svg, m.l + w * .010, yy + bh * .70, d.r,
        { f: MON, s: bh * .46, c: d.t ? C.paper : C.ink, ls: '.05em' });
      txt(svg, x(d.v) + w * .014, yy + bh * .5, grk(d.v) + ' m', { f: MON, s: bh * .55, w: 600, c: d.t ? C.red : C.ink2, b: 'middle' });
    });
    if (ANIM()) {
      svg.selectAll('.gw').style('transform', 'scaleX(0)').style('transition', 'transform 1.3s cubic-bezier(.2,.7,.25,1)');
      svg.node().closest('.page').addEventListener('om-in', () => svg.selectAll('.gw').style('transform', 'scaleX(1)'));
    }
  }

  /* ══════════ 04 · radial ring ══════════ */
  function ring() {
    const s = setup('ring'); if (!s) return;
    const { svg, w, h } = s;
    const cx = w / 2, cy = h * .52, R = Math.min(w * .42, h * .40);
    const O = [22.4191, 39.639];
    const P = PEAKS.map(p => {
      const dx = (p.lon - O[0]) * Math.cos(39.6 * Math.PI / 180), dy = p.lat - O[1];
      return { ...p, ang: Math.atan2(dx, dy) };
    }).sort((a, b) => a.ang - b.ang);
    const rs = d3.scaleLinear().domain([0, 3000]).range([R * .30, R]);

    [1000, 2000, 3000].forEach(v => {
      svg.append('circle').attr('cx', cx).attr('cy', cy).attr('r', rs(v))
        .attr('fill', 'none').attr('stroke', C.rule).attr('stroke-dasharray', '3 4');
      txt(svg, cx + 4, cy - rs(v) + w * .016, grk(v) + ' m', { f: MON, s: w * .015, c: C.mute });
    });
    svg.append('circle').attr('cx', cx).attr('cy', cy).attr('r', R * .30).attr('fill', C.paper2);
    txt(svg, cx, cy - w * .004, 'ΛΑΡΙΣΑ', { f: SER, s: w * .034, w: 900, a: 'middle', c: C.ink });
    txt(svg, cx, cy + w * .026, '74 m', { f: MON, s: w * .018, a: 'middle', c: C.mute });

    P.forEach(p => {
      const a = p.ang - Math.PI / 2, r0 = R * .30, r1 = rs(p.h);
      const x1 = cx + Math.cos(a) * r0, y1 = cy + Math.sin(a) * r0;
      const x2 = cx + Math.cos(a) * r1, y2 = cy + Math.sin(a) * r1;
      drawable(svg.append('line').attr('x1', x1).attr('y1', y1).attr('x2', x2).attr('y2', y2)
        .attr('stroke', p.h > 1900 ? C.red : C.ink2).attr('stroke-width', w * .012).attr('stroke-linecap', 'butt'));
      svg.append('circle').attr('cx', x2).attr('cy', y2).attr('r', w * .008).attr('fill', p.h > 1900 ? C.red : C.ink2).attr('class', 'fade');
      const lx = cx + Math.cos(a) * (r1 + w * .028), ly = cy + Math.sin(a) * (r1 + w * .028);
      const an = Math.cos(a) > .2 ? 'start' : Math.cos(a) < -.2 ? 'end' : 'middle';
      txt(svg, lx, ly, p.n, { f: MON, s: w * .0175, w: 600, a: an, c: C.ink, ls: '.07em', b: 'middle' });
      txt(svg, lx, ly + w * .024, grk(p.h) + ' m', { f: MON, s: w * .016, a: an, c: C.mute, b: 'middle' });
    });
  }

  /* ══════════ 05 · Meteora pillars ══════════ */
  function pillars() {
    const s = setup('pillars'); if (!s) return;
    const { svg, w, h } = s;
    const D = [
      { n: 'Αγ. Νικόλαος\nΑναπαυσάς', v: 180, y: 1350 },
      { n: 'Ρουσάνου', v: 245, y: 1545 },
      { n: 'Αγ. Στέφανος', v: 290, y: 1400 },
      { n: 'Βαρλαάμ', v: 310, y: 1517 },
      { n: 'Αγ. Τριάδα', v: 325, y: 1476 },
      { n: 'Μεγάλο\nΜετέωρο', v: 375, y: 1356 }
    ];
    const m = { t: h * .10, r: w * .03, b: h * .24, l: w * .07 };
    const y = d3.scaleLinear().domain([0, 420]).range([h - m.b, m.t]);
    const bw = (w - m.l - m.r) / D.length;
    svg.append('line').attr('x1', 0).attr('y1', y(0)).attr('x2', w).attr('y2', y(0)).attr('stroke', C.ink).attr('stroke-width', 2.5);
    txt(svg, m.l, y(0) + h * .055, 'ΕΠΙΠΕΔΟ ΤΗΣ ΠΕΔΙΑΔΑΣ · valley floor', { f: MON, s: w * .016, c: C.mute, ls: '.1em' });
    [100, 200, 300, 400].forEach(v => {
      svg.append('line').attr('x1', m.l * .5).attr('y1', y(v)).attr('x2', w - m.r).attr('y2', y(v))
        .attr('stroke', C.rule).attr('stroke-dasharray', '2 5');
      txt(svg, m.l * .5, y(v) - 5, v + ' m', { f: MON, s: w * .016, c: C.mute });
    });
    D.forEach((d, i) => {
      const cx = m.l + bw * (i + .5), pw = bw * .40;
      const g = svg.append('g');
      g.append('path')
        .attr('d', `M${cx - pw} ${y(0)} C${cx - pw * .8} ${y(d.v * .5)} ${cx - pw * 1.05} ${y(d.v * .85)} ${cx - pw * .55} ${y(d.v)} L${cx + pw * .55} ${y(d.v)} C${cx + pw * 1.05} ${y(d.v * .85)} ${cx + pw * .8} ${y(d.v * .5)} ${cx + pw} ${y(0)} Z`)
        .attr('fill', i === D.length - 1 ? C.ink : C.ink2).attr('opacity', i === D.length - 1 ? 1 : .55)
        .attr('class', 'grow').style('transform-origin', `${cx}px ${y(0)}px`)
        .style('transition-delay', (i * .09) + 's');
      g.append('rect').attr('x', cx - pw * .32).attr('y', y(d.v) - w * .019).attr('width', pw * .64).attr('height', w * .019)
        .attr('fill', C.red).attr('class', 'fade');
      d.n.split('\n').forEach((ln, j) => {
        txt(svg, cx, y(0) + h * .10 + j * w * .022, ln, { f: MON, s: w * .0165, w: 600, a: 'middle', c: C.ink, ls: '.05em' });
      });
      txt(svg, cx, y(d.v) - w * .028, '≈' + d.v + ' m', { f: MON, s: w * .017, w: 600, a: 'middle', c: C.red });
    });
    txt(svg, w - m.r, m.t - h * .03, 'Ενδεικτικά ύψη πάνω από την πεδιάδα · approximate heights above the valley floor',
      { f: MON, s: w * .014, c: C.mute, a: 'end', ls: '.06em' });
  }

  /* ══════════ 06 · Pineios long profile ══════════ */
  function river() {
    const s = setup('river'); if (!s) return;
    const { svg, w, h } = s;
    const D = [[0, 1100], [12, 880], [24, 620], [38, 400], [50, 300], [60, 240], [72, 170],
    [85, 115], [100, 95], [120, 74], [140, 62], [160, 50], [178, 30], [192, 12], [205, 0]];
    // Tier geometry derived from the label stack, not magic constants: a tier
    // must clear a full title+sub pair, and the bottom margin must clear the
    // deepest tier's descender.
    const labTop = h * .13, lineH = h * .05, tierStep = lineH * 2.2;
    const m = { t: h * .14, r: w * .03, b: labTop + tierStep + lineH + h * .05, l: w * .06 };
    const x = d3.scaleLinear().domain([0, 205]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([0, 1200]).range([h - m.b, m.t]);
    const area = d3.area().x(d => x(d[0])).y0(y(0)).y1(d => y(d[1])).curve(d3.curveMonotoneX);
    const line = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveMonotoneX);

    svg.append('rect').attr('x', m.l).attr('y', y(0)).attr('width', w - m.r - m.l).attr('height', h - m.b - y(0)).attr('fill', C.snow);
    svg.append('path').datum(D).attr('d', area).attr('fill', C.paper2).attr('class', 'fade');
    drawable(svg.append('path').datum(D).attr('d', line).attr('fill', 'none').attr('stroke', C.water).attr('stroke-width', 3.4).attr('stroke-linecap', 'round'));

    [0, 400, 800, 1200].forEach(v => {
      svg.append('line').attr('x1', m.l).attr('y1', y(v)).attr('x2', w - m.r).attr('y2', y(v))
        .attr('stroke', v ? C.rule : C.ink).attr('stroke-width', v ? .9 : 2).attr('stroke-dasharray', v ? '2 5' : null);
      txt(svg, m.l - 8, y(v) + 4, grk(v), { f: MON, s: w * .0105, c: C.mute, a: 'end' });
    });
    const M = [[0, 1100, 'ΠΗΓΕΣ · Πίνδος'], [60, 240, 'ΚΑΛΑΜΠΑΚΑ · Μετέωρα'], [85, 115, 'ΤΡΙΚΑΛΑ'],
    [120, 74, 'ΛΑΡΙΣΑ'], [178, 30, 'ΤΕΜΠΗ'], [205, 0, 'ΣΤΟΜΙΟ · Αιγαίο']];
    M.forEach(([k, v, n], i) => {
      svg.append('circle').attr('cx', x(k)).attr('cy', y(v)).attr('r', w * .0055).attr('fill', C.ink).attr('class', 'fade');
      svg.append('line').attr('x1', x(k)).attr('y1', y(v)).attr('x2', x(k)).attr('y2', h - m.b + h * .07)
        .attr('stroke', C.mute).attr('stroke-width', .8).attr('stroke-dasharray', '3 4').attr('class', 'fade');
      const yy = h - m.b + labTop + (i % 2) * tierStep;
      txt(svg, x(k), yy, n, { f: MON, s: w * .011, w: 600, a: i === 0 ? 'start' : i === M.length - 1 ? 'end' : 'middle', c: C.ink, ls: '.07em' });
      txt(svg, x(k), yy + lineH, k + ' km · ' + grk(v) + ' m', { f: MON, s: w * .0098, a: i === 0 ? 'start' : i === M.length - 1 ? 'end' : 'middle', c: C.mute });
    });
    txt(svg, m.l, m.t - h * .055, 'ΥΨΟΜΕΤΡΟ (m)', { f: MON, s: w * .0105, c: C.mute, ls: '.16em' });
    txt(svg, w - m.r, m.t - h * .055, 'ΑΠΟΣΤΑΣΗ ΚΑΤΑ ΜΗΚΟΣ ΤΗΣ ΚΟΙΤΗΣ (κατά προσέγγιση)', { f: MON, s: w * .0105, c: C.mute, ls: '.16em', a: 'end' });
  }

  /* ══════════ 07 · Karla area ══════════ */
  function karla() {
    const s = setup('karla'); if (!s) return;
    const { svg, w, h } = s;
    const D = [[1950, 180], [1961, 180], [1962, 180], [1963, 95], [1964, 30], [1965, 2], [1990, 0],
    [2009, 0], [2010, 8], [2012, 18], [2015, 26], [2018, 38], [2022, 38], [2023.6, 38],
    [2023.7, 180], [2023.95, 150], [2024.3, 55], [2025, 42]];
    const m = { t: h * .12, r: w * .035, b: h * .20, l: w * .055 };
    const x = d3.scaleLinear().domain([1950, 2025]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([0, 195]).range([h - m.b, m.t]);
    const area = d3.area().x(d => x(d[0])).y0(y(0)).y1(d => y(d[1])).curve(d3.curveStepAfter);
    const line = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveStepAfter);

    [0, 50, 100, 150].forEach(v => {
      svg.append('line').attr('x1', m.l).attr('y1', y(v)).attr('x2', w - m.r).attr('y2', y(v))
        .attr('stroke', v ? '#39423f' : C.paper).attr('stroke-width', v ? 1 : 2);
      txt(svg, m.l - 8, y(v) + 4, v, { f: MON, s: w * .0105, c: C.mute, a: 'end' });
    });
    svg.append('path').datum(D).attr('d', area).attr('fill', C.water).attr('opacity', .55).attr('class', 'fade');
    drawable(svg.append('path').datum(D).attr('d', line).attr('fill', 'none').attr('stroke', '#5fb3bf').attr('stroke-width', 3));

    d3.range(1950, 2026, 10).forEach(v => txt(svg, x(v), h - m.b + h * .075, v, { f: MON, s: w * .0115, c: C.mute, a: 'middle' }));

    const ann = [
      [1962, 180, 'ΑΠΟΞΗΡΑΝΣΗ 1962', '180 km² λίμνης γίνονται χωράφια', C.red, -1],
      [1985, 0, 'Η ΛΙΜΝΗ ΔΕΝ ΥΠΑΡΧΕΙ', '38 χρόνια ξηρού πυθμένα', C.mute, 1],
      [2018, 38, 'ΤΑΜΙΕΥΤΗΡΑΣ ≈38 km²', 'Η επαναπλήρωση ολοκληρώνεται', C.wheat, -1],
      [2023.7, 180, 'DANIEL, ΣΕΠ. 2023', 'Η Κάρλα ξαναγίνεται όσο ήταν το 1961', C.red, -1]
    ];
    ann.forEach(([k, v, t1, t2, col, dir]) => {
      const yy = y(v) + dir * h * .11;
      svg.append('line').attr('x1', x(k)).attr('y1', y(v)).attr('x2', x(k)).attr('y2', yy + (dir < 0 ? h * .03 : -h * .02))
        .attr('stroke', col).attr('stroke-width', 1.4).attr('class', 'fade');
      svg.append('circle').attr('cx', x(k)).attr('cy', y(v)).attr('r', w * .005).attr('fill', col).attr('class', 'fade');
      const an = k > 2015 ? 'end' : 'start', ox = k > 2015 ? -w * .008 : w * .008;
      txt(svg, x(k) + ox, yy, t1, { f: MON, s: w * .0135, w: 600, c: col, a: an, ls: '.08em' });
      txt(svg, x(k) + ox, yy + h * .05, t2, { s: w * .0125, c: '#bdb6a4', a: an });
    });
    txt(svg, m.l, m.t - h * .05, 'km²', { f: MON, s: w * .0115, c: C.mute, ls: '.16em' });
  }

  /* ══════════ 08 · Daniel rainfall ══════════ */
  function daniel() {
    const s = setup('daniel'); if (!s) return;
    const { svg, w, h } = s;
    const D = [
      { n: 'Ζαγορά Πηλίου', sub: '24 ώρες, 5 Σεπ. 2023', v: 754, c: C.red },
      { n: 'Λάρισα', sub: 'μέση ΕΤΗΣΙΑ βροχόπτωση', v: 413, c: C.teal },
      { n: 'Αθήνα', sub: 'μέση ΕΤΗΣΙΑ βροχόπτωση', v: 380, c: C.mute }
    ];
    // The box can be far taller than it is wide. Band heights (and therefore
    // any size derived from them) must stay width-bounded, or the labels
    // outgrow the horizontal gutters and clip off both edges.
    const band = Math.min(h, w * .62), top = (h - band) / 2;
    const m = { t: top + band * .10, r: w * .16, b: h - (top + band * .94), l: w * .32 };
    const y = d3.scaleBand().domain(D.map(d => d.n)).range([m.t, h - m.b]).padding(.42);
    const x = d3.scaleLinear().domain([0, 800]).range([m.l, w - m.r]);
    const fs = Math.min(y.bandwidth() * .44, w * .036);
    D.forEach(d => {
      const yy = y(d.n), bh = y.bandwidth();
      svg.append('rect').attr('x', m.l).attr('y', yy).attr('width', x(d.v) - m.l).attr('height', bh)
        .attr('fill', d.c).attr('class', 'gw2').style('transform-origin', `${m.l}px 0`);
      txt(svg, m.l - w * .018, yy + bh * .5 - fs * .18, d.n, { f: SER, s: fs, w: 700, a: 'end', b: 'middle' });
      txt(svg, m.l - w * .018, yy + bh * .5 + fs * .78, d.sub, { f: MON, s: fs * .52, a: 'end', c: C.mute, b: 'middle' });
      txt(svg, x(d.v) + w * .016, yy + bh * .5, grk(d.v) + ' mm', { f: MON, s: fs * .86, w: 600, c: d.c, b: 'middle' });
    });
    if (ANIM()) {
      svg.selectAll('.gw2').style('transform', 'scaleX(0)').style('transition', 'transform 1.4s cubic-bezier(.2,.7,.25,1)');
      svg.node().closest('.page').addEventListener('om-in', () => svg.selectAll('.gw2').style('transform', 'scaleX(1)'));
    }
  }

  /* ══════════ 11 · magoula stratigraphy ══════════ */
  function magoula() {
    const s = setup('magoula'); if (!s) return;
    const { svg, w, h } = s;
    const L = [
      { n: 'Αρχαιότερη Νεολιθική', d: '6800–5800 π.Χ.', c: '#8a6d3f' },
      { n: 'Μέση Νεολιθική', d: '5800–5300 π.Χ.', c: '#9c8050' },
      { n: 'Νεότερη Νεολιθική', d: '5300–4500 π.Χ.', c: '#ae9463' },
      { n: 'Τελική Νεολιθική', d: '4500–3300 π.Χ.', c: '#bfa87c' },
      { n: 'Εποχή Χαλκού', d: '3300–1100 π.Χ.', c: '#cdbb96' },
      { n: 'Ιστορικοί χρόνοι', d: '1100 π.Χ. – 1900 μ.Χ.', c: '#dbceb2' }
    ];
    const m = { t: h * .10, r: w * .34, b: h * .10, l: w * .05 };
    const bw = w - m.l - m.r, bh = (h - m.t - m.b) / (L.length + .6);
    L.slice().reverse().forEach((l, i) => {
      const yy = m.t + i * bh;
      const inset = i * bw * .055;
      const g = svg.append('g').attr('class', 'rvl');
      if (ANIM()) g.style('opacity', 0).style('transition', 'opacity .7s ease ' + (i * .12) + 's');
      g.append('path')
        .attr('d', `M${m.l + inset} ${yy + bh} L${m.l + inset + bw * .055} ${yy} L${m.l + bw - inset - bw * .055} ${yy} L${m.l + bw - inset} ${yy + bh} Z`)
        .attr('fill', l.c).attr('stroke', C.paper).attr('stroke-width', 1.5);
      const lx = m.l + bw + w * .022;
      g.append('line').attr('x1', m.l + bw - inset).attr('y1', yy + bh * .5).attr('x2', lx - w * .008).attr('y2', yy + bh * .5)
        .attr('stroke', C.rule).attr('stroke-width', 1).attr('stroke-dasharray', '2 3');
      txt(g, lx, yy + bh * .42, l.n, { f: SER, s: Math.min(bh * .46, w * .019), w: 700, b: 'middle' });
      txt(g, lx, yy + bh * .78, l.d, { f: MON, s: Math.min(bh * .3, w * .013), c: C.mute, b: 'middle' });
    });
    const gy = m.t + L.length * bh;
    svg.append('rect').attr('x', 0).attr('y', gy).attr('width', w).attr('height', h - gy).attr('fill', C.paper2).attr('opacity', .6);
    svg.append('line').attr('x1', 0).attr('y1', gy).attr('x2', w).attr('y2', gy).attr('stroke', C.ink).attr('stroke-width', 2.5);
    txt(svg, m.l, gy + h * .1, 'ΦΥΣΙΚΟ ΕΔΑΦΟΣ ΤΗΣ ΠΕΔΙΑΔΑΣ', { f: MON, s: w * .014, c: C.mute, ls: '.14em' });
    txt(svg, m.l + bw / 2, m.t - h * .035, 'σημερινή επιφάνεια — ο λόφος', { f: MON, s: w * .014, c: C.mute, a: 'middle', ls: '.1em' });
    if (ANIM()) svg.node().closest('.page').addEventListener('om-in', () => svg.selectAll('.rvl').style('opacity', 1));
  }

  /* ══════════ 12 · timeline ══════════ */
  function timeline() {
    const s = setup('timeline'); if (!s) return;
    const { svg, w, h } = s;
    const NOW = 2025;
    const E = [
      [-6800, 'Σέσκλο', 'Από τους αρχαιότερους οικισμούς της Ευρώπης', 1],
      [-4800, 'Διμήνι', 'Ομόκεντροι περίβολοι, «μέγαρο»', 0],
      [-1400, 'Μυκηναϊκή Ιωλκός', 'Το λιμάνι της Αργοναυτικής εκστρατείας', 1],
      [-1200, 'Αχιλλέας & Φθία', 'Οι Μυρμιδόνες φεύγουν για την Τροία', 0],
      [-600, 'Τα άλογα στα νομίσματα', 'Η Λάρισα κόβει νόμισμα με ίππο', 1],
      [-370, 'Θάνατος Ιπποκράτη', 'Στη Λάρισα', 0],
      [-352, 'Φίλιππος Β΄', 'Ταγός της Θεσσαλίας — το ιππικό περνά στη Μακεδονία', 1],
      [-197, 'Κυνός Κεφαλαί', 'Η Ρώμη συντρίβει τη Μακεδονία στη Θεσσαλία', 0],
      [-48, 'Φάρσαλος', 'Καίσαρας εναντίον Πομπηίου — τέλος της Δημοκρατίας', 1],
      [1204, 'Φραγκοκρατία', 'Μετά την Δ΄ Σταυροφορία', 0],
      [1423, 'Οθωμανική κατάκτηση', 'Η Λάρισα γίνεται Yenişehir', 1],
      [1881, 'Προσάρτηση στην Ελλάδα', 'Σύμβαση Κωνσταντινουπόλεως', 0],
      [1923, 'Πρόσφυγες & αγροτική μεταρρύθμιση', 'Τα τσιφλίκια μοιράζονται', 1],
      [1962, 'Αποξήρανση της Κάρλας', '', 0],
      [2023, 'Κακοκαιρία Daniel', 'Ο κάμπος ξαναγίνεται λίμνη', 1]
    ];
    const m = { l: w * .04, r: w * .04 };
    const ago = yr => NOW - yr;
    const x = d3.scalePow().exponent(.42).domain([ago(-7200), ago(NOW)]).range([m.l, w - m.r]);
    const axy = h * .5;
    svg.append('line').attr('x1', m.l).attr('y1', axy).attr('x2', w - m.r).attr('y2', axy)
      .attr('stroke', C.paper).attr('stroke-width', 3);
    // scalePow(.42) compresses the middle of the axis, so a fixed tick set
    // collides there; keep a tick's label only when it clears the last kept one.
    let lastRight = -Infinity;
    [-7000, -5000, -3000, -2000, -1000, -500, 0, 500, 1000, 1500, 1800, 1900, 2000].forEach(v => {
      const xx = x(ago(v));
      svg.append('line').attr('x1', xx).attr('y1', axy - 8).attr('x2', xx).attr('y2', axy + 8).attr('stroke', '#5a635f').attr('stroke-width', 1.5);
      const t = txt(svg, xx, axy + h * .052, v < 0 ? Math.abs(v) + ' π.Χ.' : (v === 0 ? '0' : v),
        { f: MON, s: w * .0105, c: C.mute, a: 'middle' });
      const half = t.node().getComputedTextLength() / 2, pad = w * .006;
      if (xx - half < lastRight + pad) t.remove(); else lastRight = xx + half;
    });
    // Tier is chosen by measured collision, not by index: an edge-clamped label
    // can land on top of a neighbour that a modulo tier assignment can't see.
    const occupied = {};
    const ROW0 = h * .10, ROWH = h * .062;
    const ROWS = Math.max(2, Math.floor((h * .42 - ROW0) / ROWH));
    E.forEach(([yr, t1, t2, up], i) => {
      const xx = x(ago(yr)), dir = up ? -1 : 1;
      const g = svg.append('g').attr('class', 'rvl2');
      if (ANIM()) g.style('opacity', 0).style('transition', 'opacity .6s ease ' + (i * .07) + 's');
      const stem = g.append('line').attr('x1', xx).attr('y1', axy).attr('x2', xx).attr('stroke', '#4d5854').attr('stroke-width', 1.2);
      g.append('circle').attr('cx', xx).attr('cy', axy).attr('r', w * .0035).attr('fill', C.wheat);
      const tTitle = txt(g, xx, 0, t1, { f: SER, s: w * .0165, w: 700, c: C.paper, a: 'middle' })
        .attr('dominant-baseline', dir < 0 ? 'auto' : 'hanging');
      const sub = (yr < 0 ? Math.abs(yr) + ' π.Χ.' : String(yr)) + (t2 ? ' · ' + t2 : '');
      const tSub = txt(g, xx, 0, sub, { f: MON, s: w * .0098, c: C.wheat, a: 'middle' })
        .attr('dominant-baseline', dir < 0 ? 'auto' : 'hanging');
      // The tick gutter is sized for the tick, not for a caption centred on it:
      // the first and last events would overhang by half their label width.
      const len = Math.max(tTitle.node().getComputedTextLength(), tSub.node().getComputedTextLength());
      let anc = 'middle', ax = xx;
      if (xx - len / 2 < m.l) { anc = 'start'; ax = m.l; }
      else if (xx + len / 2 > w - m.r) { anc = 'end'; ax = w - m.r; }
      if (anc !== 'middle') [tTitle, tSub].forEach(t => t.attr('text-anchor', anc).attr('x', ax));
      const x1 = anc === 'start' ? ax : anc === 'end' ? ax - len : ax - len / 2;
      const x2 = x1 + len, pad = w * .014;
      // Rows are derived from the space each side actually has, and the chosen
      // row ALWAYS records its range — a fixed cap with a silent fallback let
      // two events pile onto the last row.
      let tier = 0, best = 0, bestHits = Infinity;
      for (; tier < ROWS; tier++) {
        const occ = occupied[dir + ':' + tier] || (occupied[dir + ':' + tier] = []);
        const hits = occ.filter(r => x1 - pad < r[1] && r[0] < x2 + pad).length;
        if (hits === 0) break;
        if (hits < bestHits) { bestHits = hits; best = tier; }
      }
      if (tier === ROWS) tier = best;
      (occupied[dir + ':' + tier] || (occupied[dir + ':' + tier] = [])).push([x1, x2]);
      const tip = axy + dir * (ROW0 + tier * ROWH);
      stem.attr('y2', tip);
      tTitle.attr('y', tip + dir * h * .022);
      tSub.attr('y', tip + dir * h * .022 + (dir < 0 ? -h * .032 : h * .034));
    });
    txt(svg, m.l, h * .05, 'ΚΛΙΜΑΚΑ ΜΗ ΓΡΑΜΜΙΚΗ · non-linear scale', { f: MON, s: w * .011, c: C.mute, ls: '.16em' });
    // The two sides fill different numbers of rows, so the axis sits off-centre
    // in the box. Re-centre everything on the ink that was actually drawn.
    const node = svg.node(), root = document.createElementNS('http://www.w3.org/2000/svg', 'g');
    while (node.firstChild) root.appendChild(node.firstChild);
    node.appendChild(root);
    const ink = root.getBBox();
    root.setAttribute('transform', 'translate(0,' + ((h - ink.height) / 2 - ink.y) + ')');
    if (ANIM()) svg.node().closest('.page').addEventListener('om-in', () => svg.selectAll('.rvl2').style('opacity', 1));
  }

  /* ══════════ 13 · population ══════════ */
  function pop() {
    const s = setup('pop'); if (!s) return;
    const { svg, w, h } = s;
    const D = [[1951, 606000, 1], [1961, 694000, 1], [1971, 660000, 1], [1981, 695000, 1],
    [1991, 734000, 1], [2001, 754000, 1], [2011, 732762], [2021, 688255]];
    const m = { t: h * .13, r: w * .06, b: h * .16, l: w * .12 };
    const x = d3.scaleLinear().domain([1951, 2021]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([560000, 790000]).range([h - m.b, m.t]);
    const line = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveMonotoneX);

    [600000, 700000, 750000].forEach(v => {
      svg.append('line').attr('x1', m.l).attr('y1', y(v)).attr('x2', w - m.r).attr('y2', y(v)).attr('stroke', C.rule).attr('stroke-dasharray', '2 4');
      txt(svg, m.l - 8, y(v) + 4, grk(v / 1000) + 'χιλ.', { f: MON, s: w * .019, c: C.mute, a: 'end' });
    });
    drawable(svg.append('path').datum(D).attr('d', line).attr('fill', 'none').attr('stroke', C.ink).attr('stroke-width', 3));
    D.forEach(d => {
      svg.append('circle').attr('cx', x(d[0])).attr('cy', y(d[1])).attr('r', w * .008)
        .attr('fill', d[2] ? C.paper : C.ink).attr('stroke', C.ink).attr('stroke-width', 2).attr('class', 'fade');
      txt(svg, x(d[0]), h - m.b + h * .09, d[0], { f: MON, s: w * .019, c: C.mute, a: 'middle' });
    });
    const p1 = D[5], p2 = D[7];
    svg.append('line').attr('x1', x(p1[0])).attr('y1', y(p1[1])).attr('x2', x(p2[0])).attr('y2', y(p2[1]))
      .attr('stroke', C.red).attr('stroke-width', 3).attr('class', 'fade');
    txt(svg, x(2021), y(688255) - h * .07, '−8,8% από το 2001', { f: MON, s: w * .022, w: 600, c: C.red, a: 'end' });
    txt(svg, m.l, m.t - h * .05, 'ΜΟΝΙΜΟΣ ΠΛΗΘΥΣΜΟΣ ΘΕΣΣΑΛΙΑΣ', { f: MON, s: w * .019, c: C.mute, ls: '.14em' });
    txt(svg, m.l, h - h * .015, 'ΕΛΣΤΑΤ. Τιμές πριν το 2011 κατά προσέγγιση.', { f: MON, s: w * .017, c: C.mute });
  }


  /* ══════════ 14 · transhumance — the double journey ══════════ */
  function trans() {
    const s = setup('trans'); if (!s) return;
    const { svg, w, h } = s;
    // Left margin must hold a right-anchored '1.500' label, not just the axis.
    const m = { l: w * .085, r: w * .045, t: h * .17, b: h * .21 };
    // Month index 0..11; the flock's altitude through the year.
    const D = [[0,110],[1,110],[2,120],[3,320],[4,1150],[5,1500],[6,1550],[7,1550],
               [8,1350],[9,520],[10,140],[11,110]];
    const MO = ['Ι','Φ','Μ','Α','Μ','Ι','Ι','Α','Σ','Ο','Ν','Δ'];
    const x = d3.scaleLinear().domain([0, 11]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([0, 1700]).range([h - m.b, m.t]);

    [0, 500, 1000, 1500].forEach(v => {
      svg.append('line').attr('x1', m.l).attr('x2', w - m.r).attr('y1', y(v)).attr('y2', y(v))
        .attr('stroke', C.rule).attr('stroke-width', v ? 1 : 2).attr('class', 'fade');
      txt(svg, m.l - w * .008, y(v) + h * .022, grk(v), { f: MON, s: w * .019, c: C.mute, a: 'end' });
    });
    // summer / winter pasture bands
    svg.append('rect').attr('x', x(4.6)).attr('y', y(1600)).attr('width', x(8.4) - x(4.6))
      .attr('height', y(1100) - y(1600)).attr('fill', C.teal).attr('opacity', .10).attr('class', 'fade');
    svg.append('rect').attr('x', m.l).attr('y', y(400)).attr('width', w - m.r - m.l)
      .attr('height', y(0) - y(400)).attr('fill', C.wheat).attr('opacity', .22).attr('class', 'fade');

    const line = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveMonotoneX);
    drawable(svg.append('path').datum(D).attr('d', line).attr('fill', 'none')
      .attr('stroke', C.red).attr('stroke-width', Math.max(3, w * .006)));
    D.forEach(d => {
      svg.append('circle').attr('cx', x(d[0])).attr('cy', y(d[1])).attr('r', w * .007)
        .attr('fill', C.paper).attr('stroke', C.red).attr('stroke-width', 2).attr('class', 'fade');
      txt(svg, x(d[0]), h - m.b + h * .10, MO[d[0]], { f: MON, s: w * .021, c: C.mute, a: 'middle' });
    });
    txt(svg, x(6.5), y(1550) - h * .055, 'ΘΕΡΙΝΑ ΒΟΣΚΟΤΟΠΙΑ · ΠΙΝΔΟΣ, ΟΛΥΜΠΟΣ',
      { f: MON, s: w * .021, w: 600, c: C.teal, a: 'middle' });
    txt(svg, x(0.6), y(300), 'ΧΕΙΜΕΡΙΝΑ · Ο ΚΑΜΠΟΣ ΚΑΙ Η ΑΚΤΗ',
      { f: MON, s: w * .021, w: 600, c: C.ochre });
    txt(svg, x(4.1), y(760), 'ΑΝΟΔΟΣ', { f: MON, s: w * .019, w: 600, c: C.red, a: 'end' });
    txt(svg, x(9.6), y(760), 'ΚΑΘΟΔΟΣ', { f: MON, s: w * .019, w: 600, c: C.red });
    txt(svg, m.l, m.t - h * .06, 'ΥΨΟΜΕΤΡΟ ΤΩΝ ΚΟΠΑΔΙΩΝ ΜΕΣΑ ΣΤΟΝ ΧΡΟΝΟ (m)',
      { f: MON, s: w * .02, c: C.mute, ls: '.14em' });
    txt(svg, m.l, h - h * .02, 'Σχηματικό. Οι ημερομηνίες κινούνταν με τον καιρό και τη βοσκή.',
      { f: MON, s: w * .018, c: C.mute });
  }

  /* ══════════ 15 · a night at the panigiri ══════════ */
  function panigiri() {
    const s = setup('panigiri'); if (!s) return;
    const { svg, w, h } = s;
    const P = C.paper, MU = '#8d8b7e', RU = '#39423f';
    const m = { l: w * .04, r: w * .04, t: h * .30, b: h * .26 };
    // hours after 20:00 -> intensity 0..1
    // Labels alternate between two levels: seven of them on one baseline
    // cannot fit across this width without overprinting each other.
    const D = [
      [0, .10, '20:00', 'Το τραπέζι', 0],
      [1, .18, '21:00', 'Της τάβλας', 1],
      [3, .45, '23:00', 'Συρτός στα τρία', 0],
      [4.5, .62, '00:30', 'Τσάμικος', 1],
      [6, .84, '02:00', 'Γρήγορα συρτά', 0],
      [7, 1.0, '03:00', 'Η κορύφωση', 1],
      [9, .30, '05:00', 'Το τελευταίο', 0]
    ];
    const x = d3.scaleLinear().domain([0, 9]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([0, 1.06]).range([h - m.b, m.t]);

    svg.append('line').attr('x1', m.l).attr('x2', w - m.r).attr('y1', y(0)).attr('y2', y(0))
      .attr('stroke', RU).attr('stroke-width', 2).attr('class', 'fade');
    const area = d3.area().x(d => x(d[0])).y0(y(0)).y1(d => y(d[1])).curve(d3.curveMonotoneX);
    svg.append('path').datum(D).attr('d', area).attr('fill', C.wheat).attr('opacity', .16).attr('class', 'fade');
    const line = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveMonotoneX);
    drawable(svg.append('path').datum(D).attr('d', line).attr('fill', 'none')
      .attr('stroke', C.wheat).attr('stroke-width', Math.max(3, w * .006)));

    D.forEach((d, i) => {
      const px = x(d[0]), py = y(d[1]);
      svg.append('line').attr('x1', px).attr('x2', px).attr('y1', py).attr('y2', y(0))
        .attr('stroke', RU).attr('stroke-width', 1).attr('class', 'fade');
      svg.append('circle').attr('cx', px).attr('cy', py).attr('r', w * .0075)
        .attr('fill', i === 5 ? C.red : C.deep).attr('stroke', C.wheat).attr('stroke-width', 2).attr('class', 'fade');
      const an = i === D.length - 1 ? 'end' : (i === 0 ? 'start' : 'middle');
      const lift = h * (d[4] ? .175 : .075);
      svg.append('line').attr('x1', px).attr('x2', px).attr('y1', py - h * .012).attr('y2', py - lift + h * .012)
        .attr('stroke', RU).attr('stroke-width', 1).attr('class', 'fade');
      txt(svg, px, py - lift - h * .048, d[2], { f: MON, s: w * .019, w: 600, c: i === 5 ? C.red : MU, a: an, ls: '.08em' });
      txt(svg, px, py - lift, d[3], { f: SER, s: w * .026, w: 700, c: P, a: an });
    });
    txt(svg, m.l, m.t - h * .16, 'ΕΝΤΑΣΗ ΤΗΣ ΒΡΑΔΙΑΣ, 20:00 → 05:00',
      { f: MON, s: w * .02, c: MU, ls: '.14em' });
  }


  /* ══════════ 17 · temperature over time ══════════
     Draws from data/climate.json. While that file is marked provisional the
     chart stamps itself, so an unsourced series can never print silently. */
  let CLIM = null;
  function temptime() {
    const s = setup('temptime'); if (!s || !CLIM) return;
    const { svg, w, h } = s;
    const P = C.paper, MU = '#8d8b7e', RU = '#39423f';
    const S = CLIM.series, prov = CLIM.status === 'provisional';
    const m = { l: w * .05, r: w * .13, t: h * .12, b: h * .16 };
    const yrs = S.years;
    const all = S.thessaly.concat(S.larissa);
    const x = d3.scaleLinear().domain([yrs[0], yrs[yrs.length - 1]]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([d3.min(all) - .8, d3.max(all) + .6]).range([h - m.b, m.t]).nice();

    y.ticks(5).forEach(v => {
      svg.append('line').attr('x1', m.l).attr('x2', w - m.r).attr('y1', y(v)).attr('y2', y(v))
        .attr('stroke', RU).attr('stroke-width', 1).attr('class', 'fade');
      txt(svg, m.l - w * .008, y(v) + h * .018, v.toFixed(0) + '°', { f: MON, s: w * .019, c: MU, a: 'end' });
    });
    d3.range(1960, 2025, 10).forEach(v => txt(svg, x(v), h - m.b + h * .085, v,
      { f: MON, s: w * .019, c: MU, a: 'middle' }));

    const line = d3.line().x((d, i) => x(yrs[i])).y(d => y(d)).curve(d3.curveMonotoneX);
    [['thessaly', C.wheat, 'ΘΕΣΣΑΛΙΑ'], ['larissa', C.red, 'ΛΑΡΙΣΑ']].forEach(([k, col, lab]) => {
      drawable(svg.append('path').datum(S[k]).attr('d', line).attr('fill', 'none')
        .attr('stroke', col).attr('stroke-width', Math.max(3, w * .0055)));
      // markers only for sparse series; 65 annual points would just clutter the line
      if (yrs.length <= 30) S[k].forEach((v, i) => svg.append('circle').attr('cx', x(yrs[i])).attr('cy', y(v)).attr('r', w * .0055)
        .attr('fill', C.deep).attr('stroke', col).attr('stroke-width', 2).attr('class', 'fade'));
      const last = S[k][S[k].length - 1];
      txt(svg, w - m.r + w * .012, y(last) + h * .016, lab, { f: MON, s: w * .021, w: 600, c: col, ls: '.08em' });
      txt(svg, w - m.r + w * .012, y(last) + h * .062, last.toFixed(1).replace('.', ',') + ' °C', { f: MON, s: w * .019, c: MU });
    });
    // first decade vs last decade — two single years would let one hot year set the headline
    const mean = a => a.reduce((p, q) => p + q, 0) / a.length;
    const d0 = mean(S.thessaly.slice(0, 10)), d1 = mean(S.thessaly.slice(-10));
    txt(svg, m.l, m.t - h * .045, 'ΜΕΣΗ ΕΤΗΣΙΑ ΘΕΡΜΟΚΡΑΣΙΑ ΑΕΡΑ (°C)', { f: MON, s: w * .02, c: MU, ls: '.14em' });
    txt(svg, w - m.r, m.t - h * .045, '+' + (d1 - d0).toFixed(1).replace('.', ',') + ' °C ΣΕ ΜΙΑ ΓΕΝΙΑ',
      { f: MON, s: w * .02, w: 600, c: C.red, ls: '.08em', a: 'end' });
    txt(svg, w - m.r, m.t - h * .012, yrs[yrs.length - 10] + '–' + yrs[yrs.length - 1] + ' ΕΝΑΝΤΙ ' + yrs[0] + '–' + yrs[9],
      { f: MON, s: w * .019, c: MU, ls: '.08em', a: 'end' });
    if (prov) {
      // Box is sized FROM the rendered text and sits inside the plot area:
      // a guessed width clipped the stamp and overflowed the viewBox.
      const g = svg.append('g').attr('class', 'fade');
      const pad = w * .012;
      const label = txt(g, m.l + pad, m.t + h * .11, 'ΠΡΟΣΩΡΙΝΑ ΔΕΔΟΜΕΝΑ — ΜΗΝ ΕΚΤΥΠΩΘΕΙ',
        { f: MON, s: w * .019, w: 600, c: C.red, ls: '.06em' });
      const b = label.node().getBBox();
      g.insert('rect', 'text').attr('x', b.x - pad).attr('y', b.y - pad * .7)
        .attr('width', b.width + pad * 2).attr('height', b.height + pad * 1.4)
        .attr('fill', C.deep).attr('stroke', C.red).attr('stroke-width', 2);
    }
  }

  /* ══════════ 17 · why the cold pole is a hole ══════════ */
  function doline() {
    const s = setup('doline'); if (!s) return;
    const { svg, w, h } = s;
    const MU = '#8d8b7e';
    const m = { l: w * .03, r: w * .03, t: h * .16, b: h * .20 };
    const x = d3.scaleLinear().domain([0, 100]).range([m.l, w - m.r]);
    const y = d3.scaleLinear().domain([0, 100]).range([h - m.b, m.t]);
    // ridge — basin — ridge
    const T = [[0,42],[10,58],[20,88],[28,74],[36,40],[44,17],[50,12],[56,17],[64,40],[72,74],[80,88],[90,58],[100,42]];
    const ln = d3.line().x(d => x(d[0])).y(d => y(d[1])).curve(d3.curveMonotoneX);
    svg.append('path').datum(T.concat([[100, 0], [0, 0]])).attr('d', d3.area().x(d => x(d[0])).y0(y(0)).y1(d => y(d[1])).curve(d3.curveMonotoneX)(T))
      .attr('fill', '#1e2a28').attr('class', 'fade');
    drawable(svg.append('path').datum(T).attr('d', ln).attr('fill', 'none')
      .attr('stroke', C.paper).attr('stroke-width', Math.max(2, w * .004)));
    // pooled cold air
    svg.append('path').datum([[33,40],[42,20],[50,15],[58,20],[67,40]])
      .attr('d', d3.area().x(d => x(d[0])).y0(y(40)).y1(d => y(d[1])).curve(d3.curveMonotoneX))
      .attr('fill', C.snow).attr('opacity', .30).attr('class', 'fade');
    // drainage arrows down both flanks
    [[26,72,40,44],[74,72,60,44]].forEach(([x1,y1,x2,y2]) => {
      svg.append('line').attr('x1', x(x1)).attr('y1', y(y1)).attr('x2', x(x2)).attr('y2', y(y2))
        .attr('stroke', C.snow).attr('stroke-width', 2).attr('stroke-dasharray', '7 6').attr('class', 'fade');
      const a = Math.atan2(y(y2) - y(y1), x(x2) - x(x1)), r = w * .014;
      svg.append('path').attr('d', 'M' + x(x2) + ',' + y(y2) + 'L' + (x(x2) - r * Math.cos(a - .45)) + ',' + (y(y2) - r * Math.sin(a - .45)) +
        'L' + (x(x2) - r * Math.cos(a + .45)) + ',' + (y(y2) - r * Math.sin(a + .45)) + 'Z')
        .attr('fill', C.snow).attr('class', 'fade');
    });
    txt(svg, x(20), y(94), 'ΚΟΡΥΦΗ −14 °C', { f: MON, s: w * .022, w: 600, c: MU, a: 'middle' });
    txt(svg, x(80), y(94), 'ΚΟΡΥΦΗ −14 °C', { f: MON, s: w * .022, w: 600, c: MU, a: 'middle' });
    txt(svg, x(50), y(46), 'ΨΥΧΡΟΣ ΑΕΡΑΣ ΚΑΤΕΒΑΙΝΕΙ', { f: MON, s: w * .021, c: C.snow, a: 'middle', ls: '.06em' });
    txt(svg, x(50), y(2), 'ΠΥΘΜΕΝΑΣ ΔΟΛΙΝΗΣ  −34 °C', { f: MON, s: w * .026, w: 600, c: C.snow, a: 'middle', ls: '.06em' });
  }

  /* ---------- boot ---------- */
  function drawAll() {
    d3.json('./data/climate.json').then(j => {
      CLIM = j;
      const el = document.getElementById('climstatus');
      if (el) el.textContent = j.status === 'provisional'
        ? 'Προσωρινή σειρά — δεν έχει αντικατασταθεί με παρατηρήσεις. Βλ. HANDOFF.md'
        : 'Παρατηρήσεις · ' + (j.series._source || '');
      try { temptime(); } catch (e) { console.warn('temptime', e); }
    }).catch(e => console.warn('climate.json failed', e));
    d3.json(ATLAS).then(topo => {
      const land = topojson.feature(topo, topo.objects.countries).features;
      mapGreece(land); mapThess(land);
    }).catch(e => console.warn('atlas failed', e));
    [xsec, peaks, ring, pillars, river, karla, daniel, magoula, timeline, pop, trans, panigiri, temptime, doline].forEach(f => {
      try { f(); } catch (e) { console.warn(f.name, e); }
    });
    observe();
  }
  function observe() {
    const pages = document.querySelectorAll('.page');
    const io = new IntersectionObserver(es => es.forEach(e => {
      if (e.isIntersecting) { e.target.classList.add('in'); e.target.dispatchEvent(new Event('om-in')); }
    }), { threshold: 0, rootMargin: '200px' });
    pages.forEach(p => io.observe(p));
    if (window.ResizeObserver && !window.__thRO) {
      let t0;
      window.__thRO = new ResizeObserver(() => { clearTimeout(t0); t0 = setTimeout(drawAll, 250); });
      document.querySelectorAll('.ph').forEach(el => window.__thRO.observe(el));
    }
    const all = () => pages.forEach(p => { p.classList.add('in'); p.dispatchEvent(new Event('om-in')); });
    window.addEventListener('beforeprint', all);
    setTimeout(all, 9000);
  }
  function boot() {
    let tries = 0;
    (function wait() {
      const dp = document.querySelector('doc-page');
      if (dp && typeof dp._measure === 'function') { try { dp._measure(); } catch (e) { } }
      const p1 = document.getElementById('p01');
      const el = document.getElementById('mapThess');
      if (p1 && p1.offsetWidth > 1500 && el && el.parentElement.offsetWidth > 0) {
        const moOK = !window.matchMedia || matchMedia('(prefers-reduced-motion: no-preference)').matches;
        const clockOK = !!(document.timeline && document.timeline.currentTime > 0);
        if (moOK && clockOK) document.documentElement.classList.add('anim');
        (document.fonts ? document.fonts.ready : Promise.resolve()).then(drawAll);
        return;
      }
      if (tries++ < 180) requestAnimationFrame(wait);
    })();
  }
  if (document.readyState === 'complete') boot();
  else window.addEventListener('load', boot);
  let rt; window.addEventListener('resize', () => { clearTimeout(rt); rt = setTimeout(drawAll, 300); });
})();
