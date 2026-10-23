// Monatskalender: eingetragene Perioden, Schätzungen, fruchtbares Fenster, Stimmungspunkte. Tippen öffnet den Tag.

import SwiftUI
import ZyklusKit

struct KalenderView: View {
  @Environment(EntryStore.self) private var store
  let open: (DayNum) -> Void
  @State private var month: (y: Int, m: Int)?

  var body: some View {
    let t = store.today
    let ym = month ?? (Day.ymd(t).0, Day.ymd(t).1)
    let y = ym.y, m = ym.m
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        PageHead(title: "Kalender", sub: Texts.dayMonth(t))
        VStack(spacing: 16) {
          HStack {
            Button { shift(-1, y, m) } label: { Image(systemName: "arrow.left") }.buttonStyle(RoundButton()).accessibilityLabel("Vorheriger Monat")
            Spacer()
            Text("\(Texts.months[m - 1]) \(String(y))").font(.serif(21))
            Spacer()
            Button { shift(1, y, m) } label: { Image(systemName: "arrow.right") }.buttonStyle(RoundButton()).accessibilityLabel("Nächster Monat")
          }
          grid(y, m, t)
        }
        .card(padding: 14)
        if store.days.isEmpty {
          EmptyCard(image: "kachel-tropfen", title: "Dein Kalender ist noch leer",
                    text: "Tipp auf einen Tag, um Blutung, Stimmung und mehr einzutragen. Vergangene Perioden kannst du so auch nachtragen.",
                    button: "Heute eintragen") { open(t) }
        }
        VStack(alignment: .leading, spacing: 12) {
          SectionHead("Legende")
          legend
        }
      }
      .padding(.horizontal, Theme.gutter)
      .padding(.bottom, 32)
    }
  }

  private func shift(_ d: Int, _ y: Int, _ m: Int) {
    let i = y * 12 + (m - 1) + d
    month = (i / 12, i % 12 + 1)
  }

  private func grid(_ y: Int, _ m: Int, _ t: DayNum) -> some View {
    let first = Day.num(year: y, month: m, day: 1), last = Day.num(year: y, month: m + 1, day: 1) - 1
    let lead = Day.weekday(first)
    let an = store.analysis
    let cols = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
    return LazyVGrid(columns: cols, spacing: 5) {
      ForEach(Texts.weekdayShort, id: \.self) { Text($0.uppercased()).font(.sans(11, .medium)).foregroundStyle(Theme.faint) }
      ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 1) }
      ForEach(first...last, id: \.self) { n in
        DayCell(n: n, e: store.days[Day.str(n)], ph: Logic.phaseOf(an, n), today: t) { open(n) }
      }
    }
  }

  private var legend: some View {
    VStack(spacing: 0) {
      row(AnyView(Swatch(fill: Theme.accent, text: "P", textColor: Theme.accentInk)), "Periode (eingetragen)")
      row(AnyView(Swatch(text: "·", underline: true)), "Schmierblutung")
      row(AnyView(Swatch(text: "p", dashed: true)), "Periode erwartet (Schätzung)")
      row(AnyView(Swatch(fill: Theme.sageTint, text: "F")), "Fruchtbares Fenster, E Eisprung (Schätzung)")
      row(AnyView(Swatch(text: "•")), "Gefühle, Körper oder Notiz eingetragen")
      row(AnyView(HStack(spacing: 3) { ForEach(Model.stimmung, id: \.self) { Circle().fill(Theme.mood($0)).frame(width: 7, height: 7) } }.frame(width: 40)),
          "Stimmung: grün gut, gelb ist ok, rot schlecht, lila nur abends. Ohne Angabe aus den Gefühlen abgeleitet.", last: true)
    }
    .card(padding: 6)
  }

  private func row(_ icon: AnyView, _ text: String, last: Bool = false) -> some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) { icon; Text(text).font(.sans(14)); Spacer(minLength: 0) }.padding(.horizontal, 12).padding(.vertical, 12)
      if !last { Divider().overlay(Theme.lineSoft) }
    }
  }
}

/// Ein Tag im Kalender
struct DayCell: View {
  let n: DayNum
  let e: DayEntry?
  let ph: DayPhase?
  let today: DayNum
  let action: () -> Void

  var body: some View {
    let period = (e?.flow ?? 0) >= Model.flowPeriod, spot = e?.flow == 1
    let pred = !period && !spot && ph?.phase == .men && n > today
    let fertile = ph?.fertile == true && !period
    let dots = e.map(Logic.moodDots) ?? []
    var marks: [String] = []
    if period { marks.append("P") } else if spot { marks.append("·") } else if pred { marks.append("p") }
    if fertile { marks.append(ph?.ovu == true ? "E" : "F") }
    if e?.hasDetail == true { marks.append("•") }
    return Button(action: action) {
      ZStack(alignment: .topLeading) {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(period ? Theme.accent : fertile ? Theme.sageTint : .clear)
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .strokeBorder(n == today ? Theme.ink : pred ? Theme.accent : Theme.lineSoft,
                        style: StrokeStyle(lineWidth: n == today || pred ? 1.5 : 1, dash: pred && n != today ? [4, 3] : []))
        if spot { VStack { Spacer(); Theme.accent.frame(height: 4) }.clipShape(RoundedRectangle(cornerRadius: 12)) }
        Text("\(Day.ymd(n).2)").font(.sans(14, .medium)).padding(5)
        if !dots.isEmpty {
          LazyVGrid(columns: [GridItem(.fixed(6), spacing: 2), GridItem(.fixed(6), spacing: 2)], spacing: 2) {
            ForEach(dots, id: \.self) { Circle().fill(Theme.mood($0)).frame(width: 6, height: 6) }
          }
          .frame(width: 14).frame(maxWidth: .infinity, alignment: .topTrailing).padding(5)
        }
        Text(marks.joined(separator: " ")).font(.sans(9, .semibold))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing).padding(5)
      }
      .foregroundStyle(period ? Theme.accentInk : Theme.ink)
      .aspectRatio(1, contentMode: .fit)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(label(period: period, spot: spot, pred: pred, fertile: fertile, dots: dots))
  }

  private func label(period: Bool, spot: Bool, pred: Bool, fertile: Bool, dots: [String]) -> String {
    var a = [Texts.long(n)]
    if period, let e { a.append("Periode " + Texts.flow[e.flow]) } else if spot { a.append("Schmierblutung") } else if pred { a.append("Periode erwartet") }
    if fertile { a.append(ph?.ovu == true ? "Eisprung geschätzt" : "fruchtbar geschätzt") }
    if !dots.isEmpty { a.append("Stimmung " + dots.compactMap { Texts.stimmung[$0] }.joined(separator: ", ")) }
    if e?.hasDetail == true { a.append("Einträge vorhanden") }
    if n == today { a.append("heute") }
    return a.joined(separator: ", ")
  }
}

/// Kästchen in der Legende
struct Swatch: View {
  var fill: Color = .clear
  var text: String
  var textColor: Color = Theme.ink
  var dashed = false
  var underline = false
  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8).fill(fill)
      RoundedRectangle(cornerRadius: 8).strokeBorder(dashed ? Theme.accent : Theme.lineSoft, style: StrokeStyle(lineWidth: dashed ? 1.5 : 1, dash: dashed ? [3, 2] : []))
      if underline { VStack { Spacer(); Theme.accent.frame(height: 4) }.clipShape(RoundedRectangle(cornerRadius: 8)) }
      Text(text).font(.sans(10, .semibold)).foregroundStyle(textColor)
    }
    .frame(width: 26, height: 26)
    .frame(width: 40)
  }
}
