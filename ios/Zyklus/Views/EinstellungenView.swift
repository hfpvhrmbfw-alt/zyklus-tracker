// Einstellungen: Sicherung, Standardwerte, Darstellung, Demodaten, alles löschen.

import SwiftUI
import UIKit
import UniformTypeIdentifiers
import ZyklusKit

struct EinstellungenView: View {
  @Environment(EntryStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var exporting = false
  @State private var importing = false
  @State private var confirmDemo = false
  @State private var confirmWipe = false
  @State private var message: String?
  /// Mitteilungen in den iPhone-Einstellungen ausgeschaltet
  @State private var notifDenied = false

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Text("Deine Einträge liegen nur auf diesem iPhone. Es gibt keinen Server und kein Konto.")
          Text("Nach jeder Änderung legt die App eine Sicherung in der Dateien-App ab: **Auf meinem iPhone › Zyklus**. Die letzten \(EntryStore.keepBackups) Tage bleiben erhalten.")
          if let b = store.lastBackup { LabeledContent("Letzte Sicherung", value: Texts.long(b)) }
          Button("Backup an anderem Ort sichern …") { exporting = true }
          Button("Backup einlesen …") { importing = true }
        } header: { Text("Sicherung") } footer: {
          Text("Am besten ab und zu eine Sicherung in die iCloud oder auf einen anderen Speicher legen. Beim Löschen der App verschwindet auch der Ordner auf dem iPhone.")
        }

        Section {
          Stepper("Zykluslänge: \(store.settings.cycleLen) Tage", value: binding(\.cycleLen), in: 15...60)
          Stepper("Periodendauer: \(store.settings.periodLen) Tage", value: binding(\.periodLen), in: 1...12)
          Stepper("Lutealphase: \(store.settings.luteal) Tage", value: binding(\.luteal), in: 8...18)
        } header: { Text("Zyklus") } footer: { Text("Die Standardwerte gelten, solange es noch zu wenige eigene Zyklen gibt.") }

        Section {
          Toggle("Vorhersagen pausieren", isOn: binding(\.pause)).tint(Theme.sage)
        } header: { Text("Vorhersagen") } footer: {
          Text("Zum Beispiel in der Schwangerschaft, in der Stillzeit, mit der Pille oder in den Wechseljahren. Du kannst weiter alles eintragen, die App schätzt dann keine Periode, keine fruchtbaren Tage und keinen Eisprung.")
        }

        Section {
          Toggle("Vor der Periode", isOn: reminder(\.remindPeriod)).tint(Theme.sage)
          Toggle("Täglich ans Eintragen", isOn: reminder(\.remindDaily)).tint(Theme.sage)
          if store.prefs.remindDaily {
            DatePicker("Uhrzeit", selection: dailyTime, displayedComponents: .hourAndMinute)
          }
          if notifDenied {
            Button("Mitteilungen in den iPhone-Einstellungen erlauben …") {
              if let u = URL(string: UIApplication.openNotificationSettingsURLString) { UIApplication.shared.open(u) }
            }
          }
        } header: { Text("Erinnerungen") } footer: {
          Text("„Vor der Periode“ erinnert zwei Tage vor der erwarteten Periode um 9 Uhr. Die Erinnerungen entstehen auf dem iPhone, es wird nichts verschickt.")
        }

        Section {
          Toggle("Mit Face ID oder Code sperren", isOn: lockBinding).tint(Theme.sage)
        } header: { Text("Sperre") } footer: {
          Text("Beim Öffnen fragt die App nach Face ID, Touch ID oder dem Code deines iPhones. In der App-Übersicht sind deine Einträge dann verdeckt.")
        }

        Section("Darstellung") {
          Picker("Farbschema", selection: binding(\.theme)) {
            ForEach(Model.themes, id: \.self) { Text(Texts.theme[$0]!).tag($0) }
          }
        }

        Section {
          Button("Demodaten laden") { if store.days.isEmpty { store.loadDemo() } else { confirmDemo = true } }
          Button("Alle Daten löschen", role: .destructive) { confirmWipe = true }
        } header: { Text("Ausprobieren und löschen") } footer: {
          Text("Demodaten sind erfundene Beispielwerte über sechs Monate.")
        }

