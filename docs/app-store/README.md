# Zyklus in den App Store bringen

Diese Liste führt Schritt für Schritt bis zur Veröffentlichung. Was schon vorbereitet ist, ist abgehakt. Die übrigen Schritte brauchen deine Apple-ID, deinen Mac oder deine Unterschrift.

| Datei | Inhalt |
|---|---|
| [store-texte.md](store-texte.md) | Name, Untertitel, Beschreibung, Schlagwörter, Adressen, Hinweise für die Prüfung |
| [fragen-in-app-store-connect.md](fragen-in-app-store-connect.md) | Antworten für App-Datenschutz, Altersfreigabe, Händlerstatus |
| [bildschirmfotos.md](bildschirmfotos.md) | Größen, Reihenfolge und wie die Bilder automatisch entstehen |

## Schon vorbereitet

- [x] Datenschutzerklärung als Seite: `datenschutz.html`
- [x] Hilfe-Seite (Apple verlangt eine „Support-URL“): `hilfe.html`
- [x] Gerüst fürs Impressum: `impressum.html`
- [x] Links zu Datenschutz, Hilfe und Impressum in den Einstellungen der iPhone-App und der Web-App (Apple verlangt den Link auch in der App)
- [x] Datenschutz-Datei für Apple in der App (`PrivacyInfo.xcprivacy`)
- [x] Angabe zur Verschlüsselung in `ios/project.yml`, damit die Frage beim Hochladen entfällt
- [x] Versionsnummer 1.0.0
- [x] Texte und Antworten für App Store Connect
- [x] Bildschirmfotos in 6,9 Zoll entstehen automatisch bei GitHub

## Was du selbst erledigen musst

### A. Vorher klären (geht sofort)

- [ ] **Platzhalter ausfüllen** in `datenschutz.html`, `hilfe.html` und `impressum.html` (orange markiert): Name, Anschrift, E-Mail, zuständige Datenschutzbehörde (die deines Bundeslands). Oder du schickst mir die Angaben, dann trage ich sie ein. Wenn du deine Privatadresse nicht veröffentlichen willst, gibt es Dienste für eine ladungsfähige Postanschrift („Impressum-Service“).
- [ ] **Impressum:** Dein eigener Text kann das Gerüst in `impressum.html` ersetzen. Liegt dein Impressum woanders, sag mir die Adresse, dann verlinke ich darauf.
- [ ] **App-Icon** endgültig festlegen (offen im Thread „Stil des App-Icons“).
- [ ] **Name im Store** aussuchen (Vorschläge in `store-texte.md`).

### B. Apple Developer Account (dauert 1 bis 2 Tage)

1. Auf dem iPhone die App **Apple Developer** aus dem App Store laden.
2. Mit deiner Apple-ID anmelden. Die Zwei-Faktor-Authentifizierung muss an sein (ist sie bei neueren Apple-IDs automatisch).
3. Im Reiter **Konto** auf **Jetzt registrieren** tippen, als **Einzelperson** anmelden, deinen amtlichen Namen angeben und 99 € im Jahr bezahlen.
4. Warten, bis die Bestätigungs-E-Mail kommt.

Im App Store steht später dein Name als Anbieterin. Eine Firma (mit D-U-N-S-Nummer) ist nicht nötig.

### C. App in App Store Connect anlegen (10 Minuten)

