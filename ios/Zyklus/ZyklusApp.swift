// Start der App: Speicher anlegen, Farbschema anwenden, beim Zurückkehren „heute“ neu bestimmen.

import SwiftUI

@main
struct ZyklusApp: App {
  @State private var store: EntryStore
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let s = EntryStore()
    // Für Bildschirmfotos und Tests: mit -demo startet die App mit Beispieldaten
    if ProcessInfo.processInfo.arguments.contains("-demo") { s.loadDemo() }
    _store = State(initialValue: s)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .preferredColorScheme(store.settings.theme == "light" ? .light : store.settings.theme == "dark" ? .dark : nil)
        .tint(Theme.accent)
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.refreshToday() }
    }
  }
}
