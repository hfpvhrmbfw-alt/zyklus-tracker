/* Oberfläche: Zustand der Ansicht, Formatierung, Rendering. Ruft Logik und Speicher auf, nie umgekehrt. */

import { toNum, toStr, blank, hasDetail, DAY_MS, FLOW, FLOW_PERIOD, MOODS, SYMPTOMS, STIMMUNG, ENERGY, PHASES, DEFAULTS, NOTE_MAX } from './model.js';
import { analyze, phaseOf, moodDots, moodStats, findPatterns, avgEnergy, topSymptom, backupDue } from './logic.js';
import { Store } from './storage.js';
import { FLOW_LABEL, MOOD_LABEL, SYMPTOM_LABEL, STIMMUNG_LABEL, ENERGY_LABEL, PHASE_NAME, PHASE_SHORT, THEME_LABEL, WEEKDAY_SHORT, TAB_TITLE, greeting } from './texts.js';
import { MOOD_ICON, EMPTY_ICON, CARD_ART, ICON, scene } from './art.js';

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
  sel: todayNum(), month: null, an: null, tab: 'heute', lastTab: 'heute',
  lastBackup: null, backupSnooze: null, // Tagnummern oder null
  anaStats: null, anaPhase: null, // Analyse: Werte je Phase, gewählte Phase
};
export const entries = () => [...state.days.values()];

// ---------- Bausteine ----------
function chip(group, type, value, label, checked, cls = '') {
  return `<label class="chip ${cls}"><input type="${type}" name="${group}" value="${value}"${checked ? ' checked' : ''}><span>${esc(label)}</span></label>`;
}

function kpi(label, value, sub = '', cls = '', art = '') {
  return `<div class="tile"><div class="tl">${label}</div><div class="v ${cls}">${value}</div>${sub ? `<div class="sub">${sub}</div>` : ''}${art ? `<div class="art">${CARD_ART[art]}</div>` : ''}</div>`;
}

function phaseTags(ph) {
  return ph
    ? `<span class="tag inv">Zyklustag ${ph.cycleDay}</span><span class="tag">${PHASE_NAME[ph.phase]}${ph.predicted ? ' · Schätzung' : ''}</span>${ph.fertile ? '<span class="tag acc">Fruchtbar · Schätzung</span>' : ''}`
    : '';
}

/**
 * Leerzustand: Bild, Überschrift, kurzer Text und ein Knopf.
 * `go` sagt main.js, wohin der Knopf führt (today = Tag eintragen, kal = Kalender).
 */
function emptyCard({ art, title, text, btn, go }) {
  return `<div class="card empty"><div class="empty-art">${art}</div><h3>${title}</h3><p>${text}</p>` +
    (btn ? `<button type="button" class="pill" data-go="${go}">${btn} <span aria-hidden="true">→</span></button>` : '') + '</div>';
}
const EMPTY_LINE = text => `<p class="empty-line">${EMPTY_ICON}<span>${text}</span></p>`;

