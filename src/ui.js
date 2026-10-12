/* Oberfläche: Zustand der Ansicht, Formatierung, Rendering. Ruft Logik und Speicher auf, nie umgekehrt. */

import { toStr, blank, hasDetail, DAY_MS, FLOW, FLOW_PERIOD, MOODS, SYMPTOMS, STIMMUNG, ENERGY, PHASES, DEFAULTS, NOTE_MAX } from './model.js';
import { analyze, phaseOf, moodDots, moodStats, findPatterns, avgEnergy, topSymptom } from './logic.js';
import { Store } from './storage.js';
import { FLOW_LABEL, MOOD_LABEL, SYMPTOM_LABEL, STIMMUNG_LABEL, ENERGY_LABEL, PHASE_NAME, PHASE_SHORT, THEME_LABEL } from './texts.js';

// ---------- Zeit und Formatierung ----------
/** Heute als Tagnummer in lokaler Zeit. Einzige Stelle, die die aktuelle Uhrzeit liest. */
export const todayNum = () => { const d = new Date(); return Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / DAY_MS; };
export const fmt = (n, opts) => new Intl.DateTimeFormat('de-DE', { timeZone: 'UTC', ...opts }).format(new Date(n * DAY_MS));
export const fmtShort = n => fmt(n, { day: '2-digit', month: '2-digit' });
export const fmtLong = n => fmt(n, { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' });
export const plural = (n, one, many) => `${n} ${n === 1 ? one : many}`;
const dec1 = v => v.toFixed(1).replace('.', ',');
export const esc = s => String(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export const $ = id => document.getElementById(id);

// ---------- Zustand der Ansicht ----------
export const state = {
  days: new Map(), settings: { ...DEFAULTS }, demo: false,
  sel: todayNum(), month: null, an: null, tab: 'heute',
};
export const entries = () => [...state.days.values()];

// ---------- Bausteine ----------
function chip(group, type, value, label, checked, cls = '') {
  return `<label class="chip ${cls}"><input type="${type}" name="${group}" value="${value}"${checked ? ' checked' : ''}><span>${esc(label)}</span></label>`;
}

function kpi(label, value, sub = '', cls = '') {
  return `<div class="kpi"><div class="cap">${label}</div><div class="v ${cls}">${value}</div>${sub ? `<div class="sub">${sub}</div>` : ''}</div>`;
}

function phaseTags(ph) {
  return ph
    ? `<span class="tag inv">Zyklustag ${ph.cycleDay}</span><span class="tag">${PHASE_NAME[ph.phase]}${ph.predicted ? ' · Schätzung' : ''}</span>${ph.fertile ? '<span class="tag acc">Fruchtbar · Schätzung</span>' : ''}`
    : '';
}

/** Formuliert ein Muster aus logic.findPatterns als Satz (mit <b>-Hervorhebung). */
export function patternText(p) {
  if (p.kind === 'energy') {
    return `Deine Energie ist in der <b>${PHASE_NAME[p.high.phase]}</b> am höchsten (Ø ${dec1(p.high.avg)} von 5) und in der <b>${PHASE_NAME[p.low.phase]}</b> am niedrigsten (Ø ${dec1(p.low.avg)}).`;
  }
  const label = p.kind === 'mood' ? MOOD_LABEL[p.id] : SYMPTOM_LABEL[p.id];
  const verb = p.kind === 'mood' ? 'trägst du' : 'notierst du';
  return `<b>${label}</b> ${verb} in der <b>${PHASE_NAME[p.phase]}</b> an ${Math.round(p.share * 100)} % der Tage, in den übrigen Phasen an ${Math.round(p.otherShare * 100)} %.`;
}

// ---------- Eintrag ----------
export function renderDay() {
  const date = toStr(state.sel);
  const e = state.days.get(date) || blank(date);
  $('dayDate').value = date;
  $('dayTitle').textContent = fmtLong(state.sel) + (state.sel === todayNum() ? ' · heute' : '');
  $('flowChips').innerHTML = FLOW.map(v => chip('flow', 'radio', v, FLOW_LABEL[v], e.flow === v, v >= FLOW_PERIOD ? 'flow' : '')).join('');
  $('stimChips').innerHTML = STIMMUNG.map(v => chip('stim', 'checkbox', v, STIMMUNG_LABEL[v], e.stimmung.includes(v), 'stim ' + v)).join('');
  $('moodChips').innerHTML = MOODS.map(v => chip('mood', 'checkbox', v, MOOD_LABEL[v], e.moods.includes(v))).join('');
  $('energyChips').innerHTML = ENERGY.map(v => chip('energy', 'radio', v, ENERGY_LABEL[v], e.energy === v)).join('');
  $('symChips').innerHTML = SYMPTOMS.map(v => chip('sym', 'checkbox', v, SYMPTOM_LABEL[v], e.symptoms.includes(v))).join('');
  $('note').value = e.note;
  renderDayPhase();
}

export function renderDayPhase() {
  $('dayPhase').innerHTML = phaseTags(phaseOf(state.an, state.sel));
}

export function readForm() {
  const f = $('dayForm');
  return {
    date: toStr(state.sel),
    flow: Number((f.querySelector('input[name=flow]:checked') || {}).value || 0),
    stimmung: [...f.querySelectorAll('input[name=stim]:checked')].map(i => i.value),
    moods: [...f.querySelectorAll('input[name=mood]:checked')].map(i => i.value),
    symptoms: [...f.querySelectorAll('input[name=sym]:checked')].map(i => i.value),
    energy: Number((f.querySelector('input[name=energy]:checked') || {}).value || 0),
    note: $('note').value.slice(0, NOTE_MAX),
  };
}

// ---------- Kopf und Ausblick ----------
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
  const ph = phaseOf(an, t);
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
  const ph = phaseOf(an, t);
  const nextSub = c.overdue ? `erwartet am ${fmtShort(c.next)}, ${plural(c.overdue, 'Tag', 'Tage')} drüber` : c.next === t ? 'heute' : `in ${plural(c.next - t, 'Tag', 'Tagen')}`;
  const fertSub = c.fertileNext ? 'im nächsten Zyklus' : (t >= c.fs && t <= c.fe ? 'jetzt, Eisprung um ' + fmtShort(c.ov) : 'Eisprung um ' + fmtShort(c.ov));
  $('outlook').innerHTML =
    kpi('Zyklustag', c.day, 'seit ' + fmtShort(c.start), 'acc') +
    kpi('Phase', ph ? PHASE_NAME[ph.phase] : '–', ph && ph.predicted ? 'Schätzung' : '', 'sm') +
    kpi('Nächste Periode', c.overdue ? 'überfällig' : fmtShort(c.next), nextSub, 'sm') +
    kpi('Fruchtbares Fenster', `${fmtShort(c.fs)}–${fmtShort(c.fe)}`, fertSub, 'sm');
}

// ---------- Kalender ----------
export function renderCalendar() {
  const an = state.an, t = todayNum();
  const [y, m] = state.month;
  const first = Date.UTC(y, m, 1) / DAY_MS, last = Date.UTC(y, m + 1, 0) / DAY_MS;
  $('monthTitle').textContent = fmt(first, { month: 'long', year: 'numeric' });
  const lead = (new Date(first * DAY_MS).getUTCDay() + 6) % 7;
  let html = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'].map(d => `<div class="wd" role="columnheader">${d}</div>`).join('');
  for (let i = 0; i < lead; i++) html += '<button class="day out" tabindex="-1" aria-hidden="true"></button>';
  for (let n = first; n <= last; n++) {
    const e = state.days.get(toStr(n));
    const ph = phaseOf(an, n);
    const cls = ['day'], marks = [], aria = [fmtLong(n)];
    if (e && e.flow >= FLOW_PERIOD) { cls.push('period'); marks.push('P'); aria.push('Periode ' + FLOW_LABEL[e.flow]); }
    else if (e && e.flow === 1) { cls.push('spot'); marks.push('·'); aria.push('Schmierblutung'); }
    else if (ph && ph.phase === 'men' && n > t) { cls.push('pred'); marks.push('p'); aria.push('Periode erwartet'); }
    if (ph && ph.fertile && !(e && e.flow >= FLOW_PERIOD)) { cls.push('fertile'); marks.push(ph.ovu ? 'E' : 'F'); aria.push(ph.ovu ? 'Eisprung geschätzt' : 'fruchtbar geschätzt'); }
    const dots = e ? moodDots(e) : [];
    if (dots.length) aria.push('Stimmung ' + dots.map(k => STIMMUNG_LABEL[k]).join(', '));
    if (e && hasDetail(e)) { marks.push('•'); aria.push('Einträge vorhanden'); }
    if (n === t) { cls.push('today'); aria.push('heute'); }
    if (n === state.sel) cls.push('sel');
    html += `<button class="${cls.join(' ')}" data-n="${n}" aria-label="${esc(aria.join(', '))}"><span>${new Date(n * DAY_MS).getUTCDate()}</span>${dots.length ? `<span class="dots" aria-hidden="true">${dots.map(k => `<i class="dot ${k}"></i>`).join('')}</span>` : ''}<span class="marks" aria-hidden="true">${marks.join(' ')}</span></button>`;
  }
  $('cal').innerHTML = html;
}

// ---------- Analyse ----------
export function renderAnalysis() {
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
  const st = moodStats(an, entries(), t);
  const anyN = PHASES.some(k => st[k].n);
  if (!anyN) $('moodTable').innerHTML = '<p style="color:var(--muted)">Noch keine Gefühle in einem erkannten Zyklus eingetragen.</p>';
  else {
    const cell = (c, n) => {
      if (!n) return '<td class="cell num">–</td>';
      const p = Math.round((c / n) * 100);
      return `<td class="cell num">${p} %<span class="meter" aria-hidden="true"><i style="width:${p}%"></i></span></td>`;
    };
    const used = MOODS.filter(id => PHASES.some(k => st[k].moods[id]));
    let h = '<table class="data ph"><thead><tr><th>Gefühl</th>' + PHASES.map(k => `<th class="num">${PHASE_SHORT[k]}</th>`).join('') + '</tr></thead><tbody>';
    h += '<tr><td class="mood">Eingetragene Tage</td>' + PHASES.map(k => `<td class="num">${st[k].n}</td>`).join('') + '</tr>';
    used.forEach(id => { h += `<tr><td class="mood">${MOOD_LABEL[id]}</td>` + PHASES.map(k => cell(st[k].moods[id] || 0, st[k].n)).join('') + '</tr>'; });
    h += '<tr><td class="mood">Ø Energie (1–5)</td>' + PHASES.map(k => {
      const v = avgEnergy(st[k].energy); return `<td class="num">${v == null ? '–' : dec1(v)}</td>`;
    }).join('') + '</tr>';
    const topSym = k => { const s = topSymptom(st[k]); return s ? `${SYMPTOM_LABEL[s.id]} (${Math.round(s.share * 100)} %)` : '–'; };
    h += '<tr><td class="mood">Häufigstes Körpersymptom</td>' + PHASES.map(k => `<td>${st[k].n ? topSym(k) : '–'}</td>`).join('') + '</tr>';
    $('moodTable').innerHTML = h + '</tbody></table>';
  }
  const pats = enough ? findPatterns(st).map(patternText) : [];
  $('insights').innerHTML = pats.length
    ? pats.map((p, i) => `<div class="row${i < 2 ? ' prio' : ''}"><span>${p}</span></div>`).join('') + '<div class="note info"><span class="cap">Einordnung</span>Muster sind einfache Häufigkeiten aus deinen Einträgen. Je mehr Tage du erfasst, desto belastbarer werden sie.</div>'
    : '<div class="row"><span>Noch keine deutlichen Muster. Sie erscheinen, sobald in mindestens zwei Phasen je drei Tage mit Gefühlen erfasst sind.</span></div>';
}

// ---------- Daten ----------
export async function renderData() {
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

// ---------- Neu berechnen ----------
export function recompute(full = true) {
  state.an = analyze(entries(), state.settings, todayNum());
  renderHero(); renderOutlook();
  if (full) renderDay();
  else renderDayPhase(); // Formular nicht neu zeichnen (Fokus bleibt)
  if (state.tab === 'kal') renderCalendar();
  if (state.tab === 'ana') renderAnalysis();
  if (state.tab === 'daten') renderData();
}

// ---------- Tabs ----------
export function showTab(name, focus) {
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
export const THEME_NEXT = { auto: 'dark', dark: 'light', light: 'auto' };
export function applyTheme() {
  const t = state.settings.theme;
  if (t === 'auto') delete document.documentElement.dataset.theme; else document.documentElement.dataset.theme = t;
  try { localStorage.setItem('zyklus-theme', t); } catch { /* egal */ }
  // Statusleiste am Handy passend einfärben
  const forced = { light: '#DCE2D6', dark: '#151A16' }[t];
  $('tcLight').content = forced || '#DCE2D6';
  $('tcDark').content = forced || '#151A16';
  $('themeBtn').textContent = 'Farbe: ' + THEME_LABEL[t];
  $('themeBtn').setAttribute('aria-label', `Farbschema: ${THEME_LABEL[t]}. Wechseln zu ${THEME_LABEL[THEME_NEXT[t]]}`);
  $('setTheme').value = t;
}

