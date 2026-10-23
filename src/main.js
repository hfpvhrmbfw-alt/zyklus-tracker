/* Zyklus-Tracker · reine Frontend-PWA, Daten nur lokal (IndexedDB, Fallback localStorage)
   Start, Aktionen und Ereignisse. Verbindet Oberfläche, Logik und Speicher. */

import { toNum, toStr, isEmpty, sanitize, sanitizeSettings, buildExport, parseImport, DEFAULTS } from './model.js';
import { makeDemo, introPeriod } from './logic.js';
import { Store } from './storage.js';
import { IMPORT_ERROR } from './texts.js';
import {
  $, state, entries, todayNum, plural, readForm,
  renderDay, renderCalendar, renderData, renderBackup, recompute, showTab, applyTheme, applyFont, renderIcons, THEME_NEXT,
} from './ui.js';
import { scene } from './art.js';

// ---------- Tag speichern ----------
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

// ---------- Persistenz-Wunsch ----------
let persistAsked = false;
function askPersist() {
  if (persistAsked || !navigator.storage || !navigator.storage.persist) return;
  persistAsked = true;
  navigator.storage.persist().catch(() => {});
}

// ---------- Einstellungen ----------
async function saveSettings(s) {
  state.settings = sanitizeSettings(s);
  await Store.setMeta('settings', state.settings);
  applyTheme(); applyFont();
}

// ---------- Export / Import ----------
async function exportData() {
  const data = buildExport(state.settings, entries(), new Date().toISOString());
  // Lesbarer Name ohne Technikwörter; die Endung .json braucht das iPhone, um die Datei wieder einzulesen
  const name = `Zyklus-Backup ${toStr(todayNum()).split('-').reverse().join('.')}.json`;
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  // Am Handy über das Teilen-Menü (In Dateien sichern, iCloud …), sonst als Download
  const file = typeof File === 'function' ? new File([blob], name, { type: 'application/json' }) : null;
  if (file && matchMedia('(pointer: coarse)').matches && navigator.canShare && navigator.canShare({ files: [file] })) {
    try { await navigator.share({ files: [file], title: 'Zyklus-Backup' }); }
    catch (e) { if (e.name === 'AbortError') return; download(blob, name); }
  } else download(blob, name);
  await markBackup();
}

function download(blob, name) {
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = name;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
}

async function markBackup() {
  state.lastBackup = todayNum(); state.backupSnooze = null;
  await Store.setMeta('lastBackup', state.lastBackup);
  renderBackup();
  if (state.tab === 'daten') renderData();
}

async function importData(file) {
  let data;
  try { data = JSON.parse(await file.text()); } catch { alert(IMPORT_ERROR.invalid_json); return; }
  const res = parseImport(data);
  if (!res.ok) { alert(IMPORT_ERROR[res.error]); return; }
  if (!confirm(`${plural(res.days.length, 'Eintrag', 'Einträge')} importieren? Einträge an gleichen Tagen werden überschrieben.`)) return;
  await Store.putDays(res.days);
  res.days.forEach(e => state.days.set(e.date, e));
  if (res.settings) await saveSettings(res.settings);
  await markBackup(); // wer importiert, hat die Datei schon als Backup
  recompute(); renderData();
  alert('Import abgeschlossen.');
}

async function loadDemo() {
  await Store.clearDays(); state.days.clear();
  const list = makeDemo(todayNum());
  await Store.putDays(list); list.forEach(e => state.days.set(e.date, e));
  state.demo = true; await Store.setMeta('demo', true);
  recompute(); renderData();
}

