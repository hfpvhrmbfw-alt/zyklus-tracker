# Antworten für die Fragebögen in App Store Connect

App Store Connect stellt beim ersten Einreichen einige Fragen. Hier steht, was du für Zyklus jeweils anklickst und warum.

## 1. App-Datenschutz („App Privacy“)

Zu finden unter: App › **App-Datenschutz** › „Los geht's“.

| Frage | Antwort |
|---|---|
| Erheben du oder deine Drittanbieter Daten von dieser App? | **Nein, wir erheben keine Daten von dieser App.** |
| Datenschutzrichtlinie-URL | https://hfpvhrmbfw-alt.github.io/zyklus-tracker/datenschutz.html |

Danach „Veröffentlichen“ klicken. Im App Store steht dann **„Keine Daten erfasst“**.

**Warum das stimmt:** Apple zählt nur Daten als „erhoben“, die die App vom Gerät wegschickt, also an dich oder an Dritte. Zyklus schickt nichts weg: kein Server, keine Analyse, keine Absturzberichte über fremde Dienste, keine Werbung. Die Einträge bleiben auf dem iPhone. Die Zahlen, die Apple selbst sammelt (Downloads, Abstürze, wenn Nutzerinnen zugestimmt haben), zählen hier nicht mit.

**Wichtig für später:** Wenn die App irgendwann etwas ins Netz schickt (zum Beispiel ein Sync, ein Analyse-Werkzeug oder Absturzberichte über einen fremden Dienst), müssen diese Antworten und die Datenschutzerklärung angepasst werden, bevor das Update eingereicht wird.

Passend dazu liegt in der App die Datei `ios/Zyklus/Resources/PrivacyInfo.xcprivacy`. Apple verlangt sie seit 2024. Sie sagt dasselbe in Maschinensprache: kein Tracking, keine erhobenen Daten. Einzige Angabe: Die App liest das Änderungsdatum ihrer eigenen Sicherungsdateien, um alte Sicherungen nach 10 Tagen zu löschen (Grund „C617.1“).

## 2. Altersfreigabe („Age Rating“)

Zu finden unter: App › **App-Informationen** › Altersfreigabe › Bearbeiten.

| Thema | Antwort |
|---|---|
| Gewalt, Horror, Waffen, Glücksspiel, Alkohol/Drogen, Nacktheit, sexuelle Inhalte, Schimpfwörter | **Keine** |
| Medizinische oder Behandlungsinformationen | **Selten/leicht** (die App schätzt Periode, Eisprung und fruchtbares Fenster) |
| Gesundheits- oder Wellness-Themen (falls gefragt) | **Ja** |
| Inhalte von Nutzerinnen, die andere sehen (Chat, Profile, Austausch) | **Nein** |
| Uneingeschränkter Zugang zum Internet (Browser) | **Nein** |
| Werbung | **Nein** |
| Elternkontrolle, Altersprüfung | **Nein** |
| Wettbewerbe, Lootboxen | **Nein** |

Apple berechnet die Altersfreigabe aus diesen Antworten selbst. Bei „selten“ für medizinische Informationen liegt sie voraussichtlich bei 12+ oder 13+. Das ist für eine Zyklus-App passend und verhindert Rückfragen bei der Prüfung.

## 3. Verschlüsselung („Export Compliance“)

Ist schon erledigt: In `ios/project.yml` steht `ITSAppUsesNonExemptEncryption: false`. Damit fragt App Store Connect beim Hochladen nicht mehr nach. Die App nutzt keine eigene Verschlüsselung.

## 4. Inhaltsrechte („Content Rights“)

| Frage | Antwort |
|---|---|
| Enthält oder nutzt die App Inhalte Dritter? | **Nein** |

Die Schriften (DM Serif Display, Outfit) stehen unter der SIL Open Font License und dürfen in Apps eingebaut werden. Die Illustrationen sind deine eigenen.

## 5. Händlerstatus in der EU („Trader Status“, Digital Services Act)

Zu finden unter: **Business** (früher „Verträge, Steuern und Bankwesen“) bzw. beim ersten Einrichten der App.

- **Kein Händler (Non-Trader):** wenn du die App privat und kostenlos anbietest, ohne geschäftliche Absicht. Dann werden keine Kontaktdaten im App Store angezeigt.
- **Händler (Trader):** wenn du damit Geld verdienst oder es beruflich machst. Dann zeigt Apple deine Adresse, Telefonnummer und E-Mail im App Store an (in der EU Pflicht).

Ohne diese Angabe ist die App in der EU nicht verfügbar. Bei Unsicherheit ist eine kurze Rückfrage bei einer Steuerberatung sinnvoll. Ich kann das nicht verbindlich beurteilen.

## 6. Preis und Verfügbarkeit

- Preis: **Kostenlos** (dann sind keine Steuer- und Bankangaben nötig)
- Länder: zunächst **Deutschland, Österreich, Schweiz**, weil die App nur Deutsch kann. Alle Länder geht auch, dann sollte in der Beschreibung stehen, dass die App auf Deutsch ist.
