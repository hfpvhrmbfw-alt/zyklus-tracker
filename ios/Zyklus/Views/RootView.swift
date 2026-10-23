// Drei Bereiche in der eigenen Leiste unten, Einstellungen über das Symbol oben rechts. Beim ersten Start die Begrüßung.

import SwiftUI
import ZyklusKit

enum Tab: Hashable { case heute, kalender, analyse }

/// Welcher Tag gerade im Eintragsblatt offen ist
struct EditDay: Identifiable { let n: DayNum; var id: DayNum { n } }

struct RootView: View {
  @Environment(EntryStore.self) private var store
  @State private var tab: Tab = RootView.startTab
  @State private var editing: EditDay?
  @State private var showSettings = false

  var body: some View {
    ZStack {
      page(.heute) { HeuteView(open: { editing = EditDay(n: $0) }, showMonth: { tab = .kalender }) }
      page(.kalender) { KalenderView(open: { editing = EditDay(n: $0) }) }
      page(.analyse) { AnalyseView(open: { editing = EditDay(n: $0) }, showCalendar: { tab = .kalender }) }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) { TabBar(tab: $tab) }
    .sheet(item: $editing) { DayEditor(start: $0.n) }
    .sheet(isPresented: $showSettings) { EinstellungenView() }
    .fullScreenCover(isPresented: Binding(get: { !store.onboarded }, set: { _ in })) { IntroView() }
  }

  /// Start-Bereich, für Bildschirmfotos über das Startargument -tab kalender|analyse wählbar
  static var startTab: Tab {
    let a = ProcessInfo.processInfo.arguments
    guard let i = a.firstIndex(of: "-tab"), i + 1 < a.count else { return .heute }
    return ["kalender": .kalender, "analyse": .analyse][a[i + 1]] ?? .heute
  }

  /// Alle drei Bereiche bleiben geladen (Scrollposition bleibt erhalten), sichtbar ist nur der gewählte
  private func page<V: View>(_ t: Tab, @ViewBuilder _ content: () -> V) -> some View {
    let on = tab == t
    return screen(content()).opacity(on ? 1 : 0).allowsHitTesting(on).accessibilityHidden(!on)
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

/// Schwebende Leiste unten wie in der Web-App (statt der System-Leiste, die je nach iOS-Version anders aussieht)
struct TabBar: View {
  @Binding var tab: Tab
  private struct Item: Identifiable { let id: Tab; let label: String; let icon: String }
  private let items = [Item(id: .heute, label: "Heute", icon: "house"), Item(id: .kalender, label: "Kalender", icon: "calendar"), Item(id: .analyse, label: "Analyse", icon: "chart.bar")]

  var body: some View {
    HStack(spacing: 0) {
      ForEach(items) { item in
        let on = tab == item.id
        Button { tab = item.id } label: {
          VStack(spacing: 3) {
            Image(systemName: item.icon).font(.system(size: 18, weight: on ? .semibold : .regular))
              .frame(width: 48, height: 30)
              .background(Capsule().fill(on ? Theme.sageTint : .clear))
            Text(item.label).font(.sans(11, on ? .semibold : .medium))
          }
          .foregroundStyle(on ? Theme.ink : Theme.muted)
          .frame(maxWidth: .infinity, minHeight: 52)
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isSelected] : [])
      }
    }
    .padding(5)
    .frame(width: 300)
    .background(RoundedRectangle(cornerRadius: 22).fill(Theme.surface).shadow(color: .black.opacity(0.12), radius: 14, y: 6))
    .overlay(RoundedRectangle(cornerRadius: 22).stroke(Theme.line, lineWidth: 1))
    .padding(.bottom, 4)
    .animation(.easeOut(duration: 0.15), value: tab)
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
