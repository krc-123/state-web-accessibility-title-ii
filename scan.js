// scan.js: run axe-core against every page in pages.csv and write
// data/pages_scanned.csv, data/violations.csv, data/nodes.csv.
//
// Usage: node scan.js pages.csv data/
// Needs: npm install playwright axe-core  (and a Chromium for Playwright)

const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');

const AXE_PATH = require.resolve('axe-core/axe.min.js');
const AXE_VERSION = require('axe-core/package.json').version;
const CONCURRENCY = 3;
const NAV_TIMEOUT_MS = 45000;
const SETTLE_MS = 2500;

function parseCsv(text) {
  const rows = [];
  let row = [], field = '', inQ = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (inQ) {
      if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
      else if (c === '"') inQ = false;
      else field += c;
    } else if (c === '"') inQ = true;
    else if (c === ',') { row.push(field); field = ''; }
    else if (c === '\n') { row.push(field); rows.push(row); row = []; field = ''; }
    else if (c !== '\r') field += c;
  }
  if (field.length || row.length) { row.push(field); rows.push(row); }
  const header = rows.shift();
  return rows.filter(r => r.length === header.length).map(r => Object.fromEntries(header.map((h, i) => [h, r[i]])));
}

function csvEscape(v) {
  if (v === null || v === undefined) return '';
  const s = String(v);
  return /[",\n\r]/.test(s) ? '"' + s.replace(/"/g, '""') + '"' : s;
}

function writeCsv(file, header, rows) {
  const out = [header.join(',')].concat(rows.map(r => header.map(h => csvEscape(r[h])).join(','))).join('\n') + '\n';
  fs.writeFileSync(file, out);
}

function wcagFromTags(tags) {
  // axe tags like wcag111 -> 1.1.1, wcag1412 -> 1.4.12
  return tags.filter(t => /^wcag\d{3,4}$/.test(t)).map(t => {
    const d = t.slice(4);
    return d.length === 3 ? `${d[0]}.${d[1]}.${d[2]}` : `${d[0]}.${d[1]}.${d.slice(2)}`;
  }).join('|');
}

async function scanOne(browser, p, idx, total) {
  const context = await browser.newContext({
    viewport: { width: 1280, height: 900 },
    userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/129.0 Safari/537.36',
    locale: 'en-US',
    ignoreHTTPSErrors: true,
    bypassCSP: true, // axe is injected as a script tag; the page's CSP must not block it
  });
  const page = await context.newPage();
  const started = Date.now();
  const rec = {
    state: p.state, state_name: p.state_name, category: p.category, category_label: p.category_label,
    requested_url: p.url, final_url: '', http_status: '', page_title: '', scan_timestamp_utc: new Date().toISOString(),
    axe_version: AXE_VERSION, elapsed_ms: '', scan_ok: 'FALSE', error: '',
    n_rules_failed: '', n_nodes_failed: '', n_rules_passed: '', n_rules_incomplete: '',
    n_requests_failed: 0, failed_request_hosts: '',
  };
  const failedHosts = new Set();
  page.on('requestfailed', req => { rec.n_requests_failed++; try { failedHosts.add(new URL(req.url()).host); } catch (e) {} });
  const violations = [];
  const nodes = [];
  try {
    const resp = await page.goto(p.url, { waitUntil: 'load', timeout: NAV_TIMEOUT_MS });
    await page.waitForTimeout(SETTLE_MS);
    rec.http_status = resp ? resp.status() : '';
    rec.final_url = page.url();
    rec.page_title = (await page.title()).trim();
    await page.addScriptTag({ path: AXE_PATH });
    const r = await page.evaluate(async () => await axe.run(document, {
      resultTypes: ['violations', 'passes', 'incomplete'],
      runOnly: { type: 'tag', values: ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa', 'wcag22aa', 'best-practice'] },
    }));
    rec.scan_ok = 'TRUE';
    rec.n_rules_failed = r.violations.length;
    rec.n_nodes_failed = r.violations.reduce((a, v) => a + v.nodes.length, 0);
    rec.n_rules_passed = r.passes.length;
    rec.n_rules_incomplete = r.incomplete.length;
    for (const v of r.violations) {
      const impacts = {};
      v.nodes.forEach(n => { impacts[n.impact] = (impacts[n.impact] || 0) + 1; });
      violations.push({
        state: p.state, category: p.category, requested_url: p.url, final_url: rec.final_url,
        rule_id: v.id, impact: v.impact, help: v.help, description: v.description, help_url: v.helpUrl,
        tags: v.tags.join('|'), wcag_criteria: wcagFromTags(v.tags),
        is_wcag21aa_scope: v.tags.some(t => ['wcag2a', 'wcag2aa', 'wcag21a', 'wcag21aa'].includes(t)) ? 'TRUE' : 'FALSE',
        is_best_practice_only: v.tags.includes('best-practice') && !v.tags.some(t => /^wcag2/.test(t)) ? 'TRUE' : 'FALSE',
        n_nodes: v.nodes.length,
        n_critical: impacts.critical || 0, n_serious: impacts.serious || 0, n_moderate: impacts.moderate || 0, n_minor: impacts.minor || 0,
      });
      v.nodes.slice(0, 5).forEach((n, i) => {
        nodes.push({
          state: p.state, category: p.category, final_url: rec.final_url, rule_id: v.id, node_index: i + 1,
          impact: n.impact, target: (n.target || []).join(' '), html_snippet: (n.html || '').slice(0, 300),
          failure_summary: (n.failureSummary || '').replace(/\s+/g, ' ').slice(0, 400),
        });
      });
    }
  } catch (e) {
    rec.error = String(e.message || e).split('\n')[0].slice(0, 300);
    rec.final_url = rec.final_url || page.url();
  } finally {
    rec.elapsed_ms = Date.now() - started;
    rec.failed_request_hosts = [...failedHosts].join('|');
    await context.close();
  }
  console.log(`[${idx + 1}/${total}] ${p.state} ${p.category} ok=${rec.scan_ok} status=${rec.http_status} rules_failed=${rec.n_rules_failed} nodes=${rec.n_nodes_failed} ${rec.error}`);
  return { rec, violations, nodes };
}

(async () => {
  const [,, pagesFile, outDir] = process.argv;
  const pages = parseCsv(fs.readFileSync(pagesFile, 'utf8')).filter(p => p.url);
  fs.mkdirSync(outDir, { recursive: true });
  const browser = await chromium.launch({ executablePath: process.env.CHROMIUM_PATH || undefined });
  const results = new Array(pages.length);
  let next = 0;
  async function worker() {
    while (next < pages.length) {
      const i = next++;
      results[i] = await scanOne(browser, pages[i], i, pages.length);
    }
  }
  await Promise.all(Array.from({ length: CONCURRENCY }, worker));
  await browser.close();

  const recs = results.map(r => r.rec);
  const viol = results.flatMap(r => r.violations);
  const nds = results.flatMap(r => r.nodes);
  writeCsv(path.join(outDir, 'pages_scanned.csv'), Object.keys(recs[0]), recs);
  writeCsv(path.join(outDir, 'violations.csv'), Object.keys(viol[0] || { state: '' }), viol);
  writeCsv(path.join(outDir, 'nodes.csv'), Object.keys(nds[0] || { state: '' }), nds);
  const ok = recs.filter(r => r.scan_ok === 'TRUE').length;
  console.log(`\nDone. ${ok}/${recs.length} pages scanned. ${viol.length} rule failures, ${viol.reduce((a, v) => a + v.n_nodes, 0)} failing elements.`);
})();
