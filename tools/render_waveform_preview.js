/**
 * Gera uma prévia em PNG da waveform, usando a mesma matemática do
 * CustomPainter do app, para conferência visual rápida.
 *
 * Uso: node tools/render_waveform_preview.js [saida.png]
 */
const fs = require('fs');
const path = require('path');
const { Resvg } = require('/tmp/raster/node_modules/@resvg/resvg-js');

const OUT = process.argv[2] || path.join(__dirname, '..', 'preview_waveform.png');

const DEEP = '#1B4DFF', MID = '#2E8BFF', BRIGHT = '#46E0FF', CYAN = '#7AF3FF';
const GRAD = [DEEP, MID, BRIGHT, CYAN];

function synthetic(i) {
  const a = Math.sin(i * 0.19) * 0.30;
  const b = Math.sin(i * 0.51 + 1.3) * 0.22;
  const c = Math.sin(i * 0.93 + 2.6) * 0.12;
  return Math.min(1, Math.max(0.06, 0.5 + a + b + c));
}

function meshPath(W, H, phase) {
  const layers = 7, centerY = H / 2, amplitude = H * 0.40;
  const basePeaks = Array.from({ length: 120 }, (_, i) => synthetic(i));
  const paths = [];

  for (let layer = 0; layer < layers; layer++) {
    const layerPhase = phase + layer * 0.55;
    const layerAmp = amplitude * (1 - layer * 0.075);
    let d = '';
    const segments = 150;
    for (let s = 0; s <= segments; s++) {
      const t = s / segments, x = t * W;
      const idx = Math.min(
        basePeaks.length - 1,
        Math.round(t * (basePeaks.length - 1)),
      );
      const sample = basePeaks[idx];
      const wobble =
        Math.sin(t * 6 + layerPhase) * 0.22 +
        Math.sin(t * 11 - layerPhase * 1.3) * 0.11;
      const y =
        centerY +
        (wobble + (sample - 0.45) * 0.55) * layerAmp *
          (0.55 + 0.45 * Math.sin(t * Math.PI));
      d +=
        s === 0
          ? `M${x.toFixed(2)},${y.toFixed(2)}`
          : `L${x.toFixed(2)},${y.toFixed(2)}`;
    }
    paths.push(d);
  }
  return paths;
}

function buildSvg() {
  const W = 760, H = 420;
  const parts = [];

  parts.push(`<defs>
    <linearGradient id="wg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${GRAD[0]}" stop-opacity="0.60"/>
      <stop offset="0.5" stop-color="${CYAN}" stop-opacity="0.30"/>
      <stop offset="1" stop-color="${GRAD[1]}" stop-opacity="0.65"/>
    </linearGradient>
    <linearGradient id="bg2" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${BRIGHT}"/>
      <stop offset="1" stop-color="${DEEP}"/>
    </linearGradient>
    <radialGradient id="halo" cx="50%" cy="50%" r="50%">
      <stop offset="0" stop-color="#1B4DFF" stop-opacity="0.22"/>
      <stop offset="1" stop-color="#1B4DFF" stop-opacity="0"/>
    </radialGradient>
  </defs>`);

  parts.push(`<rect width="${W}" height="${H}" fill="#05070D"/>`);
  parts.push(`<circle cx="${W / 2}" cy="${H / 2}" r="${H * 0.48}" fill="url(#halo)"/>`);

  for (const d of meshPath(W, H, 0.35)) {
    parts.push(
      `<path d="${d}" fill="none" stroke="url(#wg)" stroke-width="1.5" stroke-linecap="round"/>`,
    );
  }

  // Faixa de barras (editor) na parte inferior.
  const barW = 3, barGap = 2.4, step = barW + barGap;
  const count = Math.floor(W / step);
  const bh = 72, by = H - bh - 24;
  for (let i = 0; i < count; i++) {
    const x = i * step + barW / 2;
    const amp = Math.min(1, Math.max(0.05, synthetic(i * 1.7)));
    const h = Math.max(3, amp * bh);
    const played = x <= W * 0.42;
    parts.push(
      `<rect x="${x}" y="${by + (bh - h) / 2}" width="${barW}" height="${h}" rx="${barW}" fill="${
        played ? 'url(#bg2)' : 'rgba(255,255,255,.22)'
      }"/>`,
    );
  }

  // Cursor do editor.
  parts.push(
    `<rect x="${(W * 0.42).toFixed(1)}" y="${by - 8}" width="2" height="${bh + 16}" fill="#46E0FF"/>`,
  );

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${parts.join(
    '',
  )}</svg>`;
}

const svg = buildSvg();
fs.writeFileSync(OUT.replace(/\.png$/, '.svg'), svg);

const resvg = new Resvg(svg, { fitTo: { mode: 'width', value: 760 } });
fs.writeFileSync(OUT, resvg.render().asPng());
console.log(`gerado: ${OUT}`);
