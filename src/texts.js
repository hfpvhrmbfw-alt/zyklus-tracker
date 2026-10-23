/* Texte der Oberfläche: Beschriftungen zu den IDs aus model.js und Satzbausteine.
   Später in Swift: Localizable.strings bzw. ein String Catalog. */

export const FLOW_LABEL = ['Keine', 'Schmierblutung', 'Leicht', 'Mittel', 'Stark'];
export const MOOD_LABEL = {
  gluecklich: 'Glücklich', ruhig: 'Ruhig', energiegeladen: 'Energiegeladen', selbstbewusst: 'Selbstbewusst',
  gut: 'Gut', zufrieden: 'Zufrieden', dankbar: 'Dankbar', entspannt: 'Entspannt',
  ausgeglichen: 'Ausgeglichen', motiviert: 'Motiviert', kreativ: 'Kreativ', optimistisch: 'Optimistisch',
  verliebt: 'Verliebt', gesellig: 'Gesellig',
  sensibel: 'Sensibel', gereizt: 'Gereizt', traurig: 'Traurig', aengstlich: 'Ängstlich',
  gestresst: 'Gestresst', muede: 'Müde', lustlos: 'Lustlos', unruhig: 'Unruhig',
};
export const SYMPTOM_LABEL = {
  kraempfe: 'Krämpfe', kopfschmerzen: 'Kopfschmerzen', brustspannen: 'Brustspannen', blaehungen: 'Blähungen',
  rueckenschmerzen: 'Rückenschmerzen', unreine_haut: 'Unreine Haut', heisshunger: 'Heißhunger',
  schlafprobleme: 'Schlafprobleme', uebelkeit: 'Übelkeit', unterleibsziehen: 'Ziehen im Unterleib',
};
export const STIMMUNG_LABEL = { gut: 'Gut', ok: 'Ist ok', schlecht: 'Schlecht', abends: 'Nur abends' };
export const ENERGY_LABEL = ['Nicht erfasst', 'Sehr niedrig', 'Niedrig', 'Mittel', 'Hoch', 'Sehr hoch'];
export const PHASE_NAME = { men: 'Menstruation', fol: 'Follikelphase', ovu: 'Eisprungphase', lut: 'Lutealphase' };
export const PHASE_SHORT = { men: 'Periode', fol: 'Follikel', ovu: 'Eisprung', lut: 'Luteal' };
export const THEME_LABEL = { auto: 'System', light: 'Hell', dark: 'Dunkel' };
export const WEEKDAY_SHORT = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
/** Begrüßung auf der Startseite, abhängig von der Stunde */
export const greeting = h => h < 5 ? 'Gute Nacht!' : h < 11 ? 'Guten Morgen!' : h < 14 ? 'Guten Mittag!' : h < 18 ? 'Guten Tag!' : h < 23 ? 'Guten Abend!' : 'Gute Nacht!';
/** Überschrift oben auf den übrigen Seiten */
export const TAB_TITLE = { kal: 'Kalender', ana: 'Analyse', daten: 'Einstellungen' };

export const IMPORT_ERROR = {
  invalid_json: 'Diese Datei ist kein Zyklus-Backup. Bitte wähle eine Datei, die mit „Backup exportieren“ gespeichert wurde.',
  no_entries: 'In der Datei wurden keine Einträge gefunden.',
  newer_version: 'Die Datei stammt aus einer neueren Version der App. Bitte zuerst die App aktualisieren.',
};
