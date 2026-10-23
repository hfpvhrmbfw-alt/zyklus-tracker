# Zyklus für iOS

Native iOS-App (SwiftUI, ab iOS 17). Modell und Logik liegen im Swift-Paket `ZyklusKit` und sind 1:1 aus der Web-App übertragen (`src/model.js`, `src/logic.js`). Beide laufen gegen dieselben Testfälle in `tests/fixtures/`.

| Ordner | Inhalt |
|---|---|
| `ZyklusKit/` | Modell, Logik, Backup-Format, Tests |
| `Zyklus/` | App: Speicher (`Store.swift`), Farben und Schriften (`Theme.swift`), Texte, Bildschirme (`Views/`) |
| `Zyklus/Resources/` | Bilder, App-Icon, Schriften |
| `project.yml` | Beschreibung des Xcode-Projekts für XcodeGen |

## Auf dem Mac öffnen

Einmalig:

1. **Xcode** aus dem Mac App Store installieren und einmal starten (lädt Zusatzkomponenten).
2. **Homebrew** installieren, falls noch nicht da: Anleitung auf brew.sh, ein Befehl im Terminal.
3. Im Terminal: `brew install xcodegen`
4. Das Repo auf den Mac holen, z. B. mit GitHub Desktop oder `git clone https://github.com/hfpvhrmbfw-alt/zyklus-tracker.git`

Danach jedes Mal, wenn sich `project.yml` geändert hat:

```
cd zyklus-tracker/ios
xcodegen
open Zyklus.xcodeproj
```

In Xcode oben ein iPhone-Simulator auswählen (z. B. „iPhone 16“) und auf ▶︎ klicken.

## Auf dem eigenen iPhone

1. iPhone per Kabel anschließen, in Xcode oben als Ziel auswählen.
2. Xcode › Einstellungen › Accounts: mit deiner Apple-ID anmelden.
3. Im Projekt unter *Signing & Capabilities* dein Team wählen. Ohne Developer Account läuft die App 7 Tage, danach neu installieren.
4. Auf dem iPhone: Einstellungen › Datenschutz & Sicherheit › Entwicklermodus einschalten.

## Daten und Sicherung

- Einträge liegen in `Application Support/zyklus.json` im App-Container, im selben Format wie die Backup-Datei.
- Nach jeder Änderung schreibt die App „Zyklus-Backup TT.MM.JJJJ.json“ in den Dokumente-Ordner. Der erscheint in der Dateien-App unter **Auf meinem iPhone › Zyklus**, die letzten 10 Tage bleiben.
- Backups aus der Web-App lassen sich in den Einstellungen einlesen und umgekehrt.

## Tests

In Xcode: Produkt › Test (⌘U). Oder im Terminal: `swift test --package-path ios/ZyklusKit`. Laufen auch automatisch bei jedem Push (GitHub Actions).

## Bilder

Die Illustrationen sind vorerst Abbilder der gezeichneten Bilder aus der Web-App. Neue Bilder einfach in `Zyklus/Resources/Assets.xcassets/<name>.imageset/` austauschen, die Namen stehen im Dokument „Grafiken für die Zyklus-App“.
