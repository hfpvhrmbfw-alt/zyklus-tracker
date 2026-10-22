// Tests für Modell und Logik. Laufen ohne Browser: npm test (oder node --test tests/*.test.js)
// Die Fixtures in tests/fixtures/ sind sprachneutral (Eingabe + erwartetes Ergebnis)
// und lassen sich später für die Swift-Tests wiederverwenden.
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { toNum, toStr, sanitize, sanitizeSettings, parseImport, buildExport, isEmpty, blank, DEFAULTS } from '../src/model.js';
import { analyze, phaseOf, moodStats, findPatterns, makeDemo, moodDots } from '../src/logic.js';

const dir = new URL('./fixtures/', import.meta.url);
const load = name => JSON.parse(readFileSync(new URL(name, dir), 'utf8'));

/** Vergleich mit Toleranz für Kommazahlen (Fixtures sind auf 6 Stellen gerundet). */
function near(actual, expected, path = '') {
  if (typeof expected === 'number' && typeof actual === 'number') {
    assert.ok(Math.abs(actual - expected) < 1e-6, `${path}: ${actual} ≠ ${expected}`);
  } else if (Array.isArray(expected)) {
    assert.ok(Array.isArray(actual), `${path}: keine Liste`);
    assert.equal(actual.length, expected.length, `${path}: Länge`);
    expected.forEach((v, i) => near(actual[i], v, `${path}[${i}]`));
  } else if (expected && typeof expected === 'object') {
    assert.ok(actual && typeof actual === 'object', `${path}: kein Objekt`);
    assert.deepEqual(Object.keys(actual).sort(), Object.keys(expected).sort(), `${path}: Felder`);
    for (const k of Object.keys(expected)) near(actual[k], expected[k], `${path}.${k}`);
  } else {
    assert.equal(actual, expected, path);
  }
}

for (const file of readdirSync(dir).filter(f => f.startsWith('analyse-'))) {
  const fx = load(file);
  test(`Analyse: ${fx.beschreibung}`, () => {
    const today = toNum(fx.input.today);
    const an = analyze(fx.input.days, fx.input.settings, today);
    near(an, fx.expected.analyze, 'analyze');
    for (const [date, ph] of Object.entries(fx.expected.phases)) near(phaseOf(an, toNum(date)), ph, `phaseOf ${date}`);
    const st = moodStats(an, fx.input.days, today);
    near(st, fx.expected.moodStats, 'moodStats');
    near(findPatterns(st), fx.expected.patterns, 'findPatterns');
  });
}

test('Demodaten sind reproduzierbar', () => {
  const fx = load('analyse-demo.json');
  assert.deepEqual(makeDemo(toNum(fx.input.today)), fx.input.days);
});

test('sanitize prüft und begrenzt Einträge', () => {
  for (const c of load('sanitize.json')) assert.deepEqual(sanitize(c.input), c.expected);
});

test('Import: Formate, Versionen, Fehler', () => {
  for (const c of load('import.json')) assert.deepEqual(parseImport(c.input), c.expected, c.name);
});

test('Export lässt sich wieder importieren', () => {
  const days = [{ ...blank('2026-03-02'), flow: 3 }, { ...blank('2026-03-01'), moods: ['ruhig'] }];
  const data = buildExport(DEFAULTS, days, '2026-10-12T08:00:00.000Z');
  assert.deepEqual(data.days.map(d => d.date), ['2026-03-01', '2026-03-02']);
  const back = parseImport(JSON.parse(JSON.stringify(data)));
  assert.ok(back.ok);
  assert.deepEqual(back.days, data.days);
  assert.deepEqual(back.settings, DEFAULTS);
});

test('Einstellungen werden begrenzt', () => {
  assert.deepEqual(sanitizeSettings({ cycleLen: 5, periodLen: 'x', luteal: 30, theme: 'neon', font: 'comic' }), { cycleLen: 15, periodLen: 5, luteal: 18, theme: 'auto', font: 'klar' });
  assert.equal(sanitizeSettings({ font: 'mix' }).font, 'mix');
  assert.deepEqual(sanitizeSettings(null), DEFAULTS);
});

test('Datum ist zeitzonenfest', () => {
  assert.equal(toStr(toNum('2026-03-29')), '2026-03-29'); // Zeitumstellung
  assert.equal(toNum('2026-01-01') - toNum('2025-12-31'), 1);
});

test('Kleine Helfer', () => {
  assert.ok(isEmpty(blank('2026-01-01')));
  assert.deepEqual(moodDots({ ...blank('2026-01-01'), moods: ['gereizt', 'ruhig'] }), ['gut', 'schlecht']);
  assert.deepEqual(moodDots({ ...blank('2026-01-01'), stimmung: ['abends'], moods: ['gereizt'] }), ['abends']);
});