/** Formuliert ein Muster aus logic.findPatterns als Satz (mit <b>-Hervorhebung). */
export function patternText(p) {
  if (p.kind === 'energy') {
    return `Deine <b>Energie</b> ist in der <b>${PHASE_NAME[p.high.phase]}</b> am höchsten (Ø ${dec1(p.high.avg)} von 5), in der <b>${PHASE_NAME[p.low.phase]}</b> am niedrigsten (Ø ${dec1(p.low.avg)}).`;
  }
  const label = p.kind === 'mood' ? MOOD_LABEL[p.id] : SYMPTOM_LABEL[p.id];
  const verb = p.kind === 'mood' ? 'fühlst du dich' : 'hast du';
  return `<b>${label}</b> ${verb} vor allem in der <b>${PHASE_NAME[p.phase]}</b>, an ${Math.round(p.share * 100)} % der Tage.`;
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
/** Überschrift oben: Begrüßung nach Tageszeit nur auf der Startseite, sonst der Name der Seite. */
function renderHead() {
  $('greet').textContent = state.tab === 'heute' ? greeting(new Date().getHours()) : TAB_TITLE[state.tab];
  $('headDate').textContent = fmt(todayNum(), { weekday: 'long', day: 'numeric', month: 'long' });
}

function renderHero() {
  const an = state.an, t = todayNum(), c = an.current;
  renderHead();
  const sep = '<span class="sep">·</span>';
  if (!c) {
    $('heroArt').innerHTML = scene('none');
    $('heroTitle').textContent = 'Schön, dass du da bist';
    $('heroSub').innerHTML = `Tage${sep}Gefühle${sep}Muster`;
    $('heroLede').textContent = 'Trag den ersten Tag deiner letzten Periode ein. Ab zwei Periodenstarts siehst du Durchschnittswerte, Vorhersagen und Muster.';
    return;
  }
  const ph = phaseOf(an, t);
  $('heroArt').innerHTML = scene(ph ? ph.phase : 'none');
  $('heroTitle').textContent = `Tag ${c.day}`;
  let when;
  if (c.inPeriod) when = 'Periode läuft';
  else if (c.overdue) when = `${plural(c.overdue, 'Tag', 'Tage')} später als erwartet`;
  else if (c.next === t) when = 'Periode heute erwartet';
  else when = `Periode in ${plural(c.next - t, 'Tag', 'Tagen')}`;
  $('heroSub').innerHTML = `${ph ? PHASE_NAME[ph.phase] : 'Zyklus'}${sep}${when}${c.inPeriod ? '' : sep + 'Schätzung'}`;
  $('heroLede').textContent = an.recent.length
    ? `Berechnet aus ${plural(an.recent.length, 'Zyklus', 'Zyklen')} mit durchschnittlich ${String(an.avgCycle.toFixed(1)).replace('.', ',').replace(',0', '')} Tagen.`
    : `Noch kein vollständiger Zyklus erfasst. Bis dahin rechnet die App mit ${an.C} Tagen (änderbar in den Einstellungen).`;
}

function renderOutlook() {
  const an = state.an, c = an.current, t = todayNum();
  if (!c) { $('outlook').innerHTML = kpi('Zyklustag', '–', 'noch keine Periode eingetragen', 'big', 'moon') + kpi('Nächste Periode', '–', 'ab dem ersten Eintrag', '', 'drop'); return; }
  const ph = phaseOf(an, t);
  const nextSub = c.overdue ? `erwartet am ${fmtShort(c.next)}, ${plural(c.overdue, 'Tag', 'Tage')} drüber` : c.next === t ? 'heute' : `in ${plural(c.next - t, 'Tag', 'Tagen')}`;
  const fertSub = c.fertileNext ? 'im nächsten Zyklus' : (t >= c.fs && t <= c.fe ? 'jetzt, Eisprung um ' + fmtShort(c.ov) : 'Eisprung um ' + fmtShort(c.ov));
  $('outlook').innerHTML =
    kpi('Zyklustag', c.day, 'seit ' + fmtShort(c.start), 'big', 'moon') +
    kpi('Phase', ph ? PHASE_NAME[ph.phase] : '–', ph && ph.predicted ? 'Schätzung' : '', 'sm', 'leaf') +
    kpi('Nächste Periode', c.overdue ? 'überfällig' : fmtShort(c.next), nextSub, '', 'drop') +
    kpi('Fruchtbar', `${fmtShort(c.fs)}–${fmtShort(c.fe)}`, fertSub, 'sm', 'flower');
}

// ---------- Stimmungswoche ----------
/** Woche (Mo–So) mit heute: Sonne, Wolke, Regen oder Mond je nach Stimmung des Tages. */
export function renderWeek() {
  const t = todayNum();
  const mon = t - (new Date(t * DAY_MS).getUTCDay() + 6) % 7;
  let html = '';
  for (let i = 0; i < 7; i++) {
    const n = mon + i, e = state.days.get(toStr(n));
    const dots = e ? moodDots(e) : [];
    const cls = ['wday'];
    if (n === t) cls.push('today');
    if (n > t) cls.push('future');
    const icon = dots.length ? MOOD_ICON[dots[0]] : n <= t ? EMPTY_ICON : '<svg aria-hidden="true"></svg>';
    const aria = fmtLong(n) + (n === t ? ', heute' : '') + (dots.length ? ', Stimmung ' + dots.map(k => STIMMUNG_LABEL[k]).join(', ') : '');
    html += `<button type="button" class="${cls.join(' ')}" data-n="${n}" aria-label="${esc(aria)}"><span class="wl" aria-hidden="true">${WEEKDAY_SHORT[i]}</span><span class="wn" aria-hidden="true">${new Date(n * DAY_MS).getUTCDate()}</span>${icon}<span class="wdots" aria-hidden="true">${dots.length > 1 ? dots.map(k => `<i class="dot ${k}"></i>`).join('') : ''}</span></button>`;
  }
  $('moodWeek').innerHTML = html;
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
  const none = !state.days.size;
  $('kalEmpty').hidden = !none;
  $('kalEmpty').innerHTML = none ? emptyCard({
    art: CARD_ART.drop, title: 'Dein Kalender ist noch leer',
    text: 'Tipp auf einen Tag, um Blutung, Stimmung und mehr einzutragen. Vergangene Perioden kannst du so auch nachtragen.',
    btn: 'Heute eintragen', go: 'today',
  }) : '';
}

// ---------- Analyse ----------
const num = v => v == null ? '–' : v.toFixed(1).replace('.', ',').replace(',0', '');
/** Wie regelmäßig, in Worten statt „±1,3 Tage“ (Schwankung = Standardabweichung der letzten Zyklen). */
const regularity = sd => sd <= 2 ? 'sehr regelmäßig' : sd <= 4 ? 'recht regelmäßig' : 'eher unregelmäßig';
const PHASE_ART = { men: 'drop', fol: 'leaf', ovu: 'flower', lut: 'autumn' };
const reduceMotion = () => matchMedia('(prefers-reduced-motion: reduce)').matches;

/** Zahl weich von „from“ auf ihren Endwert zählen (wie in Porto). Ohne Bewegung: sofort der Endwert. */
function countUp(el, from, ms = 700) {
  const to = +el.dataset.to, dec = +(el.dataset.dec || 0), final = el.textContent;
  if (reduceMotion() || !isFinite(to)) return;
  const t0 = performance.now();
  const step = now => {
    const p = Math.min(1, (now - t0) / ms), v = from + (to - from) * (1 - (1 - p) ** 3);
    el.textContent = p < 1 ? v.toFixed(dec).replace('.', ',') : final;
    if (p < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

export function renderAnalysis() {
  const an = state.an, t = todayNum();
  const enough = an.periods.length >= 2;
  // Zu wenig Daten: ein Leerzustand statt lauter Striche
  $('anaEmpty').hidden = enough;
  $('anaBody').hidden = !enough;
  if (!enough) {
    $('anaEmpty').innerHTML = an.periods.length
      ? emptyCard({
        art: scene('fol'), title: 'Fast geschafft',
        text: `Ein Periodenstart ist da (${fmtShort(an.periods[0].start)}). Sobald die nächste Periode beginnt, siehst du hier deine Zykluslänge und erste Muster. Frühere Perioden kannst du im Kalender nachtragen.`,
        btn: 'Im Kalender nachtragen', go: 'kal',
      })
      : emptyCard({
        art: scene('none'), title: 'Hier wächst deine Analyse',
        text: 'Trag den ersten Tag deiner Periode ein (Blutung ab „Leicht“). Ab zwei Periodenstarts siehst du Zykluslängen, Durchschnitt und Muster je Phase.',
        btn: 'Periode eintragen', go: 'today',
      });
    return;
  }

  // Überblick: eine Zahl groß, darunter ein Satz in Worten, dann eine kleine Liste
  const lens = an.recent.map(c => c.len), lo = Math.min(...lens), hi = Math.max(...lens);
  const verdict = !lens.length ? 'Noch kein Zyklus zwischen 15 und 60 Tagen erfasst.'
    : lens.length === 1 ? `Bisher ein Zyklus mit ${lens[0]} Tagen. Ab dem zweiten siehst du, wie regelmäßig er ist.`
    : `Dein Zyklus ist <b>${regularity(an.sd)}</b>, ${lo === hi ? `zuletzt immer ${lo} Tage` : `zuletzt zwischen ${lo} und ${hi} Tagen`}.`;
  const stat = (label, value) => `<div><dt>${label}</dt><dd>${value}</dd></div>`;
  const counted = (v, dec) => v == null ? '–' : `<span data-to="${v}" data-dec="${dec}">${dec ? num(v) : v}</span>`;
  $('anaSum').innerHTML =
    `<div class="sum-main"><div class="tl">Ø Zykluslänge</div><div class="v">${counted(an.avgCycle, 1)}<span class="u">${an.avgCycle ? ' Tage' : ''}</span></div>` +
    (an.avgCycle ? '' : `<div class="sub">Standard ${an.C} Tage</div>`) + `<p class="verdict">${verdict}</p></div>` +
    `<div class="sum-art">${CARD_ART.moon}</div>` +
    '<dl class="sum-list">' +
    stat('Ø Periode', an.avgPeriod ? `${counted(an.avgPeriod, 1)} Tage` : `${an.P} Tage (Standard)`) +
    stat('Spanne', lens.length ? (lo === hi ? lo : `${lo}–${hi}`) + ' Tage' : '–') +
    stat('Erfasst', `${counted(an.cycles.length, 0)} ${an.cycles.length === 1 ? 'Zyklus' : 'Zyklen'}`) +
    '</dl>';

  // Zyklen als Streifen: vorne die Periode, dahinter der Rest des Zyklus
  const cyc = an.cycles.slice(-12);
  $('cycleDetail').innerHTML = cyc.length ? '<span class="muted">Tipp auf einen Streifen für Details.</span>' : '';
  $('legBand').hidden = lens.length < 2;
  if (!cyc.length) { $('cycleChart').innerHTML = EMPTY_LINE('Noch keine abgeschlossenen Zyklen.'); $('cycleTable').innerHTML = ''; }
  else {
    const max = Math.max(35, ...cyc.map(c => Math.min(c.len, 60)));
    const x = d => Math.min(d, max) / max;
    let h = '<div class="strips">';
    if (lens.length > 1) h += `<div class="band" style="--a:${x(lo)};--w:${x(hi) - x(lo)}" aria-hidden="true"></div>`;
    cyc.forEach((c, i) => {
      h += `<button type="button" class="strip${c.ok ? '' : ' out'}" data-i="${an.cycles.length - cyc.length + i}" aria-pressed="false" aria-label="${esc(cycleText(c))}" style="--i:${i}">` +
        `<span class="d">${fmtShort(c.start)}</span><span class="track"><span class="sbar" style="width:${x(c.len) * 100}%">` +
        `<span class="p" style="width:${Math.min(100, (c.periodLen / c.len) * 100)}%"></span><span class="r"></span><span class="n">${c.len}</span></span></span></button>`;
    });
    h += '</div><div class="axis" aria-hidden="true"><span></span><div>' +
      Array.from({ length: Math.floor(max / 10) + 1 }, (_, k) => `<span style="left:${x(k * 10) * 100}%">${k * 10}</span>`).join('') + '</div></div>';
    $('cycleChart').innerHTML = h;
    $('cycleTable').innerHTML = '<table class="data"><thead><tr><th>Beginn</th><th class="num">Zyklus</th><th class="num">Periode</th><th>Status</th></tr></thead><tbody>' +
      an.cycles.slice().reverse().map(c => `<tr><td>${fmt(c.start, { day: '2-digit', month: '2-digit', year: 'numeric' })}</td><td class="num">${c.len}</td><td class="num">${c.periodLen}</td><td>${c.ok ? 'gezählt' : 'ausgeschlossen'}</td></tr>`).join('') + '</tbody></table>';
  }

  // Muster: kurzer Satz, daneben vier kleine Säulen (eine je Phase)
  const st = moodStats(an, entries(), t);
  state.anaStats = st;
  const pats = findPatterns(st);
  const patRow = (p, i) => {
    const energy = p.kind === 'energy', key = p.kind === 'mood' ? 'moods' : 'syms', top = energy ? p.high.phase : p.phase;
    const share = k => energy ? (avgEnergy(st[k].energy) || 0) / 5 : st[k].n ? (st[k][key][p.id] || 0) / st[k].n : 0;
    const label = PHASES.map(k => `${PHASE_SHORT[k]} ${energy ? (st[k].energy.length ? 'Ø ' + dec1(avgEnergy(st[k].energy)) + ' von 5' : 'keine Angabe') : Math.round(share(k) * 100) + ' %'}`).join(', ');
    return `<div class="pat${i === 0 ? ' prio' : ''}" style="--i:${i}"><p>${patternText(p)}</p><span class="quad" role="img" aria-label="${esc(label)}">` +
      PHASES.map((k, j) => `<span><span class="c"><i class="${k === top ? 'on' : ''}" style="height:${Math.round(share(k) * 100)}%;--j:${j}"></i></span>${PHASE_SHORT[k][0]}</span>`).join('') + '</span></div>';
  };
  $('insights').innerHTML = pats.length
    ? pats.slice(0, 3).map(patRow).join('') +
      (pats.length > 3 ? `<details><summary>Weitere ${plural(pats.length - 3, 'Muster', 'Muster')}</summary><div>${pats.slice(3).map((p, i) => patRow(p, i + 3)).join('')}</div></details>` : '') +
      '<p class="small muted cap">Die Säulen zeigen, wie oft es in jeder Phase vorkommt: P Periode, F Follikel, E Eisprung, L Luteal. Einfache Häufigkeiten aus deinen Einträgen, je mehr Tage, desto belastbarer.</p>'
    : '<div class="pat"><p>Noch keine deutlichen Muster. Sie erscheinen, sobald in mindestens zwei Phasen je drei Tage mit Gefühlen erfasst sind.</p></div>';

  // Je Phase: Energiekurve, Umschalter und eine Karte für die gewählte Phase
  const anyN = PHASES.some(k => st[k].n);
  $('phaseWrap').hidden = !anyN; $('phaseEmpty').hidden = anyN;
  $('phaseEmpty').innerHTML = anyN ? '' : EMPTY_LINE('Noch keine Einträge in einem erkannten Zyklus.');
  if (!anyN) return;
  const en = PHASES.map(k => avgEnergy(st[k].energy));
  const X = [40, 120, 200, 280], Y = v => 80 - (v / 5) * 60;
  const pts = en.map((v, i) => v == null ? null : [X[i], Y(v)]).filter(Boolean);
  let d = pts.length ? `M${pts[0][0]} ${pts[0][1]}` : '';
  for (let i = 1; i < pts.length; i++) { const [x0, y0] = pts[i - 1], [x1, y1] = pts[i], m = (x0 + x1) / 2; d += ` C${m} ${y0} ${m} ${y1} ${x1} ${y1}`; }
  $('energyCurve').innerHTML = `<svg viewBox="0 0 320 96" role="img" aria-label="${esc('Energie je Phase: ' + PHASES.map((k, i) => `${PHASE_SHORT[k]} ${en[i] == null ? 'keine Angabe' : dec1(en[i])}`).join(', ') + ' (von 5)')}">` +
    '<line x1="20" x2="300" y1="80" y2="80" stroke="var(--line-soft)"/>' +
    (d ? `<path class="epath" d="${d}" fill="none" stroke="var(--sage)" stroke-width="2.5" stroke-linecap="round"/>` : '') +
    PHASES.map((k, i) => `<text x="${X[i]}" y="94" text-anchor="middle" class="elbl">${PHASE_SHORT[k]}</text>` +
      (en[i] == null ? '' : `<text x="${X[i]}" y="${Y(en[i]) - 11}" text-anchor="middle" class="eval">${dec1(en[i])}</text><circle class="edot" data-k="${k}" cx="${X[i]}" cy="${Y(en[i])}" r="4"/>`)).join('') + '</svg>';
  if (!$('phasePick').querySelector('button')) {
    $('phasePick').insertAdjacentHTML('beforeend', PHASES.map(k => `<button type="button" data-k="${k}" aria-pressed="false">${PHASE_SHORT[k]}</button>`).join(''));
  }
  $('phaseCard').innerHTML = `<div class="ph-top"><div><h3 id="phName"></h3><div class="small muted" id="phWhen"></div></div><div class="ph-art" id="phArt"></div></div>` +
    '<dl class="ph-facts"><div><dt>Erfasste Tage</dt><dd id="phDays">–</dd></div><div><dt>Energie</dt><dd id="phEnergy"></dd></div></dl>' +
    '<div><p class="small muted cap">Häufigste Gefühle</p><div class="ph-moods" id="phMoods">' +
    [0, 1, 2].map(() => '<div class="ph-mood"><span class="ml"></span><span class="m"><i></i></span><span class="v"></span></div>').join('') + '<p class="small muted" id="phNoMood" hidden>Keine Gefühle eingetragen.</p></div></div>' +
    '<div><p class="small muted cap">Häufigstes Körpersymptom</p><div class="ph-sym" id="phSym"></div></div>';
  // Alle Gefühle als Tabelle, für alle, die Zahlen mögen
  const used = MOODS.filter(id => PHASES.some(k => st[k].moods[id]))
    .map(id => ({ id, total: PHASES.reduce((s, k) => s + (st[k].moods[id] || 0), 0) })).sort((a, b) => b.total - a.total).map(o => o.id);
  $('moodMore').hidden = !used.length;
  $('moodTableAll').innerHTML = used.length ? '<table class="data ph"><thead><tr><th>Gefühl</th>' + PHASES.map(k => `<th class="num">${PHASE_SHORT[k]}</th>`).join('') + '</tr></thead><tbody>' +
    used.map(id => `<tr><td class="mood">${MOOD_LABEL[id]}</td>` + PHASES.map(k => `<td class="num">${st[k].n ? Math.round(((st[k].moods[id] || 0) / st[k].n) * 100) + ' %' : '–'}</td>`).join('') + '</tr>').join('') + '</tbody></table>' : '';
  const now = phaseOf(an, t);
  if (!state.anaPhase) state.anaPhase = now ? now.phase : 'men';
  selectPhase(state.anaPhase, true);
}

const cycleText = c => `Zyklus ab ${fmtShort(c.start)}: ${c.len} Tage, davon ${c.periodLen} Tage Periode${c.ok ? '' : ' · nicht gezählt (unter 15 oder über 60 Tage)'}`;
/** Streifen angetippt: Details darunter zeigen. */
export function showCycle(i) {
  const c = state.an.cycles[i];
  document.querySelectorAll('#cycleChart .strip').forEach(b => b.setAttribute('aria-pressed', b.dataset.i == i));
  $('cycleDetail').textContent = c ? cycleText(c) + '.' : '';
}

/** Phase im Umschalter wählen. Die Karte bleibt stehen, nur Werte und Balken wechseln weich. */
export function selectPhase(k, first) {
  const st = state.anaStats, an = state.an; if (!st) return;
  const s = st[k], i = PHASES.indexOf(k), prevDays = +($('phDays').dataset.to || 0);
  state.anaPhase = k;
  $('phasePick').style.setProperty('--k', i);
  $('phasePick').querySelectorAll('button').forEach(b => b.setAttribute('aria-pressed', b.dataset.k === k));
  document.querySelectorAll('#energyCurve .edot').forEach(c => c.classList.toggle('on', c.dataset.k === k));
  // ungefähre Zyklustage der Phase, gleiche Regeln wie phaseOf
  const ov = an.C - an.L + 1, R = { men: [1, an.P], fol: [an.P + 1, ov - 3], ovu: [ov - 2, ov + 1], lut: [ov + 2, an.C] }[k];
  $('phName').textContent = PHASE_NAME[k];
  $('phWhen').textContent = R[1] >= R[0] ? `etwa Zyklustag ${R[0]} bis ${R[1]}` : '';
  $('phArt').innerHTML = CARD_ART[PHASE_ART[k]];
  if (!first && !reduceMotion()) { $('phArt').classList.remove('pop'); void $('phArt').offsetWidth; $('phArt').classList.add('pop'); }
  const days = $('phDays'); days.dataset.to = s.n; days.textContent = s.n; if (!first) countUp(days, prevDays, 500);
  const e = avgEnergy(s.energy);
  $('phEnergy').innerHTML = e == null ? '–' : `<span class="dots" role="img" aria-label="Ø ${dec1(e)} von 5">${[1, 2, 3, 4, 5].map(n => `<i class="${n <= Math.round(e) ? 'on' : ''}"></i>`).join('')}</span>`;
  const top = Object.entries(s.moods).sort((a, b) => b[1] - a[1]).slice(0, 3);
  $('phMoods').querySelectorAll('.ph-mood').forEach((row, j) => {
    const m = top[j]; row.hidden = !m;
    if (!m) return;
    const v = Math.round((m[1] / s.n) * 100);
    row.querySelector('.ml').textContent = MOOD_LABEL[m[0]];
    row.querySelector('.m i').style.width = v + '%';
    row.querySelector('.v').textContent = v + ' %';
  });
  $('phNoMood').hidden = top.length > 0;
  const sym = s.n && topSymptom(s);
  $('phSym').textContent = sym ? `${SYMPTOM_LABEL[sym.id]} · ${Math.round(sym.share * 100)} %` : s.n ? 'Keins eingetragen' : 'Noch keine Einträge in dieser Phase';
}

/** Beim Öffnen der Analyse: Karten gleiten herein, Streifen und Säulen wachsen, Zahlen zählen hoch. */
let playTimer;
export function playAnalysis() {
  const p = $('p-ana');
  if (reduceMotion() || $('anaBody').hidden) return;
  p.classList.remove('play'); void p.offsetWidth; p.classList.add('play');
  p.querySelectorAll('#anaSum [data-to]').forEach(el => countUp(el, 0, 900));
  const path = p.querySelector('.epath');
  if (path) {
    const L = path.getTotalLength();
    path.style.transition = 'none'; path.style.strokeDasharray = L; path.style.strokeDashoffset = L;
    path.getBoundingClientRect();
    path.style.transition = 'stroke-dashoffset 1s var(--ease) .25s'; path.style.strokeDashoffset = 0;
  }
  clearTimeout(playTimer);
  playTimer = setTimeout(() => p.classList.remove('play'), 2000);
}

// ---------- Daten ----------
export async function renderData() {
  const n = state.days.size;
  let info = `<b>${plural(n, 'Tag', 'Tage')}</b> gespeichert · ${Store.ls ? 'localStorage' : 'IndexedDB'}`;
  if (navigator.storage && navigator.storage.persisted) {
    try { info += (await navigator.storage.persisted()) ? ' · dauerhaft geschützt' : ' · Browser darf bei Speichermangel aufräumen'; } catch { /* egal */ }
  }
  info += '<br>' + (state.lastBackup != null ? `Letztes Backup am ${fmt(state.lastBackup, { day: 'numeric', month: 'long', year: 'numeric' })}` : 'Noch kein Backup gemacht');
  $('storeInfo').innerHTML = info;
  const s = state.settings;
  $('setCycle').value = s.cycleLen; $('setPeriod').value = s.periodLen; $('setLuteal').value = s.luteal; $('setTheme').value = s.theme;
  $('demoNote').hidden = !state.demo;
}

// ---------- Backup-Erinnerung ----------
export function renderBackup() {
  const t = todayNum(), ds = [...state.days.keys()];
  const first = ds.length ? toNum(ds.reduce((a, b) => (a < b ? a : b))) : null;
  const due = !state.demo && backupDue({ count: ds.length, first, lastBackup: state.lastBackup, snoozed: state.backupSnooze, today: t });
  $('backupNote').hidden = !due;
  if (!due) return;
  $('backupText').textContent = state.lastBackup != null
    ? `Dein letztes Backup ist ${plural(t - state.lastBackup, 'Tag', 'Tage')} her. Deine Einträge liegen nur auf diesem Gerät.`
    : 'Du hast noch kein Backup gemacht. Deine Einträge liegen nur auf diesem Gerät. Sichere sie am besten in deinen Dateien oder in der iCloud.';
}

// ---------- Neu berechnen ----------
export function recompute(full = true) {
  state.an = analyze(entries(), state.settings, todayNum());
  renderHero(); renderWeek(); renderOutlook(); renderBackup();
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
    if (on && focus) tab.focus();
  });
  // Seiten: drei aus der Leiste unten, Einstellungen über das Symbol oben rechts
  ['heute', 'kal', 'ana', 'daten'].forEach(k => { $('p-' + k).hidden = k !== name; });
  $('setBtn').setAttribute('aria-pressed', name === 'daten');
  if (name !== 'daten') state.lastTab = name;
  state.tab = name;
  renderHead();
  try { localStorage.setItem('zyklus-tab', name); } catch { /* egal */ }
  if (name === 'kal') renderCalendar();
  if (name === 'ana') { renderAnalysis(); playAnalysis(); }
  if (name === 'daten') renderData();
}

// ---------- Theme ----------
export const THEME_NEXT = { auto: 'dark', dark: 'light', light: 'auto' };
export function applyTheme() {
  const t = state.settings.theme;
  if (t === 'auto') delete document.documentElement.dataset.theme; else document.documentElement.dataset.theme = t;
  try { localStorage.setItem('zyklus-theme', t); } catch { /* egal */ }
  // Statusleiste am Handy passend einfärben
  const forced = { light: '#EADFCC', dark: '#1C1B1A' }[t];
  $('tcLight').content = forced || '#EADFCC';
  $('tcDark').content = forced || '#1C1B1A';
  $('themeBtn').innerHTML = ICON[{ auto: 'auto', light: 'sun', dark: 'moon' }[t]];
  $('themeBtn').title = 'Farbe: ' + THEME_LABEL[t];
  $('themeBtn').setAttribute('aria-label', `Farbschema: ${THEME_LABEL[t]}. Wechseln zu ${THEME_LABEL[THEME_NEXT[t]]}`);
  $('setTheme').value = t;
}

// ---------- Schrift ----------
export function applyFont() {
  const f = state.settings.font;
  if (f === 'klar') delete document.documentElement.dataset.font; else document.documentElement.dataset.font = f;
  try { localStorage.setItem('zyklus-font', f); } catch { /* egal */ }
  $('setFont').value = f;
}


// ---------- Symbole ----------
/** Setzt die Symbole der Leiste unten und den Einstellungen-Knopf (einmal beim Start). */
export function renderIcons() {
  document.querySelectorAll('[data-icon]').forEach(el => { el.innerHTML = ICON[el.dataset.icon]; });
  $('setBtn').innerHTML = ICON.gear;
}
