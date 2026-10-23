// Startseite: Zykluskarte mit Bild je Phase, Stimmungswoche, Ausblick-Kacheln.

import SwiftUI
import ZyklusKit

/// Bildname je Phase (Platzhalter, bis Annas gemalte Bilder da sind)
func phaseImage(_ p: Phase?) -> String {
  switch p {
  case .men: return "phase-periode"
  case .fol: return "phase-follikel"
  case .ovu: return "phase-eisprung"
  case .lut: return "phase-luteal"
  case nil: return "phase-start"
  }
}

struct HeuteView: View {
  @Environment(EntryStore.self) private var store
  let open: (DayNum) -> Void
  let showMonth: () -> Void

  var body: some View {
    let an = store.analysis, t = store.today
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        PageHead(title: Texts.greeting(Calendar.current.component(.hour, from: Date())), sub: Texts.dayMonth(t))
        if store.demo {
          Note(label: "Demo", text: "Gerade sind Beispieldaten geladen. In den Einstellungen (oben rechts) kannst du sie wieder entfernen.", tint: Theme.accentTint, labelColor: Theme.accentText)
        }
        hero(an, t)
        VStack(alignment: .leading, spacing: 12) {
          SectionHead(title: "Stimmungswoche") {
            Button("Ganzer Monat", action: showMonth).font(.sans(13, .medium)).foregroundStyle(Theme.muted)
          }
          week(t)
        }
        VStack(alignment: .leading, spacing: 12) {
          SectionHead("Ausblick")
          outlook(an, t)
        }
        Note(label: "Hinweis", text: Texts.disclaimer)
      }
      .padding(.horizontal, Theme.gutter)
      .padding(.bottom, 32)
    }
  }

  // ---------- Zykluskarte ----------
  @ViewBuilder private func hero(_ an: Analysis, _ t: DayNum) -> some View {
    let ph = Logic.phaseOf(an, t)
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 8) {
        VStack(alignment: .leading, spacing: 6) {
          Text(heroSub(an, t, ph)).font(.sans(13)).foregroundStyle(Theme.muted)
          Text(an.current.map { "Tag \($0.day)" } ?? "Schön, dass du da bist").font(.serif(30)).foregroundStyle(Theme.ink)
          Button("Tag eintragen  →") { open(t) }.buttonStyle(.pill).padding(.top, 6)
        }
        Spacer(minLength: 0)
        Image(phaseImage(ph?.phase)).resizable().scaledToFit().frame(maxWidth: 160)
          .offset(x: 18, y: -30).padding(.bottom, -30).accessibilityHidden(true)
      }
      Divider().overlay(Theme.lineSoft)
      Text(heroLede(an)).font(.sans(14)).foregroundStyle(Theme.muted)
    }
    .card()
    .accessibilityElement(children: .contain)
  }

  private func heroSub(_ an: Analysis, _ t: DayNum, _ ph: DayPhase?) -> String {
    guard let c = an.current else { return "Tage · Gefühle · Muster" }
    let when: String
    if c.inPeriod { when = "Periode läuft" }
    else if c.overdue > 0 { when = "\(Texts.plural(c.overdue, "Tag", "Tage")) später als erwartet" }
    else if c.next == t { when = "Periode heute erwartet" }
    else { when = "Periode in \(Texts.plural(c.next - t, "Tag", "Tagen"))" }
    return [ph.map { Texts.phaseName[$0.phase]! } ?? "Zyklus", when, c.inPeriod ? nil : "Schätzung"].compactMap { $0 }.joined(separator: " · ")
  }

  private func heroLede(_ an: Analysis) -> String {
    if an.current == nil { return "Trag den ersten Tag deiner letzten Periode ein. Ab zwei Periodenstarts siehst du Durchschnittswerte, Vorhersagen und Muster." }
    if let avg = an.avgCycle { return "Berechnet aus \(Texts.plural(an.recent.count, "Zyklus", "Zyklen")) mit durchschnittlich \(Texts.dec(avg)) Tagen." }
    return "Noch kein vollständiger Zyklus erfasst. Bis dahin rechnet die App mit \(an.C) Tagen (änderbar in den Einstellungen)."
  }

  // ---------- Stimmungswoche ----------
  private func week(_ t: DayNum) -> some View {
    let mon = t - Day.weekday(t)
    return HStack(spacing: 4) {
      ForEach(0..<7, id: \.self) { i in
        let n = mon + i, e = store.days[Day.str(n)], dots = e.map(Logic.moodDots) ?? []
        Button { open(n) } label: {
          VStack(spacing: 3) {
            Text(Texts.weekdayShort[i].uppercased()).font(.sans(11)).foregroundStyle(Theme.faint)
            Text("\(Day.ymd(n).2)").font(.sans(15, .medium)).foregroundStyle(n > t ? Theme.faint : Theme.ink)
            Group {
              if let d = dots.first { Image("stimmung-\(d)").resizable().scaledToFit() }
              else if n <= t { Circle().strokeBorder(Theme.line, style: StrokeStyle(lineWidth: 1.5, dash: [2.5, 3])).padding(10) }
              else { Color.clear }
            }
            .frame(width: 36, height: 36)
            HStack(spacing: 3) {
              if dots.count > 1 { ForEach(dots, id: \.self) { Circle().fill(Theme.mood($0)).frame(width: 5, height: 5) } }
            }.frame(height: 7)
          }
          .frame(maxWidth: .infinity, minHeight: 88)
          .overlay(RoundedRectangle(cornerRadius: 16).stroke(n == t ? Theme.ink : .clear, lineWidth: 1))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Texts.long(n) + (n == t ? ", heute" : "") + (dots.isEmpty ? "" : ", Stimmung " + dots.compactMap { Texts.stimmung[$0] }.joined(separator: ", ")))
      }
    }
  }

  // ---------- Ausblick ----------
  private func outlook(_ an: Analysis, _ t: DayNum) -> some View {
    let cols = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    return LazyVGrid(columns: cols, spacing: 12) {
      if let c = an.current {
        let ph = Logic.phaseOf(an, t)
        Tile(label: "Zyklustag", value: "\(c.day)", sub: "seit \(Texts.short(c.start))", big: true, art: "kachel-mond")
        Tile(label: "Phase", value: ph.map { Texts.phaseName[$0.phase]! } ?? "–", sub: ph?.predicted == true ? "Schätzung" : "", small: true, art: "zweig-klein")
        Tile(label: "Nächste Periode", value: c.overdue > 0 ? "überfällig" : Texts.short(c.next),
             sub: c.overdue > 0 ? "erwartet am \(Texts.short(c.next)), \(Texts.plural(c.overdue, "Tag", "Tage")) drüber" : c.next == t ? "heute" : "in \(Texts.plural(c.next - t, "Tag", "Tagen"))",
             art: "kachel-tropfen")
        Tile(label: "Fruchtbar", value: "\(Texts.short(c.fs))–\(Texts.short(c.fe))",
             sub: c.fertileNext == true ? "im nächsten Zyklus" : (t >= c.fs && t <= c.fe ? "jetzt, Eisprung um \(Texts.short(c.ov))" : "Eisprung um \(Texts.short(c.ov))"),
             small: true, art: "kachel-blume")
      } else {
        Tile(label: "Zyklustag", value: "–", sub: "noch keine Periode eingetragen", big: true, art: "kachel-mond")
        Tile(label: "Nächste Periode", value: "–", sub: "ab dem ersten Eintrag", art: "kachel-tropfen")
      }
    }
  }
}

/// Kachel im Ausblick: Titel, Wert, Zusatz, kleines Bild unten rechts
struct Tile: View {
  let label: String
  let value: String
  var sub = ""
  var big = false
  var small = false
  var art: String?
  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label).font(.serif(16)).foregroundStyle(Theme.ink)
      Text(value).font(.serif(big ? 40 : small ? 20 : 26)).foregroundStyle(big ? Theme.accentText : Theme.ink)
        .lineLimit(2).minimumScaleFactor(0.7)
      if !sub.isEmpty { Text(sub).font(.sans(13)).foregroundStyle(Theme.muted).padding(.trailing, 40) }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
    .padding(16)
    .background(alignment: .bottomTrailing) {
      if let art { Image(art).resizable().scaledToFit().frame(width: 58, height: 58).offset(x: 6, y: 6).accessibilityHidden(true) }
    }
    .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
    .accessibilityElement(children: .combine)
  }
}