        Section {
          Text(Texts.disclaimer).font(.sans(13)).foregroundStyle(Theme.muted)
          LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–")
        }

        Section("Rechtliches") {
          Link("Datenschutz", destination: Texts.datenschutzURL)
          Link("Hilfe und Kontakt", destination: Texts.hilfeURL)
          Link("Impressum", destination: Texts.impressumURL)
        }
      }
      .font(.sans(16))
      .scrollContentBackground(.hidden)
      .background(Theme.bg)
      .navigationTitle("Einstellungen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
      .fileExporter(isPresented: $exporting, document: BackupDocument(data: (try? store.backupData()) ?? Data()),
                    contentType: .json, defaultFilename: String(EntryStore.backupName(store.today).dropLast(5))) { result in
        if case .success = result { message = "Backup gespeichert." }
      }
      .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
        guard case let .success(url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { message = Texts.importError[.invalidJSON]; return }
        switch store.importBackup(data) {
        case let .success(n): message = "\(Texts.plural(n, "Eintrag", "Einträge")) eingelesen."
        case let .failure(e): message = Texts.importError[e]
        }
      }
      .confirmationDialog("Demodaten ersetzen alle vorhandenen Einträge. Vorher am besten ein Backup sichern.", isPresented: $confirmDemo, titleVisibility: .visible) {
        Button("Demodaten laden", role: .destructive) { store.loadDemo() }
      }
      .confirmationDialog("Wirklich alle Einträge auf diesem iPhone löschen? Das lässt sich nicht rückgängig machen.", isPresented: $confirmWipe, titleVisibility: .visible) {
        Button("Alle Daten löschen", role: .destructive) { store.wipe() }
      }
      .alert(message ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
        Button("OK") { message = nil }
      }
    }
  }

  /// Erinnerung an- oder ausschalten. Beim Einschalten erst nach der Erlaubnis für Mitteilungen fragen.
  private func reminder(_ key: WritableKeyPath<DevicePrefs, Bool>) -> Binding<Bool> {
    Binding(get: { store.prefs[keyPath: key] }, set: { on in
      if !on { var p = store.prefs; p[keyPath: key] = false; store.update(prefs: p); return }
      Task {
        let ok = await Reminders.requestPermission()
        notifDenied = !ok
        if ok { var p = store.prefs; p[keyPath: key] = true; store.update(prefs: p) }
      }
    })
  }

  /// Uhrzeit der täglichen Erinnerung
  private var dailyTime: Binding<Date> {
    Binding(get: {
      Calendar.current.date(bySettingHour: store.prefs.dailyMinute / 60, minute: store.prefs.dailyMinute % 60, second: 0, of: Date()) ?? Date()
    }, set: { d in
      let c = Calendar.current.dateComponents([.hour, .minute], from: d)
      var p = store.prefs; p.dailyMinute = (c.hour ?? 20) * 60 + (c.minute ?? 0); store.update(prefs: p)
    })
  }

  /// Sperre: zum Einschalten einmal entsperren (prüft, dass Face ID oder Code eingerichtet ist und funktioniert)
  private var lockBinding: Binding<Bool> {
    Binding(get: { store.prefs.lock }, set: { on in
      if !on { var p = store.prefs; p.lock = false; store.update(prefs: p); return }
      guard AppLock.available else { message = "Bitte richte zuerst in den iPhone-Einstellungen einen Code ein (Face ID & Code)."; return }
      Task {
        if await AppLock.unlock(reason: "Sperre für Zyklus einschalten") { var p = store.prefs; p.lock = true; store.update(prefs: p) }
      }
    })
  }

  /// Bindung an ein Feld der Einstellungen, speichert sofort
  private func binding<V>(_ key: WritableKeyPath<Settings, V>) -> Binding<V> {
    Binding(get: { store.settings[keyPath: key] }, set: { v in var s = store.settings; s[keyPath: key] = v; store.update(settings: s) })
  }
}

/// Backup-Datei für „Sichern unter“
struct BackupDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.json] }
  var data: Data
  init(data: Data) { self.data = data }
  init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
