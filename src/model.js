/* Modell: Stammdaten, Datumsformat, leere Einträge, Validierung, Schema-Version.
   Keine Abhängigkeiten. Beschriftungen für die Anzeige stehen in texts.js. */

export const APP_ID = 'zyklus-tracker';
export const SCHEMA_VERSION = 1;

// ---------- Stammdaten (stabile IDs, nie umbenennen, nur ergänzen) ----------
/** Blutungsstärke 0 keine, 1 Schmierblutung, 2 leicht, 3 mittel, 4 stark */
export const FLOW = [0, 1, 2, 3, 4];
/** Ab dieser Stärke zählt ein Tag als Periodentag */
export const FLOW_PERIOD = 2;
export const MOODS = [
  'gluecklich', 'ruhig', 'energiegeladen', 'selbstbewusst',
  'gut', 'zufrieden', 'dankbar', 'entspannt',
  'ausgeglichen', 'motiviert', 'kreativ', 'optimistisch',
  'verliebt', 'gesellig',
  'sensibel', 'gereizt', 'traurig', 'aengstlich',
  'gestresst', 'muede', 'lustlos',
];
export const SYMPTOMS = [
  'kraempfe', 'kopfschmerzen', 'brustspannen', 'blaehungen',
  'rueckenschmerzen', 'unreine_haut', 'heisshunger',
  'schlafprobleme', 'uebelkeit',
];
/** Stimmung des Tages, im Kalender als farbiger Punkt */
export const STIMMUNG = ['gut', 'ok', 'schlecht', 'abends'];
/** Ohne eigene Stimmungsangabe wird der Punkt aus den Gefühlen abgeleitet (sonst 'gut') */
export const MOOD_TONE = {
  sensibel: 'ok', muede: 'ok', lustlos: 'ok',
  gereizt: 'schlecht', traurig: 'schlecht', aengstlich: 'schlecht', gestresst: 'schlecht',
};
/** Energie 0 = nicht erfasst, 1–5 sehr niedrig bis sehr hoch */
export const ENERGY = [0, 1, 2, 3, 4, 5];
/** Zyklusphasen: Menstruation, Follikel, Eisprung, Luteal */
export const PHASES = ['men', 'fol', 'ovu', 'lut'];
export const THEMES = ['auto', 'light', 'dark'];

export const DEFAULTS = { cycleLen: 28, periodLen: 5, luteal: 14, theme: 'auto' };
export const NOTE_MAX = 2000;

// ---------- Datum: ganze Tage seit 1970 als Zahl, zeitzonenfest ----------
export const DAY_MS = 864e5;
/** @param {string} s 'YYYY-MM-DD' @returns {number} Tagnummer */
export const toNum = s => { const [y, m, d] = s.split('-').map(Number); return Date.UTC(y, m - 1, d) / DAY_MS; };
/** @param {number} n Tagnummer @returns {string} 'YYYY-MM-DD' */
export const toStr = n => new Date(n * DAY_MS).toISOString().slice(0, 10);

// ---------- Tageseintrag ----------
/**
 * @typedef {{date: string, flow: number, stimmung: string[], moods: string[], symptoms: string[], energy: number, note: string}} DayEntry
 */
/** @param {string} date @returns {DayEntry} */
export const blank = date => ({ date, flow: 0, stimmung: [], moods: [], symptoms: [], energy: 0, note: '' });
/** @param {DayEntry} e @returns {boolean} */
export const isEmpty = e => !e.flow && !e.stimmung.length && !e.moods.length && !e.symptoms.length && !e.energy && !e.note.trim();
/** Hat der Tag Angaben außer der Blutung? @param {DayEntry} e @returns {boolean} */
export const hasDetail = e => !!(e.stimmung.length || e.moods.length || e.symptoms.length || e.energy || e.note.trim());

const clampInt = (v, lo, hi) => Math.min(hi, Math.max(lo, Math.round(Number(v) || 0)));

/** Prüft einen Eintrag aus Speicher oder Import. @returns {DayEntry|null} */
export function sanitize(raw) {
  if (!raw || typeof raw.date !== 'string' || !/^\d{4}-\d{2}-\d{2}$/.test(raw.date) || isNaN(toNum(raw.date))) return null;
  const okMood = new Set(MOODS), okStim = new Set(STIMMUNG), okSym = new Set(SYMPTOMS);
  const list = (v, ok) => Array.isArray(v) ? [...new Set(v.filter(x => ok.has(x)))] : [];
  return {
    date: raw.date,
    flow: clampInt(raw.flow, 0, 4),
    stimmung: list(raw.stimmung, okStim),
    moods: list(raw.moods, okMood),
    symptoms: list(raw.symptoms, okSym),
    energy: clampInt(raw.energy, 0, 5),
    note: typeof raw.note === 'string' ? raw.note.slice(0, NOTE_MAX) : '',
  };
}

// ---------- Einstellungen ----------
/** @typedef {{cycleLen: number, periodLen: number, luteal: number, theme: string}} Settings */
/** Bringt Einstellungen in gültige Bereiche, fehlende Werte werden Standard. @returns {Settings} */
export function sanitizeSettings(s) {
  s = s || {};
  const clamp = (v, lo, hi, d) => { v = Math.round(Number(v)); return isNaN(v) ? d : Math.min(hi, Math.max(lo, v)); };
  return {
    cycleLen: clamp(s.cycleLen, 15, 60, DEFAULTS.cycleLen),
    periodLen: clamp(s.periodLen, 1, 12, DEFAULTS.periodLen),
    luteal: clamp(s.luteal, 8, 18, DEFAULTS.luteal),
    theme: THEMES.includes(s.theme) ? s.theme : 'auto',
  };
}

// ---------- Export / Import ----------
/**
 * Baut die Backup-Datei. @param {Settings} settings @param {DayEntry[]} days
 * @param {string} exportedAt ISO-Zeitstempel (wird übergeben, nicht hier erzeugt)
 */
export function buildExport(settings, days, exportedAt) {
  return {
    app: APP_ID, version: SCHEMA_VERSION, exportedAt, settings,
    days: [...days].sort((a, b) => (a.date < b.date ? -1 : a.date > b.date ? 1 : 0)),
  };
}

/**
 * Liest eine Backup-Datei (bereits geparstes JSON). Ältere Versionen werden migriert.
 * @returns {{ok: true, days: DayEntry[], settings: Settings|null} | {ok: false, error: 'newer_version'|'no_entries'}}
 */
export function parseImport(data) {
  if (data && !Array.isArray(data) && Number(data.version) > SCHEMA_VERSION) return { ok: false, error: 'newer_version' };
  const migrated = migrate(data);
  const days = migrated.days.map(sanitize).filter(Boolean);
  if (!days.length) return { ok: false, error: 'no_entries' };
  return { ok: true, days, settings: migrated.settings ? sanitizeSettings(migrated.settings) : null };
}

/** Hebt ältere Formate auf die aktuelle Schema-Version. Bisher: nackte Liste von Tagen oder Version 1. */
export function migrate(data) {
  if (Array.isArray(data)) return { days: data, settings: null };
  return { days: (data && Array.isArray(data.days)) ? data.days : [], settings: (data && data.settings) || null };
}
