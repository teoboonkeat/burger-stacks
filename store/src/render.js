// Render a store asset page to PNG.
// Usage: node render.js <html file (abs path, may include ?query)> <out.png> <w> <h> [scale]
let chromium;
try { ({ chromium } = require('playwright')); } catch (e) { ({ chromium } = require('/opt/node-tools/node_modules/playwright')); }
(async () => {
  const [f, o, w, h, s] = process.argv.slice(2);
  const b = await chromium.launch();
  const p = await b.newPage({ viewport: { width: +w, height: +h }, deviceScaleFactor: +(s || 1) });
  await p.goto('file://' + f);
  await p.waitForTimeout(400);
  await p.screenshot({ path: o });
  await b.close();
})();
