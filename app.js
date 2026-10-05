/* Zyklus-Tracker · reine Frontend-PWA, Daten nur lokal (IndexedDB, Fallback localStorage) */
'use strict';

// ---------- Stammdaten ----------
const FLOW = [[0, 'Keine'], [1, 'Schmierblutung'], [2, 'Leicht'], [3, 'Mittel'], [4, 'Stark']];
const MOODS = [
  ['gluecklich', 'Glücklich'], ['ruhig', 'Ruhig'], ['energiegeladen', 'Energiegeladen'], ['selbstbewusst', 'Selbstbewusst'],
  ['gut', 'Gut'], ['zufrieden', 'Zufrieden'], ['dankbar', 'Dankbar'], ['entspannt', 'Entspannt'],
  ['ausgeglichen', 'Ausgeglichen'], ['motiviert', 'Motiviert'], ['kreativ', 'Kreativ'], ['optimistisch', 'Optimistisch'],
  ['verliebt', 'Verliebt'], ['gesellig', 'Gesellig'],
  ['sensibel', 'Sensibel'], ['gereizt', 'Gereizt'], ['traurig', 'Traurig'], ['aengstlich', 'Ängstlich'],
  ['gestresst', 'Gestresst'], ['muede', 'Müde'], ['lustlos', 'Lustlos'],
];
const SYMPTOMS = [
  ['kraempfe', 'Krämpfe'], ['kopfschmerzen', 'Kopfschmerzen'], ['brustspannen', 'Brustspannen'], ['blaehungen', 'Blähungen'],
  ['rueckenschmerzen', 'Rückenschmerzen'], ['unreine_haut', 'Unreine Haut'], ['heisshunger', 'Heißhunger'],
  ['schlafprobleme', 'Schlafprobleme'], ['uebelkeit', 'Übelkeit'],
];
// Stimmung des Tages, im Kalender als farbiger Punkt: grün gut, gelb ok, rot schlecht, lila nur abends
const STIMMUNG = [['gut', 'Gut'], ['ok', 'Ist ok'], ['schlecht', 'Schlecht'], ['abends', 'Nur abends']];
// Ohne eigene Stimmungsangabe wird der Punkt aus den Gefühlen abgeleitet
const MOOD_TONE = {
  sensibel: 'ok', muede: 'ok', lustlos: 'ok',
  gereizt: 'schlecht', traurig: 'schlecht', aengstlich: 'schlecht', gestresst: 'schlecht',
};
const ENERGY = [[0, 'Nicht erfasst'], [1, 'Sehr niedrig'], [2, 'Niedrig'], [3, 'Mittel'], [4, 'Hoch'], [5, 'Sehr hoch']];
const PHASES = [['men', 'Menstruation'], ['fol', 'Follikelphase'], ['ovu', 'Eisprungphase'], ['lut', 'Lutealphase']];
const PHASE_NAME = Object.fromEntries(PHASES);
const PHASE_SHORT = { men: 'Periode', fol: 'Follikel', ovu: 'Eisprung', lut: 'Luteal' };
const MOOD_NAME = Object.fromEntries(MOODS);
const SYM_NAME = Object.fromEntries(SYMPTOMS);
const DEFAULTS = { cycleLen: 28, periodLen: 5, luteal: 14, theme: 'auto' };

