// Tag erfassen: Blutung, Stimmung, Gefühle, Energie, Körper, Notiz. Speichert bei jeder Änderung.

import SwiftUI
import ZyklusKit

struct DayEditor: View {
  @Environment(EntryStore.self) private var store
  @Environment(\.dismiss) private var dismiss
  @State private var n: DayNum
  @State private var e: DayEntry
  @State private var confirmClear = false

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
            ForEach(Model.moods, id: \.self) { v in
              Chip(label: Texts.mood[v]!, selected: e.moods.contains(v)) { edit { $0.moods.toggle(v, order: Model.moods) } }
            }
          }
          group("Energie") {
            ForEach(Model.energy, id: \.self) { v in
              Chip(label: Texts.energy[v], selected: e.energy == v) { edit { $0.energy = v } }
            }
          }
          group("Körper") {
            ForEach(Model.symptoms, id: \.self) { v in
              Chip(label: Texts.symptom[v]!, selected: e.symptoms.contains(v)) { edit { $0.symptoms.toggle(v, order: Model.symptoms) } }
            }
          }
          VStack(alignment: .leading, spacing: 8) {
            Text("Notiz").font(.serif(19))
            TextField("Was war heute los?", text: Binding(get: { e.note }, set: { v in edit { $0.note = String(v.prefix(Model.noteMax)) } }), axis: .vertical)
              .lineLimit(4...10)
              .font(.sans(16))
              .padding(12)
              .background(Theme.bg, in: RoundedRectangle(cornerRadius: 14))
              .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line))
          }
          .card(padding: 18)
          HStack {
            Text("Änderungen werden automatisch gespeichert").font(.sans(14)).foregroundStyle(Theme.muted)
            Spacer()
            Button("Tag leeren") { confirmClear = true }.buttonStyle(.pillGhostSmall).disabled(e.isEmpty)
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
      .confirmationDialog("Alle Angaben für diesen Tag löschen?", isPresented: $confirmClear, titleVisibility: .visible) {
        Button("Tag leeren", role: .destructive) { edit { $0 = .blank($0.date) } }
      }
      .onAppear { e = store.entry(n) }
      .onChange(of: n) { _, v in e = store.entry(v) }
    }
  }

  /// Ändert den Eintrag und speichert sofort
  private func edit(_ change: (inout DayEntry) -> Void) {
    change(&e)
    store.save(e)
  }

  private var dayNav: some View {
    let ph = Logic.phaseOf(store.analysis, n)
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
