// Analyse: Überblick, Muster, Zykluslängen als Balken, Werte je Phase. Ohne genug Daten ein Leerzustand.

import Charts
import SwiftUI
import ZyklusKit

struct AnalyseView: View {
  @Environment(EntryStore.self) private var store
  let open: (DayNum) -> Void
  let showCalendar: () -> Void

  var body: some View {
    let an = store.analysis, t = store.today
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        PageHead(title: "Analyse", sub: Texts.dayMonth(t))
        if an.periods.count < 2 {
          if let p = an.periods.first {
            EmptyCard(image: "phase-follikel", title: "Fast geschafft",
                      text: "Ein Periodenstart ist da (\(Texts.short(p.start))). Sobald die nächste Periode beginnt, siehst du hier deine Zykluslänge und erste Muster. Frühere Perioden kannst du im Kalender nachtragen.",
                      button: "Im Kalender nachtragen", action: showCalendar)
          } else {
            EmptyCard(image: "phase-start", title: "Hier wächst deine Analyse",
                      text: "Trag den ersten Tag deiner Periode ein (Blutung ab „Leicht“). Ab zwei Periodenstarts siehst du Zykluslängen, Durchschnitt und Muster je Phase.",
                      button: "Periode eintragen") { open(t) }
          }
        } else {
          let st = Logic.moodStats(an, store.entries, today: t)
          summary(an)
          VStack(alignment: .leading, spacing: 12) {
            SectionHead("Muster")
            patterns(Logic.findPatterns(st))
          }
          VStack(alignment: .leading, spacing: 12) {
            SectionHead("Zykluslängen")
            chart(an)
          }
          VStack(alignment: .leading, spacing: 12) {
            SectionHead("Je Phase")
            phases(st)
          }
        }
      }
      .padding(.horizontal, Theme.gutter)
      .padding(.bottom, 32)
    }
  }

  // ---------- Überblick ----------
  private func summary(_ an: Analysis) -> some View {
    let lens = an.recent.map(\.len)
    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Ø Zykluslänge").font(.serif(16))
          (Text(an.avgCycle.map(Texts.dec) ?? "–").font(.serif(46)).foregroundColor(Theme.accentText)
            + Text(an.avgCycle == nil ? "" : " Tage").font(.serif(18)).foregroundColor(Theme.ink))
          Text("aus \(Texts.plural(an.recent.count, "Zyklus", "Zyklen"))").font(.sans(13)).foregroundStyle(Theme.muted)
        }
        Spacer()
        Image("kachel-mond").resizable().scaledToFit().frame(width: 72).accessibilityHidden(true)
      }
      Divider().overlay(Theme.lineSoft)
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 12) {
        stat("Ø Periode", an.avgPeriod.map { Texts.dec($0) + " Tage" } ?? "\(an.P) Tage (Standard)")
        stat("Spanne", lens.isEmpty ? "–" : "\(lens.min()!)–\(lens.max()!) Tage")
        stat("Schwankung", an.sd.map { "±" + Texts.dec($0) + " Tage" } ?? "–")
        stat("Erfasst", Texts.plural(an.cycles.count, "Zyklus", "Zyklen"))
      }
    }
    .card()
  }

  private func stat(_ label: String, _ value: String) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.sans(12)).foregroundStyle(Theme.muted)
      Text(value).font(.sans(15, .semibold))
    }
    .accessibilityElement(children: .combine)
  }

  // ---------- Muster ----------
  @ViewBuilder private func patterns(_ list: [Pattern]) -> some View {
    if list.isEmpty {
      Text("Noch keine deutlichen Muster. Sie erscheinen, sobald in mindestens zwei Phasen je drei Tage mit Gefühlen erfasst sind.")
        .font(.sans(14)).card(padding: 16)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(list.prefix(5).enumerated()), id: \.offset) { i, p in
          Text(Texts.pattern(p)).font(.sans(i == 0 ? 16 : 14))
            .padding(i == 0 ? 18 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(i == 0 ? Theme.accentTint : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(i == 0 ? Theme.accentTint : Theme.line))
        }
        Text("Einfache Häufigkeiten aus deinen Einträgen. Je mehr Tage du erfasst, desto belastbarer.")
          .font(.sans(13)).foregroundStyle(Theme.muted).padding(.horizontal, 4)
      }
    }
  }

  // ---------- Zykluslängen ----------
  private func chart(_ an: Analysis) -> some View {
    let cyc = Array(an.cycles.suffix(12))
    return VStack(alignment: .leading, spacing: 8) {
      Text("Tage pro Zyklus" + (an.avgCycle.map { " · gestrichelt = Ø " + Texts.dec($0) } ?? "")
           + (cyc.contains { !$0.ok } ? " · grau = ausgeschlossen" : ""))
        .font(.sans(13)).foregroundStyle(Theme.muted)
      Chart {
        ForEach(cyc, id: \.start) { c in
          BarMark(x: .value("Beginn", Texts.short(c.start)), y: .value("Tage", c.len))
            .foregroundStyle(c.ok ? Theme.accent : Theme.faint)
            .cornerRadius(6)
            .annotation(position: .top) { Text("\(c.len)").font(.sans(11, .semibold)) }
        }
        if let avg = an.avgCycle {
          RuleMark(y: .value("Durchschnitt", avg))
            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            .foregroundStyle(Theme.ink.opacity(0.6))
        }
      }
      .chartYAxis(.hidden)
      .chartXAxis { AxisMarks { _ in AxisValueLabel().font(.sans(10)) } }
      .frame(height: 170)
    }
    .card()
  }

  // ---------- Je Phase ----------
  private func phases(_ st: [Phase: PhaseStats]) -> some View {
    VStack(alignment: .leading, spacing: 10) {
      Grid(alignment: .trailing, horizontalSpacing: 8, verticalSpacing: 8) {
        GridRow {
          Text("").gridColumnAlignment(.leading)
          ForEach(Phase.allCases, id: \.self) { Text(Texts.phaseShort[$0]!).font(.sans(12, .semibold)).foregroundStyle(Theme.muted) }
        }
        Divider().overlay(Theme.line)
        GridRow {
          Text("Tage").font(.sans(13, .semibold))
          ForEach(Phase.allCases, id: \.self) { Text("\(st[$0]!.n)").font(.sans(13)).monospacedDigit() }
        }
        GridRow {
          Text("Ø Energie").font(.sans(13, .semibold))
          ForEach(Phase.allCases, id: \.self) { Text(Logic.avgEnergy(st[$0]!.energy).map(Texts.dec) ?? "–").font(.sans(13)).monospacedDigit() }
        }
      }
      let syms = Phase.allCases.compactMap { ph in
        st[ph]!.n > 0 ? Logic.topSymptom(st[ph]!).map { SymRow(phase: ph, symptom: $0.id, share: $0.share) } : nil
      }
      if !syms.isEmpty {
        Text("Häufigstes Körpersymptom").font(.sans(13)).foregroundStyle(Theme.muted).padding(.top, 8)
        ForEach(syms) { r in
          HStack {
            Text(Texts.phaseShort[r.phase]!).foregroundStyle(Theme.muted)
            Spacer()
            Text("\(Texts.symptom[r.symptom] ?? r.symptom) · \(Int((r.share * 100).rounded())) %")
          }
          .font(.sans(13))
        }
      }
    }
    .card()
  }
}

private struct SymRow: Identifiable {
  let phase: Phase, symptom: String, share: Double
  var id: Phase { phase }
}