// ---------- Datum (ganze Tage als Zahl, zeitzonenfest) ----------
const DAY = 864e5;
const toNum = s => { const [y, m, d] = s.split('-').map(Number); return Date.UTC(y, m - 1, d) / DAY; };
const toStr = n => new Date(n * DAY).toISOString().slice(0, 10);
const todayNum = () => { const d = new Date(); return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / DAY; };
const fmt = (n, opts) => new Intl.DateTimeFormat('de-DE', { timeZone: 'UTC', ...opts }).format(new Date(n * DAY));
const fmtShort = n => fmt(n, { day: '2-digit', month: '2-digit' });
const fmtLong = n => fmt(n, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
const fmtMid = n => fmt(n, { weekday: 'short', day: 'numeric', month: 'long' });
const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;
const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const $ = id => document.getElementById(id);

// ---------- Speicher ----------
const Store = {
  db: null, ls: false, LSKEY: 'zyklus-tracker-v1',
  async open() {
    try {
      this.db = await new Promise((res, rej) => {
        const r = indexedDB.open('zyklus-tracker', 1);
        r.onupgradeneeded = () => {
          r.result.createObjectStore('days', { keyPath: 'date' });
          r.result.createObjectStore('meta', { keyPath: 'key' });
        };
        r.onsuccess = () => res(r.result);
        r.onerror = () => rej(r.error);
      });
    } catch (e) { this.ls = true; }
  },
  _req(r) { return new Promise((res, rej) => { r.onsuccess = () => res(r.result); r.onerror = () => rej(r.error); }); },
  _os(name, mode) { return this.db.transaction(name, mode).objectStore(name); },
  _lsGet() { try { return JSON.parse(localStorage.getItem(this.LSKEY)) || { days: {}, meta: {} }; } catch { return { days: {}, meta: {} }; } },
  _lsSet(v) { localStorage.setItem(this.LSKEY, JSON.stringify(v)); },
  async allDays() {
    if (this.ls) return Object.values(this._lsGet().days);
    return this._req(this._os('days', 'readonly').getAll());
  },
  async putDay(e) {
    if (this.ls) { const v = this._lsGet(); v.days[e.date] = e; return this._lsSet(v); }
    return this._req(this._os('days', 'readwrite').put(e));
  },
  async putDays(list) {
    if (this.ls) { const v = this._lsGet(); list.forEach(e => { v.days[e.date] = e; }); return this._lsSet(v); }
    const tx = this.db.transaction('days', 'readwrite');
    list.forEach(e => tx.objectStore('days').put(e));
    return new Promise((res, rej) => { tx.oncomplete = res; tx.onerror = () => rej(tx.error); });
  },
  async delDay(date) {
    if (this.ls) { const v = this._lsGet(); delete v.days[date]; return this._lsSet(v); }
    return this._req(this._os('days', 'readwrite').delete(date));
  },
  async clearDays() {
    if (this.ls) { const v = this._lsGet(); v.days = {}; return this._lsSet(v); }
    return this._req(this._os('days', 'readwrite').clear());
  },
  async getMeta(key) {
    if (this.ls) return this._lsGet().meta[key];
    const r = await this._req(this._os('meta', 'readonly').get(key));
    return r ? r.value : undefined;
  },
  async setMeta(key, value) {
    if (this.ls) { const v = this._lsGet(); v.meta[key] = value; return this._lsSet(v); }
    return this._req(this._os('meta', 'readwrite').put({ key, value }));
  },
};

// ---------- Zustand ----------
const state = {
  days: new Map(), settings: { ...DEFAULTS }, demo: false,
  sel: todayNum(), month: null, an: null, tab: 'heute',
};

const blank = date => ({ date, flow: 0, stimmung: [], moods: [], symptoms: [], energy: 0, note: '' });
const isEmpty = e => !e.flow && !e.stimmung.length && !e.moods.length && !e.symptoms.length && !e.energy && !e.note.trim();
const hasDetail = e => e.stimmung.length || e.moods.length || e.symptoms.length || e.energy || e.note.trim();
// Farbpunkte für den Kalender: eigene Stimmungsangabe, sonst aus den Gefühlen
function moodDots(e) {
  const set = new Set(e.stimmung.length ? e.stimmung : e.moods.map(m => MOOD_TONE[m] || 'gut'));
  return STIMMUNG.map(s => s[0]).filter(k => set.has(k));
}

function sanitize(raw) {
  if (!raw || typeof raw.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw.date) || isNaN(toNum(raw.date))) return null;
  const okMood = new Set(MOODS.map(m => m[0])), okStim = new Set(STIMMUNG.map(s => s[0])), okSym = new Set(SYMPTOMS.map(s => s[0]));
  const int = (v, lo, hi) => Math.min(hi, Math.max(lo, Math.round(Number(v) || 0)));
  return {
    date: raw.date,
    flow: int(raw.flow, 0, 4),
    stimmung: Array.isArray(raw.stimmung) ? [...new Set(raw.stimmung.filter(m => okStim.has(m)))] : [],
    moods: Array.isArray(raw.moods) ? [...new Set(raw.moods.filter(m => okMood.has(m)))] : [],
    symptoms: Array.isArray(raw.symptoms) ? [...new Set(raw.symptoms.filter(s => okSym.has(s)))] : [],
    energy: int(raw.energy, 0, 5),
    note: typeof raw.note === 'string' ? raw.note.slice(0, 2000) : '',
  };
}

