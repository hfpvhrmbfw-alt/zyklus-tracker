// Drei Bereiche in der Leiste unten, Einstellungen über das Symbol oben rechts. Beim ersten Start die Begrüßung.

import SwiftUI
import ZyklusKit

enum Tab: Hashable { case heute, kalender, analyse }

/// Welcher Tag gerade im Eintragsblatt offen ist
struct EditDay: Identifiable { let n: DayNum; var id: DayNum { n } }

struct RootView: View {
  @Environment(EntryStore.self) private var store
  @State private var tab: Tab = .heute
  @State private var editing: EditDay?
  @State private var showSettings = false

  var body: some View {
    TabView(selection: $tab) {
      screen(HeuteView(open: { editing = EditDay(n: $0) }, showMonth: { tab = .kalender }))
        .tabItem { Label("Heute", systemImage: "house") }.tag(Tab.heute)
      screen(KalenderView(open: { editing = EditDay(n: $0) }))
        .tabItem { Label("Kalender", systemImage: "calendar") }.tag(Tab.kalender)
      screen(AnalyseView(open: { editing = EditDay(n: $0) }, showCalendar: { tab = .kalender }))
        .tabItem { Label("Analyse", systemImage: "chart.bar") }.tag(Tab.analyse)
    }
    .sheet(item: $editing) { DayEditor(start: $0.n) }
    .sheet(isPresented: $showSettings) { EinstellungenView() }
    .fullScreenCover(isPresented: Binding(get: { !store.onboarded }, set: { _ in })) { IntroView() }
  }

  /// Gemeinsamer Rahmen: Hintergrund, Zweige oben, Einstellungen-Knopf
  private func screen<V: View>(_ content: V) -> some View {
    NavigationStack {
      ZStack(alignment: .top) {
        Theme.bg.ignoresSafeArea()
        Sprigs()
        content
      }
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button { showSettings = true } label: { Image(systemName: "slider.horizontal.3") }
            .accessibilityLabel("Einstellungen und Backup")
            .foregroundStyle(Theme.ink)
        }
      }
      .toolbarBackground(.hidden, for: .navigationBar)
    }
  }
}

/// Gemalte Zweige in den oberen Ecken
struct Sprigs: View {
  var body: some View {
    HStack {
      Image("zweig-ecke").resizable().scaledToFit().frame(width: 92)
      Spacer()
      Image("zweig-ecke").resizable().scaledToFit().frame(width: 92).scaleEffect(x: -1)
    }
    .ignoresSafeArea(edges: .top)
    .allowsHitTesting(false)
    .accessibilityHidden(true)
  }
}

/// Seitenkopf: große Überschrift und Datum
struct PageHead: View {
  let title: String
  let sub: String
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title).font(.serif(34, relativeTo: .largeTitle)).foregroundStyle(Theme.ink)
      Text(sub).font(.sans(15)).foregroundStyle(Theme.muted)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.top, 40)
  }
}