1. Auf [appstoreconnect.apple.com](https://appstoreconnect.apple.com) anmelden, **Apps** › **+** › **Neue App**.
2. Plattform **iOS**, Name (aus `store-texte.md`), Primäre Sprache **Deutsch**, Bundle-ID **de.annagramm.zyklus**, SKU **zyklus-ios**, Zugriff **Uneingeschränkt**.
   Falls die Bundle-ID nicht in der Liste steht: erst Schritt D bis zum Hochladen machen, Xcode legt sie dann an. Oder auf [developer.apple.com](https://developer.apple.com/account/resources/identifiers/list) unter Identifiers mit **+** anlegen.
3. Händlerstatus (EU) angeben, siehe `fragen-in-app-store-connect.md`.

### D. App mit Xcode hochladen (30 Minuten beim ersten Mal)

1. Repo auf dem Mac aktualisieren, dann im Terminal:
   ```
   cd zyklus-tracker/ios
   xcodegen
   open Zyklus.xcodeproj
   ```
2. In Xcode: **Xcode › Einstellungen › Accounts**, mit der Apple-ID anmelden. Dein Team erscheint als „Anna … (Personal Team)“ und, sobald der Account freigeschaltet ist, ohne den Zusatz.
3. Links das Projekt **Zyklus** › Ziel **Zyklus** › **Signing & Capabilities** › bei **Team** dein Team wählen.
4. **Wichtig:** Damit die Auswahl beim nächsten `xcodegen` nicht verloren geht, die Team-ID (10 Zeichen, steht auf developer.apple.com unter **Membership**) in `ios/project.yml` bei `DEVELOPMENT_TEAM` eintragen. Oder mir schicken, dann mache ich das.
5. Oben als Ziel **Any iOS Device (arm64)** wählen.
6. Menü **Product › Archive**. Nach ein paar Minuten öffnet sich das Fenster **Organizer**.
7. **Distribute App** › **App Store Connect** › **Upload** und den Vorschlägen folgen.
8. Nach 10 bis 30 Minuten erscheint der Build in App Store Connect unter **TestFlight**.

Für jedes weitere Hochladen muss die Build-Nummer steigen: in `ios/project.yml` `CURRENT_PROJECT_VERSION` um eins erhöhen (oder mir Bescheid geben).

### E. Mit TestFlight auf dem eigenen iPhone testen (freiwillig, empfohlen)

1. In App Store Connect unter **TestFlight** › **Interne Tests** eine Gruppe anlegen und dich hinzufügen.
2. Auf dem iPhone die App **TestFlight** laden, die Einladung annehmen, Zyklus installieren.
3. Ein paar Tage normal benutzen, auch eine Sicherung anlegen und wieder einlesen.

### F. Eintrag ausfüllen und einreichen (1 Stunde)

1. In App Store Connect bei der App die Version **1.0** öffnen.
2. Bildschirmfotos (6,9 Zoll) hochladen, siehe `bildschirmfotos.md`.
3. Werbetext, Beschreibung, Schlagwörter, Support-URL, Copyright aus `store-texte.md` einfügen.
4. Unter **Build** den hochgeladenen Build auswählen.
5. **App Review Information**: „Anmeldung erforderlich“ aus, Kontakt und Notizen aus `store-texte.md`.
6. **App-Informationen**: Kategorie, Altersfreigabe, Inhaltsrechte; **App-Datenschutz**: „Keine Daten erhoben“; **Preise und Verfügbarkeit**: kostenlos, Länder.
7. Bei **Freigabe der Version** am besten **Manuell** wählen, dann entscheidest du nach der Prüfung selbst, wann die App erscheint.
8. **Zur Prüfung hinzufügen** › **Zur Prüfung einreichen**.

Die Prüfung dauert meist 1 bis 3 Tage. Bei einer Ablehnung schreibt Apple den Grund ins **Resolution Center**. Schick mir den Text, dann kümmere ich mich darum.

## Häufige Gründe für Ablehnungen und wie Zyklus damit umgeht

| Grund | Stand |
|---|---|
| Datenschutzerklärung fehlt in App oder Store | Link in den Einstellungen und im Store |
| Medizinische Aussagen ohne Hinweis | Hinweis „kein medizinischer Rat, nicht zur Verhütung“ in App, Beschreibung und Hilfe |
| App stürzt ab oder Seiten sind leer | Leere Seiten zeigen einen Hinweis; vor dem Einreichen mit TestFlight testen |
| Platzhalter-Texte oder Testdaten | Demodaten nur auf Wunsch; Platzhalter auf den Webseiten vorher ersetzen |
| Zu wenig Funktionen | Kein Problem, die App hat genug eigene Funktionen |
