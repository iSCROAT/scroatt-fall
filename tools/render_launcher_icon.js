/**
 * Rasteriza o ícone do app (SVG) para os PNGs do Android mipmap.
 *
 * Uso: node tools/render_launcher_icon.js
 */
const fs = require('fs');
const path = require('path');
const { Resvg } = require('/tmp/raster/node_modules/@resvg/resvg-js');

const root = path.resolve(__dirname, '..');
const svgPath = path.join(root, 'app', 'assets', 'icons', 'app_icon.svg');
const resDir = path.join(root, 'app', 'android', 'app', 'src', 'main', 'res');

// densidades -> tamanho do ícone (o maior é 192px para o ic_launcher.png)
const targets = [
  ['mipmap-mdpi', 48],
  ['mipmap-hdpi', 72],
  ['mipmap-xhdpi', 96],
  ['mipmap-xxhdpi', 144],
  ['mipmap-xxxhdpi', 192],
];

const svg = fs.readFileSync(svgPath);

for (const [dir, size] of targets) {
  const outDir = path.join(resDir, dir);
  fs.mkdirSync(outDir, { recursive: true });

  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
    background: 'rgba(0,0,0,0)',
  });
  const png = resvg.render().asPng();

  const outFile = path.join(outDir, 'ic_launcher.png');
  fs.writeFileSync(outFile, png);
  console.log(`${dir}/ic_launcher.png (${size}x${size}) - ${png.length} bytes`);
}

// Ícone redondo (Android 8+ adaptive icon legacy)
for (const [dir, size] of targets) {
  const outDir = path.join(resDir, dir);
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: size },
    background: 'rgba(0,0,0,0)',
  });
  const png = resvg.render().asPng();
  fs.writeFileSync(path.join(outDir, 'ic_launcher_round.png'), png);
}

console.log('OK');
