// Replay a list of input steps against a web game and record evidence.
//
// Usage: node play.js <steps.json> <out-dir>
//
// steps.json:
// {
//   "url": "http://localhost:8790/",
//   "viewport": [390, 844],          // phone portrait by default
//   "clearStorage": true,            // start from a fresh save
//   "storage": {"flutter.currentLevel": "30"},  // optional seed
//   "steps": [
//     {"wait": 6000},                // Flutter boot takes a few seconds
//     {"tap": [195, 550]},
//     {"drag": [[70, 450], [240, 500]], "ms": 300},
//     {"key": "Escape"},
//     {"shot": "after-drag"},        // -> <out-dir>/after-drag.png
//     {"burst": "landing", "frames": 6, "every": 50},  // screenshot sequence
//     {"frames": 2000},              // measure frame times for 2 s
//     {"viewport": [360, 640]},
//     {"semantics": true}            // dump Flutter's accessibility labels
//   ]
// }
//
// Writes <out-dir>/log.json: console errors, page errors, frame stats per
// "frames" step and semantics dumps. Exits 0 even when the game errors; read
// the log.
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

(async () => {
  const [stepsFile, out] = process.argv.slice(2);
  if (!stepsFile || !out) {
    console.error('usage: node play.js <steps.json> <out-dir>');
    process.exit(2);
  }
  const spec = JSON.parse(fs.readFileSync(stepsFile, 'utf8'));
  fs.mkdirSync(out, { recursive: true });
  const log = { console: [], pageErrors: [], frames: [], semantics: [], shots: [] };
  const browser = await chromium.launch();
  const [w, h] = spec.viewport || [390, 844];
  const page = await browser.newPage({ viewport: { width: w, height: h }, hasTouch: false });
  page.on('console', (m) => {
    // Skip headless-GPU noise caused by taking screenshots.
    if (/GL Driver Message|GPU stall due to ReadPixels/.test(m.text())) return;
    if (['error', 'warning'].includes(m.type())) log.console.push(`${m.type()}: ${m.text()}`);
  });
  page.on('pageerror', (e) => log.pageErrors.push(String(e)));

  await page.goto(spec.url);
  if (spec.clearStorage || spec.storage) {
    await page.evaluate((s) => {
      if (s.clear) localStorage.clear();
      for (const [k, v] of Object.entries(s.set || {})) localStorage.setItem(k, v);
    }, { clear: !!spec.clearStorage, set: spec.storage || {} });
    await page.goto(spec.url);
  }

  const shot = async (name) => {
    const file = path.join(out, `${name}.png`);
    await page.screenshot({ path: file });
    log.shots.push(file);
  };

  for (const [i, s] of (spec.steps || []).entries()) {
    try {
      if (s.wait) await page.waitForTimeout(s.wait);
      else if (s.tap) {
        await page.mouse.click(s.tap[0], s.tap[1]);
        await page.waitForTimeout(s.after ?? 150);
      } else if (s.drag) {
        const pts = s.drag, ms = s.ms ?? 300, n = Math.max(8, Math.round(ms / 16));
        await page.mouse.move(...pts[0]);
        await page.mouse.down();
        for (let k = 1; k < pts.length; k++) {
          const [ax, ay] = pts[k - 1], [bx, by] = pts[k];
          for (let j = 1; j <= n; j++) {
            await page.mouse.move(ax + ((bx - ax) * j) / n, ay + ((by - ay) * j) / n);
            await page.waitForTimeout(ms / n / (pts.length - 1));
          }
        }
        if (s.shotBeforeRelease) await shot(s.shotBeforeRelease);
        await page.mouse.up();
        await page.waitForTimeout(s.after ?? 150);
      } else if (s.key) await page.keyboard.press(s.key);
      else if (s.shot) await shot(s.shot);
      else if (s.burst) {
        for (let k = 0; k < (s.frames ?? 6); k++) {
          await shot(`${s.burst}-${k}`);
          await page.waitForTimeout(s.every ?? 50);
        }
      } else if (s.frames) {
        const stats = await page.evaluate((ms) => new Promise((res) => {
          const d = []; let last = performance.now(); const end = last + ms;
          const f = (t) => { d.push(t - last); last = t; t < end ? requestAnimationFrame(f) : res(d); };
          requestAnimationFrame(f);
        }), s.frames);
        stats.sort((a, b) => a - b);
        const pct = (p) => +stats[Math.floor((stats.length - 1) * p)].toFixed(1);
        log.frames.push({ step: i, count: stats.length, p50: pct(.5), p95: pct(.95),
          max: pct(1), over33ms: stats.filter((x) => x > 33).length });
      } else if (s.viewport) await page.setViewportSize({ width: s.viewport[0], height: s.viewport[1] });
      else if (s.semantics) {
        // Turn on Flutter's accessibility tree, then list labelled nodes with boxes.
        await page.evaluate(() => {
          const p = document.querySelector('flt-semantics-placeholder');
          if (p) p.click();
        });
        await page.waitForTimeout(500);
        log.semantics.push({ step: i, nodes: await page.evaluate(() =>
          [...document.querySelectorAll('flt-semantics [aria-label], flt-semantics[aria-label], flt-semantics span')]
            .map((e) => { const r = e.getBoundingClientRect();
              return { label: e.getAttribute('aria-label') || e.textContent.trim(),
                role: e.getAttribute('role'), box: [r.x, r.y, r.width, r.height].map(Math.round) }; })
            .filter((n) => n.label)) });
      }
    } catch (e) {
      log.pageErrors.push(`step ${i} (${JSON.stringify(s)}): ${e}`);
    }
  }
  fs.writeFileSync(path.join(out, 'log.json'), JSON.stringify(log, null, 2));
  console.log(JSON.stringify({ out, consoleErrors: log.console.length,
    pageErrors: log.pageErrors.length, frames: log.frames, shots: log.shots.length }));
  await browser.close();
})();
