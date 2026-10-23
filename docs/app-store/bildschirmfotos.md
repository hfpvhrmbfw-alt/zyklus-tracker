# Bildschirmfotos für den App Store

## Welche Größe Apple verlangt

Für iPhone-Apps reicht **ein Satz in 6,9 Zoll** (1320 × 2868 Pixel, Hochformat). Apple verkleinert die Bilder selbst für alle kleineren iPhones. Erlaubt sind 1 bis 10 Bilder, PNG oder JPEG, ohne Transparenz.

Ein iPad-Satz ist nicht nötig, weil die App nur für iPhone gebaut ist (`TARGETED_DEVICE_FAMILY: "1"`).

## Wie die Bilder entstehen

Bei jedem Pull Request und auf Knopfdruck macht GitHub die Fotos automatisch im Simulator („iPhone … Pro Max“), Uhrzeit 9:41, volle Akkuanzeige:

1. Auf GitHub im Repo oben **Actions** › links **Tests** › rechts **Run workflow** › **Run workflow** (oder einen fertigen Lauf eines Pull Requests öffnen).
2. Wenn der Lauf grün ist: ganz unten unter **Artifacts** die Datei **app-store-bildschirmfotos** herunterladen und entpacken.
3. In App Store Connect bei der Version unter **iPhone 6,9"** die Bilder in der Reihenfolge der Nummern hineinziehen.

## Reihenfolge

Die ersten drei Bilder sieht man in den Suchergebnissen, deshalb stehen dort die stärksten Seiten.

| Nr. | Bild | Was es zeigt |
|---|---|---|
| 01 | Heute (hell) | Zykluskarte mit Phase, Stimmungswoche, Ausblick |
| 02 | Kalender (hell) | Perioden, erwartete Periode, fruchtbares Fenster |
| 03 | Eintrag (hell) | Wie leicht ein Tag eingetragen ist |
| 04 | Analyse (hell) | Zykluslänge und Muster |
| 05 | Heute (dunkel) | Dunkler Modus |
| 06 | Begrüßung, Schritt 2 | „Deine Daten bleiben bei dir“ |

Alle Bilder mit Demodaten (erfundene Werte), es sind also keine echten Gesundheitsdaten zu sehen.

## Später (freiwillig)

Viele Apps setzen über die Bildschirmfotos eine kurze Überschrift auf farbigem Grund, zum Beispiel „Deine Daten bleiben bei dir“. Das geht auch nachträglich, ohne die App neu einzureichen. Die reinen Fotos sind für den Anfang völlig in Ordnung.
