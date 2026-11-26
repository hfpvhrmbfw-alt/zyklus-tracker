// Tag erfassen: Blutung, Stimmung, Gefühle, Energie, Körper; aufklappbar Medikamente, Sex, Ausfluss, Notiz.
// Gefühle und Körper zeigen zuerst die drei meistgenutzten, der Rest liegt hinter „+ N weitere“. Speichert bei jeder Änderung.

import SwiftUI
import ZyklusKit

struct DayEditor: View {
  @Environment(EntryStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var n: DayNum
  @State private var e: DayEntry
  /// Die drei meistgenutzten Gefühle und Körpersymptome, beim Öffnen eines Tages festgelegt (springen beim Tippen nicht herum)
  @State private var topMoods: [String] = []
  @State private var topSyms: [String] = []
  @State private var allMoods = false
  @State private var allSyms = false
  @State private var moreOpen = false
  /// Nach „Tag leeren“: der alte Eintrag, solange „Rückgängig“ angeboten wird
  @State private var undo: DayEntry?

  /// So viele Möglichkeiten zeigt eine lange Liste zuerst
  static let compact = 3

  init(start: DayNum) {
    _n = State(initialValue: start)
    _e = State(initialValue: .blank(Day.str(start)))
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 10) {
          dayNav
          group("Blutung") {
            ForEach(Model.flow, id: \.self) { v in
              Chip(label: Texts.flow[v], selected: e.flow == v,
                   tint: v >= Model.flowPeriod ? Theme.accent : Theme.sageTint,
                   border: v >= Model.flowPeriod ? Theme.accent : Theme.sage) { edit { $0.flow = v } }
            }
          }
          group("Stimmung") {
            ForEach(Model.stimmung, id: \.self) { v in
              Chip(label: Texts.stimmung[v]!, selected: e.stimmung.contains(v), dot: Theme.mood(v)) { edit { $0.stimmung.toggle(v, order: Model.stimmung) } }
            }
          }
          group("Gefühle") {
            compactChips(Model.moods, top: topMoods, selected: e.moods, expanded: $allMoods, label: { Texts.mood[$0]! }) { v in edit { $0.moods.toggle(v, order: Model.moods) } }
          }
          group("Energie") {
            ForEach(Model.energy.filter { $0 > 0 }, id: \.self) { v in
              Chip(label: Texts.energy[v], selected: e.energy == v) { edit { $0.energy = $0.energy == v ? 0 : v } }
            }
          }
          group("Körper") {
            compactChips(Model.symptoms, top: topSyms, selected: e.symptoms, expanded: $allSyms, label: { Texts.symptom[$0]! }) { v in edit { $0.symptoms.toggle(v, order: Model.symptoms) } }
          }
          more
          HStack {
            Text("Änderungen werden automatisch gespeichert").font(.sans(14)).foregroundStyle(Theme.muted)
            Spacer()
            Button("Tag leeren") { clear() }.buttonStyle(.pillGhostSmall).disabled(e.isEmpty)
          }
          .padding(.top, 6)
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.bottom, 32)
      }
      .background(Theme.bg)
      .navigationTitle("Tag erfassen")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fertig") { dismiss() } } }
      .overlay(alignment: .bottom) { if undo != nil { undoBar.transition(.move(edge: .bottom).combined(with: .opacity)) } }
      .alert("Konnte nicht speichern", isPresented: Binding(get: { store.saveFailed }, set: { if !$0 { store.saveFailed = false } })) {
        Button("OK") { store.saveFailed = false }
      } message: {
        Text("Deine letzte Änderung konnte nicht gespeichert werden. Ist der Speicher deines iPhones voll? Gib etwas Platz frei und versuch es noch einmal.")
      }
      .onAppear { load(n) }
      .onChange(of: n) { _, v in load(v) }
    }
  }

  /// Tag laden: Eintrag, meistgenutzte Auswahl, „Weitere Angaben“ offen, wenn dort etwas steht
  private func load(_ day: DayNum) {
    e = store.entry(day)
    topMoods = Logic.topUsed(store.entries, \.moods, ids: Model.moods, k: Self.compact)
    topSyms = Logic.topUsed(store.entries, \.symptoms, ids: Model.symptoms, k: Self.compact)
    allMoods = false; allSyms = false
    moreOpen = moreFilled > 0
    undo = nil
  }

  /// Wie viele der weiteren Angaben ausgefüllt sind
  private var moreFilled: Int {
    [!e.meds.isEmpty, e.sex != 0, e.discharge != 0, !e.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty].filter { $0 }.count
  }

  /// Tag leeren, mit „Rückgängig“ statt Rückfrage
  private func clear() {
    let old = e
    edit { $0 = .blank($0.date) }
    withAnimation { undo = old }
    Task {
      try? await Task.sleep(for: .seconds(6))
      if undo == old { withAnimation { undo = nil } }
    }
  }

  private var undoBar: some View {
    HStack {
      Text("Tag geleert.").font(.sans(14)).foregroundStyle(Theme.bg)
      Spacer()
      Button("Rückgängig") {
        if let old = undo { e = old; store.restore(old) }
        withAnimation { undo = nil }
      }
      .font(.sans(14, .semibold)).foregroundStyle(Theme.accent).frame(minHeight: 44)
    }
    .padding(.leading, 18).padding(.trailing, 12)
    .background(Theme.ink, in: RoundedRectangle(cornerRadius: 16))
    .padding(.horizontal, 16).padding(.bottom, 12)
  }

  /// Lange Auswahl kompakt: zuerst die meistgenutzten und alle gewählten, der Rest hinter „+ N weitere“
  @ViewBuilder
  private func compactChips(_ ids: [String], top: [String], selected: [String], expanded: Binding<Bool>,
                            label: @escaping (String) -> String, toggle: @escaping (String) -> Void) -> some View {
    let first = top + ids.filter { selected.contains($0) && !top.contains($0) }
    let rest = ids.filter { !first.contains($0) }
    ForEach(first + (expanded.wrappedValue ? rest : []), id: \.self) { v in
      Chip(label: label(v), selected: selected.contains(v)) { toggle(v) }
    }
    if !rest.isEmpty {
      Button { withAnimation(.easeOut(duration: 0.2)) { expanded.wrappedValue.toggle() } } label: {
        Text(expanded.wrappedValue ? "Weniger" : "+ \(rest.count) weitere")
          .font(.sans(14, .medium)).foregroundStyle(Theme.accentText)
          .padding(.horizontal, 15).frame(minHeight: 40)
          .overlay(Capsule().stroke(Theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
          .contentShape(Capsule())
      }
      .buttonStyle(.plain)
    }
  }

  /// Weitere Angaben: Medikamente, Sex, Ausfluss, Notiz (aufklappbar)
  private var more: some View {
    DisclosureGroup(isExpanded: $moreOpen) {
      VStack(alignment: .leading, spacing: 16) {
        sub("Medikamente") {
          ForEach(Model.meds, id: \.self) { v in
            Chip(label: Texts.med[v]!, selected: e.meds.contains(v)) { edit { $0.meds.toggle(v, order: Model.meds) } }
          }
        }
        sub("Sex") {
          ForEach(Model.sex.filter { $0 > 0 }, id: \.self) { v in
            Chip(label: Texts.sex[v], selected: e.sex == v) { edit { $0.sex = $0.sex == v ? 0 : v } }
          }
        }
        sub("Ausfluss") {
          ForEach(Model.discharge.filter { $0 > 0 }, id: \.self) { v in
            Chip(label: Texts.discharge[v], selected: e.discharge == v) { edit { $0.discharge = $0.discharge == v ? 0 : v } }
          }
        }
        VStack(alignment: .leading, spacing: 8) {
          Text("Notiz").font(.sans(14, .medium)).foregroundStyle(Theme.muted)
          TextField("Was war heute los?", text: Binding(get: { e.note }, set: { v in edit { $0.note = String(v.prefix(Model.noteMax)) } }), axis: .vertical)
            .lineLimit(4...10)
            .font(.sans(16))
            .padding(12)
            .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
        }
      }
      .padding(.top, 12)
    } label: {
      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text("Weitere Angaben").font(.serif(19)).foregroundStyle(Theme.ink)
        if moreFilled > 0 { Text("· \(moreFilled) ausgefüllt").font(.sans(14)).foregroundStyle(Theme.muted) }
      }
    }
    .tint(Theme.accentText)
    .card(padding: 18)
  }

  private func sub<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Divider().overlay(Theme.lineSoft)
      Text(title).font(.sans(14, .medium)).foregroundStyle(Theme.muted).accessibilityAddTraits(.isHeader)
      FlowLayout() { content() }
    }
  }

  /// Ändert den Eintrag und speichert sofort
  private func edit(_ change: (inout DayEntry) -> Void) {
    change(&e)
    store.save(e)
  }

  private var dayNav: some View {
    let ph = Logic.phaseShown(store.analysis, n, paused: store.settings.pause)
    return VStack(alignment: .leading, spacing: 10) {
      HStack {
        Button { n -= 1 } label: { Text("←").font(.sans(18)) }.buttonStyle(RoundButton()).accessibilityLabel("Vorheriger Tag")
        Spacer()
        DatePicker("Datum", selection: Binding(get: { date(n) }, set: { n = EntryStore.currentDay($0) }), displayedComponents: .date)
          .labelsHidden()
        Spacer()
        Button { n += 1 } label: { Text("→").font(.sans(18)) }.buttonStyle(RoundButton()).accessibilityLabel("Nächster Tag")
      }
      Text(Texts.long(n) + (n == store.today ? " · heute" : "")).font(.serif(22))
      if let ph {
        FlowLayout() {
          PhaseTag(text: "Zyklustag \(ph.cycleDay)", inverted: true)
          PhaseTag(text: Texts.phaseName[ph.phase]! + (ph.predicted ? " · Schätzung" : ""))
          if ph.fertile { PhaseTag(text: "Fruchtbar · Schätzung", accent: true) }
        }
      }
      if n != store.today { Button("Zu heute") { n = store.today }.buttonStyle(.pillGhostSmall) }
    }
    .card()
  }

  private func date(_ n: DayNum) -> Date {
    let (y, m, d) = Day.ymd(n)
    return Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
  }

  private func group<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title).font(.serif(19)).accessibilityAddTraits(.isHeader)
      FlowLayout() { content() }
    }
    .card(padding: 18)
  }
}

/// Runder Pfeil-Knopf
struct RoundButton: ButtonStyle {
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.system(size: 17, weight: .medium))
      .foregroundStyle(Theme.ink)
      .frame(width: 44, height: 44)
      .background(Circle().fill(configuration.isPressed ? Theme.sunken : .clear))
      .overlay(Circle().stroke(Theme.line))
  }
}

/// Kleines Etikett (Zyklustag, Phase)
struct PhaseTag: View {
  let text: String
  var inverted = false
  var accent = false
  var body: some View {
    Text(text).font(.sans(12, .medium))
      .foregroundStyle(inverted ? Theme.bg : accent ? Theme.accentText : Theme.ink)
      .padding(.horizontal, 11).padding(.vertical, 6)
      .background(Capsule().fill(inverted ? Theme.ink : .clear))
      .overlay(Capsule().stroke(inverted ? Theme.ink : accent ? Theme.accentText : Theme.line))
  }
}

extension Array where Element == String {
  /// Fügt hinzu oder entfernt, Reihenfolge wie in den Stammdaten
  mutating func toggle(_ v: String, order: [String]) {
    if contains(v) { removeAll { $0 == v } } else { self = order.filter { $0 == v || contains($0) } }
  }
}