// ---------- Begrüßung beim ersten Start ----------
function openIntro() {
  const dlg = $('intro');
  dlg.querySelectorAll('[data-art]').forEach(el => { el.innerHTML = scene(el.dataset.art); });
  $('introStart').max = toStr(todayNum());
  $('introPeriod').value = state.settings.periodLen; $('introCycle').value = state.settings.cycleLen;
  const steps = [...dlg.querySelectorAll('.intro-step')], dots = [...dlg.querySelectorAll('.intro-dots i')];
  const go = i => {
    steps.forEach((s, k) => { s.hidden = k !== i; });
    dots.forEach((d, k) => d.classList.toggle('on', k === i));
    const h = steps[i].querySelector('h2');
    dlg.setAttribute('aria-labelledby', h.id);
    h.tabIndex = -1; h.focus();
  };
  dlg.querySelectorAll('[data-next]').forEach((b, i) => { b.onclick = () => go(i + 1); });
  const finish = async () => { await Store.setMeta('onboarded', true); dlg.close(); };
  $('introSkip').onclick = finish;
  dlg.addEventListener('cancel', e => { e.preventDefault(); finish(); });
  $('introDemo').onclick = async () => { await finish(); await loadDemo(); };
  $('introDone').onclick = async () => {
    await saveSettings({ ...state.settings, cycleLen: $('introCycle').value, periodLen: $('introPeriod').value });
    const v = $('introStart').value;
    if (v && toNum(v) <= todayNum()) {
      const list = introPeriod(toNum(v), state.settings.periodLen, todayNum());
      await Store.putDays(list); list.forEach(e => state.days.set(e.date, e));
    }
    await finish();
    recompute();
  };
  if (typeof dlg.showModal === 'function') dlg.showModal(); else dlg.setAttribute('open', '');
  go(0);
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
    tab.addEventListener('click', () => { showTab(tab.id.slice(4)); window.scrollTo({ top: 0 }); });
    tab.addEventListener('keydown', e => {
      const d = e.key === 'ArrowRight' ? 1 : e.key === 'ArrowLeft' ? -1 : 0;
      if (!d) return;
      e.preventDefault();
      showTab(tabs[(i + d + tabs.length) % tabs.length].id.slice(4), true);
    });
  });

  $('prevMonth').onclick = () => { const [y, m] = state.month; state.month = m ? [y, m - 1] : [y - 1, 11]; renderCalendar(); };
  $('nextMonth').onclick = () => { const [y, m] = state.month; state.month = m === 11 ? [y + 1, 0] : [y, m + 1]; renderCalendar(); };
  // Tag aus Kalender oder Wochenleiste öffnen: zum Formular springen
  const openDay = async n => {
    await saveDay(true);
    state.sel = n; renderDay(); showTab('heute');
    $('entry').scrollIntoView({ behavior: 'smooth', block: 'start' });
  };
  $('cal').addEventListener('click', e => {
    const b = e.target.closest('button.day[data-n]');
    if (b) openDay(Number(b.dataset.n));
  });
  $('moodWeek').addEventListener('click', e => {
    const b = e.target.closest('button.wday[data-n]');
    if (b) openDay(Number(b.dataset.n));
  });
  $('goEntry').onclick = () => openDay(todayNum());
  // Knöpfe in den Leerzuständen (Kalender, Analyse)
  document.addEventListener('click', e => {
    const b = e.target.closest('[data-go]');
    if (!b) return;
    if (b.dataset.go === 'today') openDay(todayNum());
    else { showTab(b.dataset.go); window.scrollTo({ top: 0 }); }
  });
  $('backupNow').onclick = exportData;
  $('backupLater').onclick = async () => {
    state.backupSnooze = todayNum(); await Store.setMeta('backupSnooze', state.backupSnooze);
    renderBackup();
  };
  $('seeMonth').onclick = () => { showTab('kal'); window.scrollTo({ top: 0 }); };
  // Symbol oben rechts öffnet die Einstellungen, ein zweiter Tipp führt zurück
  $('setBtn').onclick = () => { showTab(state.tab === 'daten' ? state.lastTab : 'daten'); window.scrollTo({ top: 0 }); };

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
  ['setCycle', 'setPeriod', 'setLuteal', 'setTheme', 'setFont'].forEach(id => $(id).addEventListener('change', async () => {
    await saveSettings({ cycleLen: $('setCycle').value, periodLen: $('setPeriod').value, luteal: $('setLuteal').value, theme: $('setTheme').value, font: $('setFont').value });
    recompute(); renderData();
  }));
  $('demoBtn').onclick = async () => {
    if (state.days.size && !confirm('Demodaten ersetzen alle vorhandenen Einträge. Vorher am besten ein Backup exportieren. Fortfahren?')) return;
    await loadDemo();
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
  const [list, settings, demo, lastBackup, backupSnooze, onboarded] = await Promise.all([Store.allDays(),
    Store.getMeta('settings'), Store.getMeta('demo'), Store.getMeta('lastBackup'), Store.getMeta('backupSnooze'), Store.getMeta('onboarded')]);
  list.map(sanitize).filter(Boolean).forEach(e => state.days.set(e.date, e));
  state.settings = { ...DEFAULTS, ...(settings || {}) };
  state.demo = !!demo;
  state.lastBackup = Number.isFinite(lastBackup) ? lastBackup : null;
  state.backupSnooze = Number.isFinite(backupSnooze) ? backupSnooze : null;
  renderIcons();
  applyTheme();
  applyFont();
  const d = new Date(); state.month = [d.getFullYear(), d.getMonth()];
  bind();
  recompute();
  $('demoNote').hidden = !state.demo;
  let tab = 'heute';
  try { tab = localStorage.getItem('zyklus-tab') || 'heute'; } catch { /* egal */ }
  showTab(['heute', 'kal', 'ana', 'daten'].includes(tab) ? tab : 'heute');
  // Erster Start: Begrüßung. Wer schon Einträge hat (ältere Version), sieht sie nicht.
  if (!onboarded) {
    if (state.days.size || state.demo) Store.setMeta('onboarded', true);
    else { showTab('heute'); openIntro(); }
  }
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    // Neue Version übernommen → einmal neu laden, damit alle Dateien zusammenpassen
    const hadController = !!navigator.serviceWorker.controller;
    let reloaded = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => { if (hadController && !reloaded) { reloaded = true; location.reload(); } });
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
})();
