# Übertragung nach Swift

Die PWA ist in vier Schichten aufgeteilt. Modell und Logik werden 1:1 übertragen, Oberfläche und Speicher entstehen in Swift neu.

| Datei | Inhalt | In Swift |
|---|---|---|
| `src/model.js` | Stammdaten-IDs, `DayEntry`, `Settings`, `sanitize`, Import/Export, Migration | 1:1 übertragen (`struct`, `enum`, `Codable`) |
| `src/logic.js` | `analyze`, `phaseOf`, `moodStats`, `findPatterns`, `makeDemo` | 1:1 übertragen, reine Funktionen |
| `tests/fixtures/*.json` | Eingaben und erwartete Ergebnisse | als XCTest-Fixtures wiederverwenden |
| `src/texts.js` | Beschriftungen und Fehlermeldungen | String Catalog (`Localizable.xcstrings`) |
| `src/storage.js` | IndexedDB / localStorage | neu: SwiftData oder Dateien im App-Container |
| `src/ui.js`, `src/main.js` | Rendering, Ereignisse, Formatierung | neu: SwiftUI |

## Datentypen

```swift
struct DayEntry: Codable {
  var date: String          // "YYYY-MM-DD"
  var flow: Int             // 0 keine … 4 stark, Periode ab 2
  var stimmung: [Stimmung]  // gut, ok, schlecht, abends
  var moods: [Mood]
  var symptoms: [Symptom]
  var energy: Int           // 0 nicht erfasst, 1–5
  var note: String          // max. 2000 Zeichen
}
struct Settings: Codable { var cycleLen = 28, periodLen = 5, luteal = 14; var theme: Theme = .auto }
enum Phase: String, Codable { case men, fol, ovu, lut }
```

`Mood`, `Symptom` und `Stimmung` werden `enum`s mit `String`-Rohwerten aus `model.js`. Die IDs nie umbenennen, nur ergänzen. Unbekannte IDs beim Import verwerfen (wie `sanitize`).

## Datum

Tage werden als ganze Zahl seit 1.1.1970 gerechnet (`toNum`/`toStr`), immer in UTC. In Swift: `Calendar` mit `TimeZone(identifier: "UTC")`, nie mit lokaler Zeitzone rechnen. "Heute" wird einmal in der Oberfläche aus dem lokalen Datum bestimmt und als Zahl an die Logik übergeben.

## Muster

`findPatterns` liefert Daten (`kind`, `id`, `phase`, `share`, `otherShare` bzw. `high`/`low` bei Energie). Die Sätze baut die Oberfläche (`patternText` in `ui.js`). In Swift entsprechend ein `enum Pattern` mit zugehörigen Werten und die Formulierung im View.

## Austauschformat

Backup-Datei (JSON), identisch in PWA und Swift-App:

```json
{ "app": "zyklus-tracker", "version": 1, "exportedAt": "2026-10-12T08:00:00.000Z",
  "settings": { "cycleLen": 28, "periodLen": 5, "luteal": 14, "theme": "auto" },
  "days": [ { "date": "2026-10-01", "flow": 3, "stimmung": [], "moods": ["muede"], "symptoms": ["kraempfe"], "energy": 2, "note": "" } ] }
```

Eine Datei mit höherer `version` als die App kennt wird abgelehnt. Bei einer neuen Schema-Version kommt eine Migration in `migrate` (model.js) und in Swift.

## Kommazahlen in den Fixtures

Kommazahlen sind auf 6 Nachkommastellen gerundet. Swift-Tests mit Toleranz `1e-6` vergleichen.