// ---------- Analyse ----------
function analyze(days, settings, today) {
  const L = settings.luteal;
  const bleed = [...days.values()].filter(e => e.flow >= 2).map(e => toNum(e.date)).sort((a, b) => a - b);
  const periods = [];
  for (const n of bleed) {
    const p = periods[periods.length - 1];
    if (p && n - p.end <= 2) p.end = n; else periods.push({ start: n, end: n });
  }
  periods.forEach(p => { p.len = p.end - p.start + 1; });

  const cycles = [];
  for (let i = 0; i < periods.length - 1; i++) {
    const len = periods[i + 1].start - periods[i].start;
    cycles.push({ start: periods[i].start, len, periodLen: periods[i].len, ok: len >= 15 && len <= 60 });
  }
  const recent = cycles.filter(c => c.ok).slice(-6);
  const mean = a => a.reduce((s, v) => s + v, 0) / a.length;
  const avgCycle = recent.length ? mean(recent.map(c => c.len)) : null;
  const done = periods.filter(p => p.end < today - 1).slice(-6);
  const avgPeriod = done.length ? mean(done.map(p => p.len)) : null;
  const sd = recent.length > 1 ? Math.sqrt(mean(recent.map(c => (c.len - avgCycle) ** 2))) : null;
  const C = Math.round(avgCycle || settings.cycleLen);
  const P = Math.round(avgPeriod || settings.periodLen);

  // Phase eines Tages: echte Periodenstarts, danach Fortschreibung mit Ø-Länge
  function phaseOf(n) {
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
  return { periods, cycles, recent, avgCycle, avgPeriod, sd, C, P, L, phaseOf, current };
}

function moodStats(an, days, today) {
  const stats = {};
  PHASES.forEach(([k]) => { stats[k] = { n: 0, moods: {}, syms: {}, energy: [] }; });
  for (const e of days.values()) {
    const n = toNum(e.date);
    if (n > today || !hasDetail(e)) continue;
    const ph = an.phaseOf(n);
    if (!ph) continue;
    const s = stats[ph.phase];
    s.n++;
    e.moods.forEach(m => { s.moods[m] = (s.moods[m] || 0) + 1; });
    e.symptoms.forEach(m => { s.syms[m] = (s.syms[m] || 0) + 1; });
    if (e.energy) s.energy.push(e.energy);
  }
  return stats;
}

function findPatterns(stats) {
  const out = [];
  const scan = (key, names, verb) => {
    for (const [id, label] of names) {
      const rows = PHASES.map(([ph]) => ({ ph, n: stats[ph].n, c: stats[ph][key][id] || 0 })).filter(r => r.n >= 3);
      const total = rows.reduce((s, r) => s + r.c, 0);
      if (rows.length < 2 || total < 4) continue;
      rows.forEach(r => { r.p = r.c / r.n; });
      const top = rows.reduce((a, b) => (b.p > a.p ? b : a));
      const rest = rows.filter(r => r !== top);
      const restN = rest.reduce((s, r) => s + r.n, 0), restC = rest.reduce((s, r) => s + r.c, 0);
      const other = restN ? restC / restN : 0;
      if (top.p >= 0.25 && top.p >= other * 1.6 + 0.05) {
        out.push({ score: top.p - other, text: `<b>${label}</b> ${verb} in der <b>${PHASE_NAME[top.ph]}</b> an ${Math.round(top.p * 100)} % der Tage, in den übrigen Phasen an ${Math.round(other * 100)} %.` });
      }
    }
  };
  scan('moods', MOODS, 'trägst du');
  scan('syms', SYMPTOMS, 'notierst du');
  out.sort((a, b) => b.score - a.score);
  const en = PHASES.map(([ph]) => ({ ph, v: stats[ph].energy })).filter(r => r.v.length >= 3)
    .map(r => ({ ph: r.ph, avg: r.v.reduce((s, v) => s + v, 0) / r.v.length }));
  const res = out.slice(0, 5).map(o => o.text);
  if (en.length >= 2) {
    const hi = en.reduce((a, b) => (b.avg > a.avg ? b : a)), lo = en.reduce((a, b) => (b.avg < a.avg ? b : a));
    if (hi.avg - lo.avg >= 0.5) res.push(`Deine Energie ist in der <b>${PHASE_NAME[hi.ph]}</b> am höchsten (Ø ${hi.avg.toFixed(1).replace('.', ',')} von 5) und in der <b>${PHASE_NAME[lo.ph]}</b> am niedrigsten (Ø ${lo.avg.toFixed(1).replace('.', ',')}).`);
  }
  return res;
}

// ---------- Rendering ----------
function chip(group, type, value, label, checked, cls = '') {
  return `<label class="chip ${cls}"><input type="${type}" name="${group}" value="${value}"${checked ? ' checked' : ''}><span>${esc(label)}</span></label>`;
}

function renderDay() {
  const date = toStr(state.sel);
  const e = state.days.get(date) || blank(date);
  $('dayDate').value = date;
  $('dayTitle').textContent = fmtLong(state.sel) + (state.sel === todayNum() ? ' · heute' : '');
  $('flowChips').innerHTML = FLOW.map(([v, l]) => chip('flow', 'radio', v, l, e.flow === v, v >= 2 ? 'flow' : '')).join('');
  $('stimChips').innerHTML = STIMMUNG.map(([v, l]) => chip('stim', 'checkbox', v, l, e.stimmung.includes(v), 'stim ' + v)).join('');
  $('moodChips').innerHTML = MOODS.map(([v, l]) => chip('mood', 'checkbox', v, l, e.moods.includes(v))).join('');
  $('energyChips').innerHTML = ENERGY.map(([v, l]) => chip('energy', 'radio', v, l, e.energy === v)).join('');
  $('symChips').innerHTML = SYMPTOMS.map(([v, l]) => chip('sym', 'checkbox', v, l, e.symptoms.includes(v))).join('');
  $('note').value = e.note;
  const ph = state.an.phaseOf(state.sel);
  $('dayPhase').innerHTML = ph
    ? `<span class="tag inv">Zyklustag ${ph.cycleDay}</span><span class="tag">${PHASE_NAME[ph.phase]}${ph.predicted ? ' · Schätzung' : ''}</span>${ph.fertile ? '<span class="tag acc">Fruchtbar · Schätzung</span>' : ''}`
    : '';
}

function readForm() {
  const f = $('dayForm');
  return {
    date: toStr(state.sel),
    flow: Number((f.querySelector('input[name=flow]:checked') || {}).value || 0),
    stimmung: [...f.querySelectorAll('input[name=stim]:checked')].map(i => i.value),
    moods: [...f.querySelectorAll('input[name=mood]:checked')].map(i => i.value),
    symptoms: [...f.querySelectorAll('input[name=sym]:checked')].map(i => i.value),
    energy: Number((f.querySelector('input[name=energy]:checked') || {}).value || 0),
    note: $('note').value.slice(0, 2000),
  };
}

let saveTimer;
async function saveDay(immediate) {
  clearTimeout(saveTimer);
  const run = async () => {
    const e = readForm();
    if (isEmpty(e)) { state.days.delete(e.date); await Store.delDay(e.date); }
    else { state.days.set(e.date, e); await Store.putDay(e); }
    $('saveState').textContent = 'Gespeichert ' + new Date().toLocaleTimeString('de-DE', { hour: '2-digit', minute: '2-digit' });
    askPersist();
    recompute(false);
  };
  if (immediate) return run();
  saveTimer = setTimeout(run, 500);
}

function kpi(label, value, sub = '', cls = '') {
  return `<div class="kpi"><div class="cap">${label}</div><div class="v ${cls}">${value}</div>${sub ? `<div class="sub">${sub}</div>` : ''}</div>`;
}

function renderHero() {
  const an = state.an, t = todayNum(), c = an.current;
  $('headDate').textContent = fmt(t, { day: 'numeric', month: 'long', year: 'numeric' });
  const sep = '<span class="sep">·</span>';
  if (!c) {
    $('heroTitle').textContent = 'Zyklus';
    $('heroSub').innerHTML = `Tage${sep}Gefühle${sep}Muster`;
    $('heroLede').textContent = 'Trag den ersten Tag deiner letzten Periode ein. Ab zwei Periodenstarts siehst du Durchschnittswerte, Vorhersagen und Muster.';
    return;
  }
  const ph = an.phaseOf(t);
  $('heroTitle').textContent = `Tag ${c.day}`;
  let when;
  if (c.inPeriod) when = 'Periode läuft';
  else if (c.overdue) when = `${plural(c.overdue, 'Tag', 'Tage')} später als erwartet`;
  else if (c.next === t) when = 'Periode heute erwartet';
  else when = `Periode in ${plural(c.next - t, 'Tag', 'Tagen')}`;
  $('heroSub').innerHTML = `${ph ? PHASE_NAME[ph.phase] : 'Zyklus'}${sep}${when}${c.inPeriod ? '' : sep + 'Schätzung'}`;
  $('heroLede').textContent = an.recent.length
    ? `Berechnet aus ${plural(an.recent.length, 'Zyklus', 'Zyklen')} mit durchschnittlich ${String(an.avgCycle.toFixed(1)).replace('.', ',').replace(',0', '')} Tagen.`
    : `Noch kein vollständiger Zyklus erfasst. Bis dahin rechnet die App mit ${an.C} Tagen (Einstellung unter „Daten“).`;
}

function renderOutlook() {
  const an = state.an, c = an.current, t = todayNum();
  if (!c) { $('outlook').innerHTML = kpi('Zyklustag', '–', 'noch keine Periode eingetragen'); return; }
  const ph = an.phaseOf(t);
  const nextSub = c.overdue ? `erwartet am ${fmtShort(c.next)}, ${plural(c.overdue, 'Tag', 'Tage')} drüber` : c.next === t ? 'heute' : `in ${plural(c.next - t, 'Tag', 'Tagen')}`;
  const fertSub = c.fertileNext ? 'im nächsten Zyklus' : (t >= c.fs && t <= c.fe ? 'jetzt, Eisprung um ' + fmtShort(c.ov) : 'Eisprung um ' + fmtShort(c.ov));
  $('outlook').innerHTML =
    kpi('Zyklustag', c.day, 'seit ' + fmtShort(c.start), 'acc') +
    kpi('Phase', ph ? PHASE_NAME[ph.phase] : '–', ph && ph.predicted ? 'Schätzung' : '', 'sm') +
    kpi('Nächste Periode', c.overdue ? 'überfällig' : fmtShort(c.next), nextSub, 'sm') +
    kpi('Fruchtbares Fenster', `${fmtShort(c.fs)}–${fmtShort(c.fe)}`, fertSub, 'sm');
}

function renderCalendar() {
  const an = state.an, t = todayNum();
  const [y, m] = state.month;
  const first = Date.UTC(y, m, 1) / DAY, last = Date.UTC(y, m + 1, 0) / DAY;
  $('monthTitle').textContent = fmt(first, { month: 'long', year: 'numeric' });
  const lead = (new Date(first * DAY).getUTCDay() + 6) % 7;
  let html = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'].map(d => `<div class="wd" role="columnheader">${d}</div>`).join('');
  for (let i = 0; i < lead; i++) html += '<button class="day out" tabindex="-1" aria-hidden="true"></button>';
  for (let n = first; n <= last; n++) {
    const e = state.days.get(toStr(n));
    const ph = an.phaseOf(n);
    const cls = ['day'], marks = [], aria = [fmtLong(n)];
    if (e && e.flow >= 2) { cls.push('period'); marks.push('P'); aria.push('Periode ' + FLOW[e.flow][1]); }
    else if (e && e.flow === 1) { cls.push('spot'); marks.push('·'); aria.push('Schmierblutung'); }
    else if (ph && ph.phase === 'men' && n > t) { cls.push('pred'); marks.push('p'); aria.push('Periode erwartet'); }
    if (ph && ph.fertile && !(e && e.flow >= 2)) { cls.push('fertile'); marks.push(ph.ovu ? 'E' : 'F'); aria.push(ph.ovu ? 'Eisprung geschätzt' : 'fruchtbar geschätzt'); }
    const dots = e ? moodDots(e) : [];
    if (dots.length) aria.push('Stimmung ' + dots.map(k => STIMMUNG.find(s => s[0] === k)[1]).join(', '));
    if (e && hasDetail(e)) { marks.push('•'); aria.push('Einträge vorhanden'); }
    if (n === t) { cls.push('today'); aria.push('heute'); }
    if (n === state.sel) cls.push('sel');
    html += `<button class="${cls.join(' ')}" data-n="${n}" aria-label="${esc(aria.join(', '))}"><span>${new Date(n * DAY).getUTCDate()}</span>${dots.length ? `<span class="dots" aria-hidden="true">${dots.map(k => `<i class="dot ${k}"></i>`).join('')}</span>` : ''}<span class="marks" aria-hidden="true">${marks.join(' ')}</span></button>`;
  }
  $('cal').innerHTML = html;
}

function renderAnalysis() {
  const an = state.an, t = todayNum();
  const enough = an.periods.length >= 2;
  $('anaEmpty').hidden = enough;
  const num = v => v == null ? '–' : v.toFixed(1).replace('.', ',').replace(',0', '');
  const rng = an.recent.length ? `${Math.min(...an.recent.map(c => c.len))}–${Math.max(...an.recent.map(c => c.len))}` : '–';
  $('anaKpis').innerHTML =
    kpi('Ø Zykluslänge', num(an.avgCycle), an.avgCycle ? 'Tage, letzte ' + an.recent.length : `Standard ${an.C} Tage`, 'acc') +
    kpi('Ø Periodendauer', num(an.avgPeriod), an.avgPeriod ? 'Tage' : `Standard ${an.P} Tage`) +
    kpi('Spanne', rng, an.sd != null ? `Tage · ±${num(an.sd)} Schwankung` : 'Tage') +
    kpi('Erfasste Zyklen', an.cycles.length, plural(an.periods.length, 'Periode', 'Perioden') + ' erkannt');

  // Balken
  const cyc = an.cycles.slice(-12);
  if (!cyc.length) { $('cycleChart').innerHTML = '<p style="color:var(--muted)">Noch keine abgeschlossenen Zyklen.</p>'; $('cycleTable').innerHTML = ''; }
  else {
    const max = Math.max(40, ...cyc.map(c => c.len)) * 1.08;
    const lbl = new Set([cyc.length - 1]);
    const lens = cyc.map(c => c.len);
    lbl.add(lens.indexOf(Math.max(...lens))); lbl.add(lens.indexOf(Math.min(...lens)));
    const tipText = c => `${fmtShort(c.start)}: ${c.len} Tage · Periode ${c.periodLen} Tage${c.ok ? '' : ' · ausgeschlossen'}`;
    let h = '<div class="bars" id="bars">';
    if (an.avgCycle) h += `<div class="avg" style="bottom:${(an.avgCycle / max) * 198}px" aria-hidden="true"></div>`;
    cyc.forEach((c, i) => {
      h += `<div class="col${c.ok ? '' : ' out'}" tabindex="0" data-tip="${esc(tipText(c))}" aria-label="${esc(tipText(c))}">${lbl.has(i) ? `<span class="val">${c.len}</span>` : ''}<div class="bar" style="height:${(Math.min(c.len, max) / max) * 198}px"></div></div>`;
    });
    h += '</div><div class="xlabels" aria-hidden="true">' + cyc.map(c => `<span>${fmtShort(c.start)}</span>`).join('') + '</div>';
    $('cycleChart').innerHTML = h;
    $('chartCap').textContent = `Tage pro Zyklus · gestrichelt = Durchschnitt${an.avgCycle ? ' (' + num(an.avgCycle) + ')' : ''} · grau = ausgeschlossen (unter 15 oder über 60 Tage)`;
    $('cycleTable').innerHTML = '<table class="data"><thead><tr><th>Beginn</th><th class="num">Zyklus</th><th class="num">Periode</th><th>Status</th></tr></thead><tbody>' +
      an.cycles.slice().reverse().map(c => `<tr><td>${fmt(c.start, { day: '2-digit', month: '2-digit', year: 'numeric' })}</td><td class="num">${c.len}</td><td class="num">${c.periodLen}</td><td>${c.ok ? 'gezählt' : 'ausgeschlossen'}</td></tr>`).join('') + '</tbody></table>';
  }

  // Gefühle je Phase
  const st = moodStats(an, state.days, t);
  const anyN = PHASES.some(([k]) => st[k].n);
  if (!anyN) $('moodTable').innerHTML = '<p style="color:var(--muted)">Noch keine Gefühle in einem erkannten Zyklus eingetragen.</p>';
  else {
    const cell = (c, n) => {
      if (!n) return '<td class="cell num">–</td>';
      const p = Math.round((c / n) * 100);
      return `<td class="cell num">${p} %<span class="meter" aria-hidden="true"><i style="width:${p}%"></i></span></td>`;
    };
    const used = MOODS.filter(([id]) => PHASES.some(([k]) => st[k].moods[id]));
    let h = '<table class="data ph"><thead><tr><th>Gefühl</th>' + PHASES.map(([k]) => `<th class="num">${PHASE_SHORT[k]}</th>`).join('') + '</tr></thead><tbody>';
    h += '<tr><td class="mood">Eingetragene Tage</td>' + PHASES.map(([k]) => `<td class="num">${st[k].n}</td>`).join('') + '</tr>';
    used.forEach(([id, l]) => { h += `<tr><td class="mood">${l}</td>` + PHASES.map(([k]) => cell(st[k].moods[id] || 0, st[k].n)).join('') + '</tr>'; });
    h += '<tr><td class="mood">Ø Energie (1–5)</td>' + PHASES.map(([k]) => {
      const v = st[k].energy; return `<td class="num">${v.length ? (v.reduce((s, x) => s + x, 0) / v.length).toFixed(1).replace('.', ',') : '–'}</td>`;
    }).join('') + '</tr>';
    const topSym = k => { const e = Object.entries(st[k].syms).sort((a, b) => b[1] - a[1])[0]; return e ? `${SYM_NAME[e[0]]} (${Math.round(e[1] / st[k].n * 100)} %)` : '–'; };
    h += '<tr><td class="mood">Häufigstes Körpersymptom</td>' + PHASES.map(([k]) => `<td>${st[k].n ? topSym(k) : '–'}</td>`).join('') + '</tr>';
    $('moodTable').innerHTML = h + '</tbody></table>';
  }
  const pats = enough ? findPatterns(st) : [];
  $('insights').innerHTML = pats.length
    ? pats.map((p, i) => `<div class="row${i < 2 ? ' prio' : ''}"><span>${p}</span></div>`).join('') + '<div class="note info"><span class="cap">Einordnung</span>Muster sind einfache Häufigkeiten aus deinen Einträgen. Je mehr Tage du erfasst, desto belastbarer werden sie.</div>'
    : '<div class="row"><span>Noch keine deutlichen Muster. Sie erscheinen, sobald in mindestens zwei Phasen je drei Tage mit Gefühlen erfasst sind.</span></div>';
}

async function renderData() {
  const n = state.days.size;
  let info = `<b>${plural(n, 'Tag', 'Tage')}</b> gespeichert · ${Store.ls ? 'localStorage' : 'IndexedDB'}`;
  if (navigator.storage && navigator.storage.persisted) {
    try { info += (await navigator.storage.persisted()) ? ' · dauerhaft geschützt' : ' · Browser darf bei Speichermangel aufräumen'; } catch { /* egal */ }
  }
  $('storeInfo').innerHTML = info;
  const s = state.settings;
  $('setCycle').value = s.cycleLen; $('setPeriod').value = s.periodLen; $('setLuteal').value = s.luteal; $('setTheme').value = s.theme;
  $('demoNote').hidden = !state.demo;
}

function recompute(full = true) {
  state.an = analyze(state.days, state.settings, todayNum());
  renderHero(); renderOutlook();
  if (full) renderDay();
  else { // nur Phase-Tags des Tages aktualisieren, Formular nicht neu zeichnen (Fokus bleibt)
    const ph = state.an.phaseOf(state.sel);
    $('dayPhase').innerHTML = ph ? `<span class="tag inv">Zyklustag ${ph.cycleDay}</span><span class="tag">${PHASE_NAME[ph.phase]}${ph.predicted ? ' · Schätzung' : ''}</span>${ph.fertile ? '<span class="tag acc">Fruchtbar · Schätzung</span>' : ''}` : '';
  }
  if (state.tab === 'kal') renderCalendar();
  if (state.tab === 'ana') renderAnalysis();
  if (state.tab === 'daten') renderData();
}

// ---------- Tabs ----------
function showTab(name, focus) {
  document.querySelectorAll('[role=tab]').forEach(tab => {
    const on = tab.id === 'tab-' + name;
    tab.setAttribute('aria-selected', on); tab.tabIndex = on ? 0 : -1;
    $(tab.getAttribute('aria-controls')).hidden = !on;
    if (on && focus) tab.focus();
  });
  state.tab = name;
  try { localStorage.setItem('zyklus-tab', name); } catch { /* egal */ }
  if (name === 'kal') renderCalendar();
  if (name === 'ana') renderAnalysis();
  if (name === 'daten') renderData();
}

// ---------- Theme ----------
const THEME_LABEL = { auto: 'System', light: 'Hell', dark: 'Dunkel' };
const THEME_NEXT = { auto: 'dark', dark: 'light', light: 'auto' };
function applyTheme() {
  const t = state.settings.theme;
  if (t === 'auto') delete document.documentElement.dataset.theme; else document.documentElement.dataset.theme = t;
  try { localStorage.setItem('zyklus-theme', t); } catch { /* egal */ }
  // Statusleiste am Handy passend einfärben
  const forced = { light: '#E3DAD3', dark: '#1D1916' }[t];
  $('tcLight').content = forced || '#E3DAD3';
  $('tcDark').content = forced || '#1D1916';
  $('themeBtn').textContent = 'Farbe: ' + THEME_LABEL[t];
  $('themeBtn').setAttribute('aria-label', `Farbschema: ${THEME_LABEL[t]}. Wechseln zu ${THEME_LABEL[THEME_NEXT[t]]}`);
  $('setTheme').value = t;
}

// ---------- Persistenz-Wunsch ----------
let persistAsked = false;
function askPersist() {
  if (persistAsked || !navigator.storage || !navigator.storage.persist) return;
  persistAsked = true;
  navigator.storage.persist().catch(() => {});
}

// ---------- Demodaten (erfunden) ----------
function makeDemo(today) {
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

// ---------- Export / Import ----------
function exportData() {
  const data = { app: 'zyklus-tracker', version: 1, exportedAt: new Date().toISOString(), settings: state.settings, days: [...state.days.values()].sort((a, b) => a.date.localeCompare(b.date)) };
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `zyklus-backup-${toStr(todayNum())}.json`;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}

async function importData(file) {
  let data;
  try { data = JSON.parse(await file.text()); } catch { alert('Die Datei ist kein gültiges JSON.'); return; }
  const list = (Array.isArray(data) ? data : data && data.days || []).map(sanitize).filter(Boolean);
  if (!list.length) { alert('In der Datei wurden keine Einträge gefunden.'); return; }
  if (!confirm(`${plural(list.length, 'Eintrag', 'Einträge')} importieren? Einträge an gleichen Tagen werden überschrieben.`)) return;
  await Store.putDays(list);
  list.forEach(e => state.days.set(e.date, e));
  if (data.settings) { await saveSettings(data.settings); }
  recompute(); renderData();
  alert('Import abgeschlossen.');
}

async function saveSettings(s) {
  const clamp = (v, lo, hi, d) => { v = Math.round(Number(v)); return isNaN(v) ? d : Math.min(hi, Math.max(lo, v)); };
  state.settings = {
    cycleLen: clamp(s.cycleLen, 15, 60, DEFAULTS.cycleLen),
    periodLen: clamp(s.periodLen, 1, 12, DEFAULTS.periodLen),
    luteal: clamp(s.luteal, 8, 18, DEFAULTS.luteal),
    theme: ['auto', 'light', 'dark'].includes(s.theme) ? s.theme : 'auto',
  };
  await Store.setMeta('settings', state.settings);
  applyTheme();
}

// ---------- Ereignisse ----------
function bind() {
  $('dayForm').addEventListener('change', e => saveDay(e.target.type !== 'textarea'));
  $('note').addEventListener('input', () => { $('saveState').textContent = 'Wird gespeichert …'; saveDay(false); });
  $('note').addEventListener('blur', () => saveDay(true));
  const go = async n => { await saveDay(true); state.sel = n; renderDay(); };
  $('prevDay').onclick = () => go(state.sel - 1);
  $('nextDay').onclick = () => go(state.sel + 1);
  $('todayBtn').onclick = () => go(todayNum());
  $('dayDate').addEventListener('change', e => { if (e.target.value) go(toNum(e.target.value)); });
  $('clearDay').onclick = async () => {
    if (!state.days.has(toStr(state.sel))) return;
    if (!confirm('Alle Angaben für diesen Tag löschen?')) return;
    state.days.delete(toStr(state.sel)); await Store.delDay(toStr(state.sel));
    $('saveState').textContent = 'Tag geleert'; recompute();
  };

  const tabs = [...document.querySelectorAll('[role=tab]')];
  tabs.forEach((tab, i) => {
    tab.addEventListener('click', () => showTab(tab.id.slice(4)));
    tab.addEventListener('keydown', e => {
      const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (!d) return;
      e.preventDefault();
      showTab(tabs[(i + d + tabs.length) % tabs.length].id.slice(4), true);
    });
  });

  $('prevMonth').onclick = () => { const [y, m] = state.month; state.month = m ? [y, m - 1] : [y - 1, 11]; renderCalendar(); };
  $('nextMonth').onclick = () => { const [y, m] = state.month; state.month = m === 11 ? [y + 1, 0] : [y, m + 1]; renderCalendar(); };
  $('cal').addEventListener('click', e => {
    const b = e.target.closest('button.day[data-n]');
    if (!b) return;
    state.sel = Number(b.dataset.n); renderDay(); showTab('heute');
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });

  // Tooltip für Balken
  const tip = $('tip');
  const showTip = el => { const r = el.getBoundingClientRect(); tip.textContent = el.dataset.tip; tip.hidden = false; tip.style.left = (r.left + r.width / 2 + scrollX) + 'px'; tip.style.top = (r.top + scrollY + el.offsetHeight - el.querySelector('.bar').offsetHeight - 8) + 'px'; const tr = tip.getBoundingClientRect(); if (tr.left < 8) tip.style.left = (parseFloat(tip.style.left) + 8 - tr.left) + 'px'; if (tr.right > innerWidth - 8) tip.style.left = (parseFloat(tip.style.left) - (tr.right - innerWidth + 8)) + 'px'; };
  const hideTip = () => { tip.hidden = true; };
  $('cycleChart').addEventListener('pointerover', e => { const c = e.target.closest('.col'); if (c) showTip(c); });
  $('cycleChart').addEventListener('pointerout', e => { if (e.target.closest('.col')) hideTip(); });
  $('cycleChart').addEventListener('focusin', e => { const c = e.target.closest('.col'); if (c) showTip(c); });
  $('cycleChart').addEventListener('focusout', hideTip);

  $('themeBtn').onclick = async () => {
    await saveSettings({ ...state.settings, theme: THEME_NEXT[state.settings.theme] });
  };
  $('exportBtn').onclick = exportData;
  $('importBtn').onclick = () => $('importFile').click();
  $('importFile').onchange = e => { const f = e.target.files[0]; e.target.value = ''; if (f) importData(f); };
  ['setCycle', 'setPeriod', 'setLuteal', 'setTheme'].forEach(id => $(id).addEventListener('change', async () => {
    await saveSettings({ cycleLen: $('setCycle').value, periodLen: $('setPeriod').value, luteal: $('setLuteal').value, theme: $('setTheme').value });
    recompute(); renderData();
  }));
  $('demoBtn').onclick = async () => {
    if (state.days.size && !confirm('Demodaten ersetzen alle vorhandenen Einträge. Vorher am besten ein Backup exportieren. Fortfahren?')) return;
    await Store.clearDays(); state.days.clear();
    const list = makeDemo(todayNum());
    await Store.putDays(list); list.forEach(e => state.days.set(e.date, e));
    state.demo = true; await Store.setMeta('demo', true);
    recompute(); renderData();
  };
  $('wipeBtn').onclick = async () => {
    if (!confirm('Wirklich alle Einträge auf diesem Gerät löschen? Das lässt sich nicht rückgängig machen.')) return;
    await Store.clearDays(); state.days.clear();
    state.demo = false; await Store.setMeta('demo', false);
    recompute(); renderData();
  };

  let deferred;
  window.addEventListener('beforeinstallprompt', e => { e.preventDefault(); deferred = e; $('installBtn').hidden = false; });
  $('installBtn').onclick = async () => { if (!deferred) return; deferred.prompt(); await deferred.userChoice; deferred = null; $('installBtn').hidden = true; };

  // Mitternacht / Rückkehr in die App: "heute" neu berechnen
  document.addEventListener('visibilitychange', () => { if (!document.hidden) recompute(false); });
}

// ---------- Start ----------
(async function init() {
  await Store.open();
  const [list, settings, demo] = await Promise.all([Store.allDays(), Store.getMeta('settings'), Store.getMeta('demo')]);
  list.map(sanitize).filter(Boolean).forEach(e => state.days.set(e.date, e));
  state.settings = { ...DEFAULTS, ...(settings || {}) };
  state.demo = !!demo;
  applyTheme();
  const d = new Date(); state.month = [d.getFullYear(), d.getMonth()];
  bind();
  recompute();
  $('demoNote').hidden = !state.demo;
  let tab = 'heute';
  try { tab = localStorage.getItem('zyklus-tab') || 'heute'; } catch { /* egal */ }
  showTab(['heute', 'kal', 'ana', 'daten'].includes(tab) ? tab : 'heute');
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    // Neue Version übernommen → einmal neu laden, damit alle Dateien zusammenpassen
    const hadController = !!navigator.serviceWorker.controller;
    let reloaded = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => { if (hadController && !reloaded) { reloaded = true; location.reload(); } });
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
})();
