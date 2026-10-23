# Texte für den App-Store-Eintrag

Alles zum Hineinkopieren in App Store Connect (Seite der App › Version 1.0 › Deutsch). Die Zahl in Klammern ist die Länge, das Limit von Apple steht dahinter.

## Name (max. 30 Zeichen)

Der Name muss im ganzen App Store einmalig sein. „Zyklus“ allein ist sehr wahrscheinlich schon vergeben. Vorschläge:

1. **Zyklus – Periode & Gefühle** (26) ← Empfehlung, passt zu dem, was die App besonders macht
2. Zyklus: Periode & Stimmung (26)
3. Zyklus – Periodenkalender (25)

Auf dem Home-Bildschirm steht trotzdem nur „Zyklus“ (das legt `CFBundleDisplayName` in `ios/project.yml` fest).

## Untertitel (max. 30 Zeichen)

1. **Deine Daten bleiben bei dir** (27) ← Empfehlung
2. Periode, Gefühle, Muster (24)
3. Periodenkalender ohne Konto (27)

## Werbetext (max. 170 Zeichen, jederzeit ohne neue Prüfung änderbar)

Kein Konto, kein Server, keine Werbung: Zyklus speichert deine Einträge nur auf deinem iPhone und zeigt dir, wie Periode, Stimmung und Energie zusammenhängen. (158)

## Schlagwörter (max. 100 Zeichen, mit Komma, ohne Leerzeichen)

```
menstruation,periodenkalender,eisprung,fruchtbar,pms,stimmung,symptome,tagebuch,privat,offline,regel
```

(100) Wörter aus Name und Untertitel (Zyklus, Periode, Gefühle, Daten) sucht Apple ohnehin mit, deshalb stehen sie hier nicht noch einmal.

## Beschreibung (max. 4000 Zeichen)

```
Zyklus ist ein ruhiger Begleiter für deine Periode und alles, was dazugehört. Trag ein, wie es dir geht, und sieh, wie dein Zyklus und deine Stimmung zusammenhängen. Ohne Konto, ohne Werbung und ohne dass deine Daten dein iPhone verlassen.

WAS DU EINTRÄGST
• Blutung, von Schmierblutung bis stark
• Stimmung und Gefühle, von „zufrieden“ bis „unruhig“
• Energie auf einer Skala von 1 bis 5
• Körpersymptome wie Krämpfe, Kopfschmerzen oder Brustspannen
• eine Notiz für alles andere

WAS DIR ZYKLUS ZEIGT
• Heute: in welcher Phase du gerade bist, wann die nächste Periode zu erwarten ist und wie deine Woche war
• Kalender: Perioden, erwartete Periode, fruchtbares Fenster und Eisprung auf einen Blick
• Analyse: deine durchschnittliche Zykluslänge und Periodendauer, die Schwankung und deine stärksten Muster, zum Beispiel in welcher Phase deine Energie am niedrigsten ist oder welche Gefühle und Beschwerden in welcher Phase gehäuft vorkommen

DEINE DATEN BLEIBEN BEI DIR
• Kein Konto, keine Anmeldung, kein Server
• Keine Werbung, keine Analyse-Werkzeuge, kein Tracking
• Alle Einträge liegen nur auf deinem iPhone
• Automatische Sicherung in der Dateien-App unter „Auf meinem iPhone › Zyklus“
• Sicherung jederzeit in iCloud Drive oder an einem anderen Ort ablegen und wieder einlesen

SCHÖN UND RUHIG
Warme Farben, gemalte Illustrationen, viel Luft. Hell und dunkel, ganz nach deiner Einstellung.

WICHTIG
Alle Vorhersagen sind Schätzungen aus deinen bisherigen Einträgen. Zyklus ist kein Medizinprodukt, ersetzt keine ärztliche Beratung und ist nicht zur Verhütung geeignet.
```

## Neu in dieser Version (bei 1.0 nicht nötig, ab dem ersten Update)

Für spätere Versionen, Beispiel: „Kleine Verbesserungen und Fehlerbehebungen.“

## Adressen (URLs)

| Feld | Adresse |
|---|---|
| Datenschutzrichtlinie (Pflicht) | https://hfpvhrmbfw-alt.github.io/zyklus-tracker/datenschutz.html |
| Support-URL (Pflicht) | https://hfpvhrmbfw-alt.github.io/zyklus-tracker/hilfe.html |
| Marketing-URL (freiwillig) | leer lassen oder https://hfpvhrmbfw-alt.github.io/zyklus-tracker/ (die Web-App) |

Die Seiten sind erreichbar, sobald der Pull Request auf `main` ist. Vorher in allen drei Seiten (`datenschutz.html`, `hilfe.html`, `impressum.html`) die orange markierten Platzhalter ausfüllen.

## Weitere Angaben

| Feld | Vorschlag |
|---|---|
| Primäre Sprache | Deutsch |
| Kategorie | Gesundheit und Fitness |
| Zweite Kategorie | Lifestyle (freiwillig) |
| Preis | Kostenlos |
| Copyright | 2026 [dein Name] |
| SKU (interne Kennung, frei wählbar) | zyklus-ios |
| Bundle-ID | de.annagramm.zyklus |

## Hinweise für die Prüfung durch Apple (App Review Information)

- **Anmeldung erforderlich:** Nein (Häkchen bei „Sign-in required“ entfernen)
- **Kontakt:** dein Name, deine Telefonnummer, deine E-Mail (sieht nur Apple)
- **Notizen:**

```
Die App braucht kein Konto und keine Internetverbindung. Alle Einträge bleiben auf dem Gerät.
Zum Ausprobieren mit Beispieldaten: Zahnrad oben rechts › „Demodaten laden“.
Die Vorhersagen sind Schätzungen; die App weist in den Einstellungen und auf der Support-Seite darauf hin, dass sie kein medizinischer Rat und nicht zur Verhütung geeignet ist.

The app needs no account and no internet connection. All data stays on the device.
To try it with sample data: gear icon top right › "Demodaten laden" (load demo data).
```
