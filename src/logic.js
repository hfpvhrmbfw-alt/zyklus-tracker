/* Logik: reine Funktionen. Daten rein, Daten raus.
   Kein DOM, kein Speicher, keine aktuelle Zeit: "heute" kommt immer als Tagnummer herein. */

import { toNum, toStr, blank, isEmpty, hasDetail, FLOW_PERIOD, MOODS, SYMPTOMS, STIMMUNG, MOOD_TONE, PHASES } from './model.js';

const mean = a => a.reduce((s, v) => s + v, 0) / a.length;

/**
 * @typedef {{start: number, end: number, len: number}} Period
 * @typedef {{start: number, len: number, periodLen: number, ok: boolean}} Cycle
 * @typedef {{start: number, day: number, next: number, overdue: number, ov: number, fs: number, fe: number, inPeriod: boolean, fertileNext?: boolean}} Current
 * @typedef {{today: number, periods: Period[], cycles: Cycle[], recent: Cycle[], avgCycle: number|null, avgPeriod: number|null, sd: number|null, C: number, P: number, L: number, current: Current|null}} Analysis
 */

/**
 * Erkennt Perioden und Zyklen, rechnet Durchschnitt und aktuellen Stand.
 * @param {import('./model.js').DayEntry[]} entries
 * @param {import('./model.js').Settings} settings
 * @param {number} today Tagnummer
 * @returns {Analysis}
 */
export function analyze(entries, settings, today) {
  const L = settings.luteal;
  const bleed = entries.filter(e => e.flow >= FLOW_PERIOD).map(e => toNum(e.date)).sort((a, b) => a - b);
  const periods = [];
  for (const n of bleed) {
    const p = periods[periods.length - 1];
    if (p && n - p.end <= 2) p.end = n; else periods.push({ start: n, end: n, len: 0 });
  }
  periods.forEach(p => { p.len = p.end - p.start + 1; });

  const cycles = [];
  for (let i = 0; i < periods.length - 1; i++) {
    const len = periods[i + 1].start - periods[i].start;
    cycles.push({ start: periods[i].start, len, periodLen: periods[i].len, ok: len >= 15 && len <= 60 });
  }
  const recent = cycles.filter(c => c.ok).slice(-6);
  const avgCycle = recent.length ? mean(recent.map(c => c.len)) : null;
  const done = periods.filter(p => p.end < today - 1).slice(-6);
  const avgPeriod = done.length ? mean(done.map(p => p.len)) : null;
  const sd = recent.length > 1 ? Math.sqrt(mean(recent.map(c => (c.len - avgCycle) ** 2))) : null;
  const C = Math.round(avgCycle || settings.cycleLen);
  const P = Math.round(avgPeriod || settings.periodLen);

  let current = null;
  if (periods.length) {
    const last = periods[periods.length - 1];
    const next = last.start + C;
    current = {
      start: last.start, day: today - last.start + 1, next,
      overdue: today > next ? today - next : 0,
      ov: next - L, fs: next - L - 5, fe: next - L + 1,
      inPeriod: today <= last.end,
    };
    if (current.fe < today && !current.overdue) { // Fenster dieses Zyklus vorbei → nächstes zeigen
      current.fs += C; current.fe += C; current.ov += C; current.fertileNext = true;
    }
  }
  return { today, periods, cycles, recent, avgCycle, avgPeriod, sd, C, P, L, current };
}

/**
 * @typedef {{phase: string, predicted: boolean, fertile: boolean, ovu: boolean, cycleDay: number, next: number}} DayPhase
 */
/**
 * Phase eines Tages: echte Periodenstarts, danach Fortschreibung mit Ø-Länge.
 * @param {Analysis} an @param {number} n Tagnummer @returns {DayPhase|null}
 */
export function phaseOf(an, n) {
  const { periods, C, P, L, today } = an;
  let i = -1;
  for (let k = periods.length - 1; k >= 0; k--) if (periods[k].start <= n) { i = k; break; }
  if (i < 0) return null;
  const p = periods[i];
  let start = p.start, end = p.end, next, predicted = false;
  if (periods[i + 1]) next = periods[i + 1].start;
  else if (n < p.start + C) next = p.start + C;
  else {
    const k = Math.floor((n - p.start) / C);
    start = p.start + k * C; end = start + P - 1; next = start + C; predicted = true;
  }
  if (!predicted && i === periods.length - 1 && n > today) predicted = true;
  const ov = next - L;
  const phase = n <= end ? 'men' : n < ov - 2 ? 'fol' : n <= ov + 1 ? 'ovu' : 'lut';
  return { phase, predicted, fertile: n >= ov - 5 && n <= ov + 1, ovu: n === ov, cycleDay: n - start + 1, next };
}

/** Farbpunkte für den Kalender: eigene Stimmungsangabe, sonst aus den Gefühlen. @returns {string[]} STIMMUNG-IDs */
export function moodDots(e) {
  const set = new Set(e.stimmung.length ? e.stimmung : e.moods.map(m => MOOD_TONE[m] || 'gut'));
  return STIMMUNG.filter(k => set.has(k));
}

/**
 * @typedef {{n: number, moods: Object<string, number>, syms: Object<string, number>, energy: number[]}} PhaseStats
 */
/** Zählt Gefühle, Symptome und Energie je Phase (nur Tage bis heute mit Angaben). @returns {Object<string, PhaseStats>} */
export function moodStats(an, entries, today) {
  const stats = {};
  PHASES.forEach(k => { stats[k] = { n: 0, moods: {}, syms: {}, energy: [] }; });
  for (const e of entries) {
    const n = toNum(e.date);
    if (n > today || !hasDetail(e)) continue;
    const ph = phaseOf(an, n);
    if (!ph) continue;
    const s = stats[ph.phase];
    s.n++;
    e.moods.forEach(m => { s.moods[m] = (s.moods[m] || 0) + 1; });
    e.symptoms.forEach(m => { s.syms[m] = (s.syms[m] || 0) + 1; });
    if (e.energy) s.energy.push(e.energy);
  }
  return stats;
}

