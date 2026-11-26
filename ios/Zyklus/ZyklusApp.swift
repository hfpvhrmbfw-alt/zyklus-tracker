// Start der App: Speicher anlegen, Farbschema anwenden, beim Zurückkehren „heute“ neu bestimmen,
// Erinnerungen neu planen und (falls eingeschaltet) die Sperre zeigen.

import SwiftUI

@main
struct ZyklusApp: App {
  @State private var store: EntryStore
  /// Sperre aktiv: Inhalt verdeckt, bis entsperrt
  @State private var locked: Bool
  @Environment(\.scenePhase) private var scenePhase

  init() {
    let s = EntryStore()
    // Für Bildschirmfotos und Tests: mit -demo startet die App mit Beispieldaten
    if ProcessInfo.processInfo.arguments.contains("-demo") { s.loadDemo() }
    _store = State(initialValue: s)
    _locked = State(initialValue: s.prefs.lock)
  }

  var body: some Scene {
    WindowGroup {
      RootView()
        .environment(store)
        .overlay { if locked || (store.prefs.lock && scenePhase != .active) { LockView(locked: $locked) } }
        .preferredColorScheme(store.settings.theme == "light" ? .light : store.settings.theme == "dark" ? .dark : nil)
        .tint(Theme.accent)
        .onAppear(perform: reschedule)
        .onChange(of: store.days) { _, _ in reschedule() }
        .onChange(of: store.settings) { _, _ in reschedule() }
        .onChange(of: store.prefs) { _, _ in reschedule() }
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { store.refreshToday(); reschedule() }
      if phase == .background && store.prefs.lock { locked = true }
    }
  }

  private func reschedule() {
    Reminders.schedule(prefs: store.prefs, analysis: store.analysis, paused: store.settings.pause, today: store.today)
  }
}

/// Verdeckt die App, bis mit Face ID, Touch ID oder Code entsperrt wurde. Ohne „locked“ nur als Sichtschutz in der App-Übersicht.
struct LockView: View {
  @Binding var locked: Bool
  @Environment(\.scenePhase) private var scenePhase
  /// Schon einmal von selbst gefragt? Nach „Abbrechen“ nicht in Schleife neu fragen, erst nach Rückkehr aus dem Hintergrund.
  @State private var asked = false

  var body: some View {
    ZStack {
      Theme.bg.ignoresSafeArea()
      VStack(spacing: 18) {
        Image("phase-start").resizable().scaledToFit().frame(maxWidth: 200).accessibilityHidden(true)
        Text("Zyklus ist gesperrt").font(.serif(28))
        if locked {
          Button("Entsperren") { unlock() }.buttonStyle(.pill)
        }
      }
      .padding(Theme.gutter)
    }
    .onAppear { autoUnlock() }
    .onChange(of: scenePhase) { _, p in
      if p == .background { asked = false }
      if p == .active { autoUnlock() }
    }
  }

  private func autoUnlock() {
    guard locked, scenePhase == .active, !asked else { return }
    asked = true
    unlock()
  }

  private func unlock() {
    Task { if await AppLock.unlock() { locked = false } }
  }
}
