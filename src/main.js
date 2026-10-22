/* Zyklus-Tracker · reine Frontend-PWA, Daten nur lokal (IndexedDB, Fallback localStorage)
   Start, Aktionen und Ereignisse. Verbindet Oberfläche, Logik und Speicher. */

import { toNum, toStr, isEmpty, sanitize, sanitizeSettings, buildExport, parseImport, DEFAULTS } from './model.js';
import { makeDemo } from './logic.js';
import { Store } from './storage.js';
import { IMPORT_ERROR } from './texts.js';
import {
  $, state, entries, todayNum, plural, readForm,
  renderDay, renderCalendar, renderData, recompute, showTab, applyTheme, applyFont, renderIcons, THEME_NEXT,
} from './ui.js';

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
function exportData() {
  const data = buildExport(state.settings, entries(), new Date().toISOString());
  const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `zyklus-backup-${toStr(todayNum())}.json`;
  document.body.appendChild(a); a.click(); a.remove();
  setTimeout(() => URL.revokeObjectURL(a.href), 2000);
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
  recompute(); renderData();
  alert('Import abgeschlossen.');
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
  if ('serviceWorker' in navigator && location.protocol !== 'file:') {
    // Neue Version übernommen → einmal neu laden, damit alle Dateien zusammenpassen
    const hadController = !!navigator.serviceWorker.controller;
    let reloaded = false;
    navigator.serviceWorker.addEventListener('controllerchange', () => { if (hadController && !reloaded) { reloaded = true; location.reload(); } });
    navigator.serviceWorker.register('sw.js').catch(() => {});
  }
})();
