# Zyklus-Tracker

Reine Frontend-PWA ohne Backend und ohne Build-Schritt. Alle Einträge liegen nur im Browser (IndexedDB, Fallback localStorage).

## Funktionen
- **Eintrag:** pro Tag Blutung (keine bis stark), Gefühle, Energie (1–5), Körpersymptome, Notiz. Speichert automatisch.
- **Heute:** Zykluskarte mit Bild je Phase, Stimmungswoche (Sonne, Wolke, Regen, Mond), Ausblick-Kacheln.
- **Kalender:** eingetragene Perioden (P), Schmierblutung (·), erwartete Periode (p), fruchtbares Fenster (F) und Eisprung (E) als Schätzung.
- **Analyse:** Ø Zykluslänge groß, darunter Periodendauer, Spanne, Schwankung (letzte 6 plausiblen Zyklen, 15–60 Tage); die stärksten Muster zuerst, Balken je Zyklus, je Phase Tage, Energie, häufigstes Körpersymptom und die fünf häufigsten Gefühle (Rest aufklappbar).
- **Erster Start:** Begrüßung in drei Schritten (was die App kann, Daten bleiben lokal, letzte Periode und übliche Längen). Die letzte Periode wird als „Leicht“ eingetragen. Alternativ gleich mit Demodaten starten.
- **Backup-Erinnerung:** ab fünf Einträgen auf der Startseite, wenn das letzte Backup (oder ohne Backup der erste Eintrag) 30 Tage her ist; „Später“ schiebt um 7 Tage. Am Handy öffnet „Backup exportieren“ das Teilen-Menü (In Dateien sichern, iCloud).
- **Leerzustände:** Kalender und Analyse zeigen ohne Daten ein Bild, einen kurzen Text und einen Knopf zum Eintragen.
- **Einstellungen** (Symbol oben rechts, nicht in der Leiste): JSON-Backup exportieren/importieren, Standardwerte (Zykluslänge, Periodendauer, Lutealphase), Hell/Dunkel, Demodaten, alles löschen.

## Bilder
Illustrationen sind meist Inline-SVG in `src/art.js`. Gemalte Bilder liegen als PNG mit echter Transparenz in `img/` (Zweige oben, kleiner Zweig auf den Kacheln). Neue PNGs dort ablegen und in `sw.js` unter `SHELL` eintragen.

## Schriften
Liegen in `fonts/` (variable WOFF2, Zeichensatz latin, SIL Open Font License) und werden nicht bei Google geladen. Neue Schriftdateien in `sw.js` unter `SHELL` eintragen.

## Wie gerechnet wird
- Periodenstart = erster Tag mit Blutung ab „Leicht“; Lücken bis 1 Tag gehören zur selben Periode.
- Nächste Periode = letzter Start + Ø Zykluslänge. Eisprung = nächster Start − Lutealphase (Standard 14). Fruchtbar = Eisprung −5 bis +1.
- Phasen: Menstruation, Follikelphase, Eisprungphase (Eisprung −2 bis +1), Lutealphase.
- Alles sind Schätzungen, kein medizinischer Rat und nicht zur Verhütung geeignet.

## Starten
Die App nutzt ES-Module und braucht deshalb einen kleinen Server (`https://` oder `localhost`, nicht `file://`):

```
cd zyklus-tracker
npx serve .        # oder: python3 -m http.server 8000
```

Zum Installieren auf dem Handy den Ordner auf einen HTTPS-Host legen (z. B. GitHub Pages, Netlify), Seite öffnen und „Zum Home-Bildschirm“ bzw. „App installieren“ wählen. Danach läuft die App offline.

## Aufbau
Vier Schichten, Abhängigkeiten nur in eine Richtung (Oberfläche → Logik → Modell, Oberfläche → Speicher → Modell):

| Datei | Schicht |
|---|---|
| `src/model.js` | Modell: Stammdaten-IDs, Einträge, Validierung, Import/Export, Schema-Version |
| `src/logic.js` | Logik: reine Funktionen (Zyklen, Phasen, Muster, Demodaten), ohne DOM, Speicher oder Uhrzeit |
| `src/storage.js` | Speicher: IndexedDB mit localStorage-Fallback |
| `src/texts.js` | Beschriftungen und Meldungen der Oberfläche |
| `src/ui.js` | Oberfläche: Rendering, Formatierung, Theme |
| `src/art.js` | Oberfläche: Illustrationen und Symbole als Inline-SVG |
| `src/main.js` | Start, Aktionen, Ereignisse |

Weitere Dateien: `index.html` · `styles.css` (Stil „Beet“ v2.0, mobil zuerst) · `sw.js` · `manifest.webmanifest` · `icons/` · `docs/SWIFT.md` (Übertragung nach Swift)

## Tests
Die Logik läuft ohne Browser und wird mit Node getestet (keine Abhängigkeiten):

```
npm test
```

Die Testfälle liegen als JSON in `tests/fixtures/` und sind für spätere Swift-Tests wiederverwendbar.

## Nach Änderungen
`VERSION` in `sw.js` hochzählen und neue Dateien in die `SHELL`-Liste eintragen, damit installierte Apps das Update laden.
