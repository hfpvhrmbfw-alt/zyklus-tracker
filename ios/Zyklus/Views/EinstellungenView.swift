// Einstellungen: Sicherung, Standardwerte, Darstellung, Demodaten, alles löschen.

import SwiftUI
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