/**
 * @typedef {{kind: 'mood'|'symptom', id: string, phase: string, share: number, otherShare: number}} FrequencyPattern
 * @typedef {{kind: 'energy', high: {phase: string, avg: number}, low: {phase: string, avg: number}}} EnergyPattern
 */
/**
 * Findet auffällige Häufungen je Phase. Liefert Daten, die Oberfläche formuliert die Sätze.
 * Höchstens fünf Häufigkeitsmuster (stärkste zuerst), danach optional ein Energiemuster.
 * @param {Object<string, PhaseStats>} stats @returns {Array<FrequencyPattern|EnergyPattern>}
 */
export function findPatterns(stats) {
  const out = [];
  const scan = (key, ids, kind) => {
    for (const id of ids) {
      const rows = PHASES.map(ph => ({ ph, n: stats[ph].n, c: stats[ph][key][id] || 0, p: 0 })).filter(r => r.n >= 3);
      const total = rows.reduce((s, r) => s + r.c, 0);
      if (rows.length < 2 || total < 4) continue;
      rows.forEach(r => { r.p = r.c / r.n; });
      const top = rows.reduce((a, b) => (b.p > a.p ? b : a));
      const rest = rows.filter(r => r !== top);
      const restN = rest.reduce((s, r) => s + r.n, 0), restC = rest.reduce((s, r) => s + r.c, 0);
      const other = restN ? restC / restN : 0;
      if (top.p >= 0.25 && top.p >= other * 1.6 + 0.05) {
        out.push({ score: top.p - other, pattern: { kind, id, phase: top.ph, share: top.p, otherShare: other } });
      }
    }
  };
  scan('moods', MOODS, 'mood');
  scan('syms', SYMPTOMS, 'symptom');
  // stabile Sortierung: bei gleichem Wert bleibt die Reihenfolge der Stammdaten
  out.sort((a, b) => b.score - a.score);
  const res = out.slice(0, 5).map(o => o.pattern);
  const en = PHASES.map(ph => ({ ph, v: stats[ph].energy })).filter(r => r.v.length >= 3)
    .map(r => ({ phase: r.ph, avg: mean(r.v) }));
  if (en.length >= 2) {
    const high = en.reduce((a, b) => (b.avg > a.avg ? b : a)), low = en.reduce((a, b) => (b.avg < a.avg ? b : a));
    if (high.avg - low.avg >= 0.5) res.push({ kind: 'energy', high, low });
  }
  return res;
}

/** Durchschnittliche Energie einer Liste (1–5) oder null. */
export const avgEnergy = v => (v.length ? mean(v) : null);

/** Häufigstes Symptom einer Phase. @returns {{id: string, share: number}|null} */
export function topSymptom(s) {
  const e = Object.entries(s.syms).sort((a, b) => b[1] - a[1])[0];
  return e ? { id: e[0], share: e[1] / s.n } : null;
}

// ---------- Demodaten (erfunden, reproduzierbar) ----------
/** @param {number} today Tagnummer @returns {import('./model.js').DayEntry[]} */
export function makeDemo(today) {
  let seed = 42; const rnd = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  const pick = (arr, k) => arr.filter(() => rnd() < k);
  const lens = [29, 27, 31, 28, 30, 28];
  let start = today - lens.reduce((s, v) => s + v, 0) - 3;
  const out = [];
  for (let c = 0; c <= lens.length; c++) {
    const len = lens[c] || 28, plen = 4 + Math.floor(rnd() * 3), ov = start + len - 14;
    for (let d = 0; d < len; d++) {
      const n = start + d;
      if (n > today) break;
      const e = blank(toStr(n));
      if (d < plen) e.flow = d === 0 ? 3 : d === 1 ? 4 : d < plen - 1 ? 2 + Math.round(rnd()) : 2;
      if (d === plen) e.flow = rnd() < 0.4 ? 1 : 0;
      if (rnd() < 0.65) {
        let moods, syms = [], energy;
        if (d < plen) { moods = pick(['muede', 'sensibel', 'lustlos', 'ruhig'], 0.45); syms = pick(['kraempfe', 'rueckenschmerzen', 'kopfschmerzen'], 0.45); energy = 2 + Math.round(rnd()); }
        else if (n < ov - 2) { moods = pick(['gluecklich', 'energiegeladen', 'selbstbewusst', 'ruhig'], 0.45); energy = 3 + Math.round(rnd() * 2); }
        else if (n <= ov + 1) { moods = pick(['gluecklich', 'selbstbewusst', 'energiegeladen'], 0.55); energy = 4 + Math.round(rnd()); }
        else if (n > start + len - 6) { moods = pick(['gereizt', 'traurig', 'sensibel', 'gestresst', 'muede'], 0.45); syms = pick(['brustspannen', 'heisshunger', 'blaehungen', 'unreine_haut'], 0.45); energy = 1 + Math.round(rnd() * 2); }
        else { moods = pick(['ruhig', 'muede', 'gestresst', 'gluecklich'], 0.35); syms = pick(['blaehungen'], 0.2); energy = 2 + Math.round(rnd() * 2); }
        e.moods = moods; e.symptoms = syms; e.energy = energy;
        if (rnd() < 0.25) e.stimmung = [rnd() < 0.5 ? 'abends' : 'ok'];
      }
      if (!isEmpty(e)) out.push(e);
    }
    start += len;
  }
  return out;
}
