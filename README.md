# Zyklus-Tracker

Reine Frontend-PWA ohne Backend und ohne Build-Schritt. Alle Einträge liegen nur im Browser (IndexedDB, Fallback localStorage).

## Funktionen
- **Eintrag:** pro Tag Blutung (keine bis stark), Gefühle, Energie (1–5), Körpersymptome, Notiz. Speichert automatisch.
- **Kalender:** eingetragene Perioden (P), Schmierblutung (·), erwartete Periode (p), fruchtbares Fenster (F) und Eisprung (E) als Schätzung.
- **Analyse:** Ø Zykluslänge und Periodendauer (letzte 6 plausiblen Zyklen, 15–60 Tage), Spanne und Schwankung, Balken je Zyklus, Gefühle je Zyklusphase, automatisch erkannte Muster.
- **Daten:** JSON-Backup exportieren/importieren, Standardwerte (Zykluslänge, Periodendauer, Lutealphase), Hell/Dunkel, Demodaten, alles löschen.

## Wie gerechnet wird
- Periodenstart = erster Tag mit Blutung ab „Leicht“; Lücken bis 1 Tag gehören zur selben Periode.
- Nächste Periode = letzter Start + Ø Zykluslänge. Eisprung = nächster Start − Lutealphase (Standard 14). Fruchtbar = Eisprung −5 bis +1.
- Phasen: Menstruation, Follikelphase, Eisprungphase (Eisprung −2 bis +1), Lutealphase.
- Alles sind Schätzungen, kein medizinischer Rat und nicht zur Verhütung geeignet.

## Starten
Service Worker brauchen `https://` oder `localhost`:

```
cd zyklus-tracker
npx serve .        # oder: python3 -m http.server 8000
```

Zum Installieren auf dem Handy den Ordner auf einen HTTPS-Host legen (z. B. GitHub Pages, Netlify), Seite öffnen und „Zum Home-Bildschirm“ bzw. „App installieren“ wählen. Danach läuft die App offline.

## Dateien
`index.html` · `styles.css` (Hausstil Web v1.2) · `app.js` · `sw.js` · `manifest.webmanifest` · `icons/`

Nach Änderungen an App-Dateien `VERSION` in `sw.js` hochzählen, damit installierte Apps das Update laden.
