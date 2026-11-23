// Analyse wie in der Web-App (2.5): Überblick in Worten, Zyklen als Streifen, Muster mit vier Mini-Säulen,
// Energiekurve und eine Karte je Phase mit Umschalter. Beim Öffnen gleiten Karten herein, Balken wachsen,
// Zahlen zählen hoch. Mit „Bewegung reduzieren“ steht alles sofort da.

import SwiftUI
import ZyklusKit

struct AnalyseView: View {
  @Environment(EntryStore.self) private var store
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let open: (DayNum) -> Void
  let showCalendar: () -> Void
  /// Ist der Bereich gerade sichtbar? Beim Wechsel hierher spielt die Bewegung einmal ab.
  var active = true

  /// false = Ausgangszustand der Bewegung, true = Ruhezustand
  @State private var shown = true
  @State private var selected: Int?
  @State private var phase: Phase?

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
          let st = Logic.moodStats(an, store.entries, today: t, paused: store.settings.pause)
          summary(an).rise(shown, 0)
          VStack(alignment: .leading, spacing: 12) {
            SectionHead("Deine letzten Zyklen")
            cycles(an).rise(shown, 1)
          }
          VStack(alignment: .leading, spacing: 12) {
            SectionHead("Muster")
            patterns(Logic.findPatterns(st), st)
          }
          VStack(alignment: .leading, spacing: 12) {
            SectionHead("Je Phase")
            phases(st, an, t).rise(shown, 2)
          }
        }
      }
      .padding(.horizontal, Theme.gutter)
      .padding(.bottom, 32)
    }
    .onAppear { if active { play() } }
    .onChange(of: active) { _, on in if on { play() } }
  }

  /// Bewegung einmal abspielen (nur beim Öffnen, nicht bei jeder Änderung)
  private func play() {
    guard !reduceMotion else { shown = true; return }
    var t = Transaction(); t.disablesAnimations = true
    withTransaction(t) { shown = false }
    DispatchQueue.main.async { withAnimation(.easeOut(duration: 0.6)) { shown = true } }
  }

  // ---------- Überblick ----------
  private func regularity(_ sd: Double) -> String { sd <= 2 ? "sehr regelmäßig" : sd <= 4 ? "recht regelmäßig" : "eher unregelmäßig" }

  private func summary(_ an: Analysis) -> some View {
    let lens = an.recent.map(\.len), lo = lens.min() ?? 0, hi = lens.max() ?? 0
    let verdict = lens.isEmpty ? "Noch kein Zyklus zwischen 15 und 60 Tagen erfasst."
      : lens.count == 1 ? "Bisher ein Zyklus mit \(lens[0]) Tagen. Ab dem zweiten siehst du, wie regelmäßig er ist."
      : "Dein Zyklus ist **\(regularity(an.sd ?? 0))**, " + (lo == hi ? "zuletzt immer \(lo) Tage." : "zuletzt zwischen \(lo) und \(hi) Tagen.")
    return VStack(alignment: .leading, spacing: 14) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Ø Zykluslänge").font(.serif(16))
          HStack(alignment: .firstTextBaseline, spacing: 4) {
            if let avg = an.avgCycle {
              CountText(value: avg, decimals: 1, shown: shown).font(.serif(46)).foregroundStyle(Theme.accentText)
              Text("Tage").font(.serif(18))
            } else {
              Text("–").font(.serif(46)).foregroundStyle(Theme.accentText)
            }
          }
          if an.avgCycle == nil { Text("Standard \(an.C) Tage").font(.sans(13)).foregroundStyle(Theme.muted) }
          Text(md(verdict)).font(.sans(16)).padding(.top, 4).fixedSize(horizontal: false, vertical: true)
        }
        Spacer(minLength: 8)
        Image("kachel-mond").resizable().scaledToFit().frame(width: 72).accessibilityHidden(true)
          .pop(shown, delay: 0.3)
      }
      DashedDivider()
      LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), alignment: .leading)], alignment: .leading, spacing: 12) {
        stat("Ø Periode", an.avgPeriod.map { Texts.dec($0) + " Tage" } ?? "\(an.P) Tage (Standard)")
        stat("Spanne", lens.isEmpty ? "–" : (lo == hi ? "\(lo)" : "\(lo)–\(hi)") + " Tage")
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

  // ---------- Zyklen als Streifen ----------
  private func cycleText(_ c: Cycle) -> String {
    "Zyklus ab \(Texts.short(c.start)): \(c.len) Tage, davon \(c.periodLen) Tage Periode" + (c.ok ? "" : " · nicht gezählt (unter 15 oder über 60 Tage)")
  }

  private func cycles(_ an: Analysis) -> some View {
    let cyc = Array(an.cycles.suffix(12)), offset = an.cycles.count - cyc.count
    let lens = an.recent.map(\.len)
    let maxLen = Double(max(35, cyc.map { min($0.len, 60) }.max() ?? 35))
    let x = { (d: Int) in min(Double(d), maxLen) / maxLen }
    let band: (Double, Double)? = lens.count > 1 ? (x(lens.min()!), x(lens.max()!)) : nil
    return VStack(alignment: .leading, spacing: 14) {
      HStack(spacing: 14) {
        legendKey(Theme.accent, "Periode")
        legendKey(Theme.accentTint, "Rest des Zyklus")
        if band != nil { legendKey(Theme.sageTint, "üblicher Bereich") }
      }
      .font(.sans(13)).foregroundStyle(Theme.muted)
      .accessibilityHidden(true)
      VStack(spacing: 10) {
        ForEach(Array(cyc.enumerated()), id: \.offset) { i, c in
          Button { selected = offset + i } label: {
            HStack(spacing: 10) {
              Text(Texts.short(c.start)).font(.sans(12)).monospacedDigit().foregroundStyle(Theme.muted).frame(width: 50, alignment: .leading)
              GeometryReader { g in
                let w = g.size.width
                ZStack(alignment: .leading) {
                  if let b = band {
                    RoundedRectangle(cornerRadius: 6).fill(Theme.sageTint.opacity(0.6))
                      .frame(width: max(6, w * (b.1 - b.0)), height: 36).offset(x: w * b.0)
                  }
                  HStack(spacing: 0) {
                    Rectangle().fill(c.ok ? Theme.accent : Theme.faint).frame(width: w * x(c.len) * min(1, Double(c.periodLen) / Double(c.len)))
                    Rectangle().fill(c.ok ? Theme.accentTint : Theme.lineSoft)
                  }
                  .frame(width: w * x(c.len), height: 26)
                  .overlay(alignment: .trailing) { Text("\(c.len)").font(.sans(12, .semibold)).foregroundStyle(Theme.ink).padding(.trailing, 9) }
                  .clipShape(Capsule())
                  .overlay(Capsule().stroke(Theme.ink, lineWidth: selected == offset + i ? 2 : 0))
                  .scaleEffect(x: shown ? 1 : 0.001, anchor: .leading)
                  .animation(reduceMotion ? nil : .easeOut(duration: 0.7).delay(0.15 + Double(i) * 0.06), value: shown)
                }
                .frame(height: 26)
              }
              .frame(height: 26)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .padding(.vertical, -9)
          .accessibilityLabel(cycleText(c))
          .accessibilityAddTraits(selected == offset + i ? .isSelected : [])
        }
      }
      .padding(.vertical, 9)
      // Achse 0, 10, 20 …
      HStack(spacing: 10) {
        Color.clear.frame(width: 50, height: 1)
        GeometryReader { g in
          ForEach(Array(stride(from: 0, through: Int(maxLen), by: 10)), id: \.self) { d in
            Text("\(d)").font(.sans(11)).foregroundStyle(Theme.faint).fixedSize()
              .position(x: g.size.width * x(d), y: 7)
          }
        }
        .frame(height: 14)
      }
      .accessibilityHidden(true)
      Text(selected.flatMap { $0 < an.cycles.count ? cycleText(an.cycles[$0]) + "." : nil } ?? "Tipp auf einen Streifen für Details.")
        .font(.sans(14)).foregroundStyle(selected == nil ? Theme.muted : Theme.ink)
        .frame(minHeight: 21, alignment: .leading)
      DisclosureGroup {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 8) {
          GridRow {
            Text("Beginn"); Text("Zyklus").gridColumnAlignment(.trailing); Text("Periode").gridColumnAlignment(.trailing); Text("Status")
          }
          .font(.sans(12, .semibold)).foregroundStyle(Theme.muted)
          ForEach(Array(an.cycles.reversed()), id: \.start) { c in
            GridRow {
              Text(Texts.date(c.start)); Text("\(c.len)").monospacedDigit(); Text("\(c.periodLen)").monospacedDigit(); Text(c.ok ? "gezählt" : "ausgeschlossen")
            }
            .font(.sans(14))
          }
        }
        .padding(.top, 8)
      } label: { Text("Als Tabelle").font(.sans(14, .medium)).foregroundStyle(Theme.ink) }
      .tint(Theme.accentText)
    }
    .card()
  }

  private func legendKey(_ c: Color, _ s: String) -> some View {
    HStack(spacing: 6) { RoundedRectangle(cornerRadius: 4).fill(c).frame(width: 12, height: 12); Text(s) }
  }

  // ---------- Muster ----------
  @ViewBuilder private func patterns(_ list: [Pattern], _ st: [Phase: PhaseStats]) -> some View {
    if list.isEmpty {
      Text("Noch keine deutlichen Muster. Sie erscheinen, sobald in mindestens zwei Phasen je drei Tage mit Gefühlen erfasst sind.")
        .font(.sans(15)).card(padding: 16)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        ForEach(Array(list.prefix(3).enumerated()), id: \.offset) { i, p in patternRow(p, st, i).rise(shown, Double(i)) }
        if list.count > 3 {
          DisclosureGroup {
            VStack(spacing: 8) {
              ForEach(Array(list.dropFirst(3).enumerated()), id: \.offset) { i, p in patternRow(p, st, i + 3) }
            }
            .padding(.top, 8)
          } label: { Text("Weitere \(Texts.plural(list.count - 3, "Muster", "Muster"))").font(.sans(14, .medium)).foregroundStyle(Theme.ink) }
          .tint(Theme.accentText)
          .padding(.horizontal, 4)
        }
        Text("Die Säulen zeigen, wie oft es in jeder Phase vorkommt: P Periode, F Follikel, E Eisprung, L Luteal. Einfache Häufigkeiten aus deinen Einträgen, je mehr Tage, desto belastbarer.")
          .font(.sans(13)).foregroundStyle(Theme.muted).padding(.horizontal, 4).padding(.top, 4)
      }
    }
  }

  private func patternRow(_ p: Pattern, _ st: [Phase: PhaseStats], _ i: Int) -> some View {
    let share: (Phase) -> Double, top: Phase, label: String
    switch p {
    case let .energy(high, _):
      share = { (Logic.avgEnergy(st[$0]!.energy) ?? 0) / 5 }; top = high.phase
      label = Phase.allCases.map { ph in "\(Texts.phaseShort[ph]!) " + (Logic.avgEnergy(st[ph]!.energy).map { "Ø \(Texts.dec($0)) von 5" } ?? "keine Angabe") }.joined(separator: ", ")
    case let .frequency(kind, id, phase, _, _):
      let key: KeyPath<PhaseStats, [String: Int]> = kind == .mood ? \.moods : \.syms
      share = { ph in st[ph]!.n > 0 ? Double(st[ph]![keyPath: key][id] ?? 0) / Double(st[ph]!.n) : 0 }; top = phase
      label = Phase.allCases.map { "\(Texts.phaseShort[$0]!) \(Int((share($0) * 100).rounded())) %" }.joined(separator: ", ")
    }
    return HStack(spacing: 16) {
      Text(md(Texts.pattern(p))).font(.sans(15)).frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
      HStack(spacing: 4) {
        ForEach(Array(Phase.allCases.enumerated()), id: \.offset) { j, ph in
          VStack(spacing: 3) {
            ZStack(alignment: .bottom) {
              RoundedRectangle(cornerRadius: 4).fill(Theme.lineSoft)
              RoundedRectangle(cornerRadius: 4).fill(ph == top ? Theme.accent : Theme.faint)
                .frame(height: max(3, 30 * share(ph)))
                .scaleEffect(y: shown ? 1 : 0.001, anchor: .bottom)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.6).delay(0.3 + Double(j) * 0.05), value: shown)
            }
            .frame(width: 16, height: 30)
            Text(String(Texts.phaseShort[ph]!.prefix(1))).font(.sans(10)).foregroundStyle(Theme.muted)
          }
        }
      }
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(label)
    }
    .padding(.horizontal, 16).padding(.vertical, 14)
    .background(i == 0 ? Theme.accentTint : Theme.surface, in: RoundedRectangle(cornerRadius: 16))
    .overlay(RoundedRectangle(cornerRadius: 16).stroke(i == 0 ? Theme.accentTint : Theme.line))
  }

  // ---------- Je Phase ----------
  @ViewBuilder private func phases(_ st: [Phase: PhaseStats], _ an: Analysis, _ t: DayNum) -> some View {
    if !Phase.allCases.contains(where: { st[$0]!.n > 0 }) {
      Text("Noch keine Einträge in einem erkannten Zyklus.").font(.sans(14)).foregroundStyle(Theme.muted)
    } else {
      let k = phase ?? Logic.phaseShown(an, t, paused: store.settings.pause)?.phase ?? .men
      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Energie über den Zyklus").font(.sans(14)).foregroundStyle(Theme.muted).padding(.horizontal, 6)
          EnergyCurve(values: Phase.allCases.map { Logic.avgEnergy(st[$0]!.energy) }, selected: Phase.allCases.firstIndex(of: k) ?? 0, shown: shown)
            .frame(height: 110)
        }
        .padding(.horizontal, 12).padding(.top, 14).padding(.bottom, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
        PhasePicker(selection: Binding(get: { k }, set: { v in withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.85)) { phase = v } }))
        phaseCard(k, st[k]!, an)
        allMoods(st)
      }
    }
  }

  private func phaseCard(_ k: Phase, _ s: PhaseStats, _ an: Analysis) -> some View {
    let ov = an.C - an.L + 1
    let r: (Int, Int) = [Phase.men: (1, an.P), .fol: (an.P + 1, ov - 3), .ovu: (ov - 2, ov + 1), .lut: (ov + 2, an.C)][k]!
    let top = s.moods.sorted { $0.value != $1.value ? $0.value > $1.value : (Model.moods.firstIndex(of: $0.key) ?? 0) < (Model.moods.firstIndex(of: $1.key) ?? 0) }.prefix(3)
    let e = Logic.avgEnergy(s.energy)
    let sym = s.n > 0 ? Logic.topSymptom(s) : nil
    return VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text(Texts.phaseName[k]!).font(.serif(25))
          if r.1 >= r.0 { Text("etwa Zyklustag \(r.0) bis \(r.1)").font(.sans(14)).foregroundStyle(Theme.muted) }
        }
        Spacer()
        Image(phaseArt(k)).resizable().scaledToFit().frame(width: 64, height: 64).accessibilityHidden(true)
          .id(k).transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.4).combined(with: .opacity), removal: .opacity))
      }
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 4) {
          Text("Erfasste Tage").font(.sans(12)).foregroundStyle(Theme.muted)
          Text("\(s.n)").font(.sans(16, .semibold)).monospacedDigit().contentTransition(.numericText(value: Double(s.n)))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        VStack(alignment: .leading, spacing: 4) {
          Text("Energie").font(.sans(12)).foregroundStyle(Theme.muted)
          if let e {
            HStack(spacing: 5) {
              ForEach(1...5, id: \.self) { n in
                Circle().fill(n <= Int((e + 0.5).rounded(.down)) ? Theme.sage : .clear).overlay(Circle().stroke(Theme.sage, lineWidth: 1.5)).frame(width: 14, height: 14)
              }
            }
            .padding(.top, 3)
            .accessibilityElement(children: .ignore).accessibilityLabel("Ø \(Texts.dec(e)) von 5")
          } else { Text("–").font(.sans(16, .semibold)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
      VStack(alignment: .leading, spacing: 10) {
        Text("Häufigste Gefühle").font(.sans(14)).foregroundStyle(Theme.muted)
        if top.isEmpty { Text("Keine Gefühle eingetragen.").font(.sans(14)).foregroundStyle(Theme.muted) }
        ForEach(Array(top), id: \.key) { m in
          let v = s.n > 0 ? Double(m.value) / Double(s.n) : 0
          HStack(spacing: 10) {
            Text(Texts.mood[m.key] ?? m.key).font(.sans(14)).frame(width: 100, alignment: .leading).lineLimit(1).minimumScaleFactor(0.8)
            GeometryReader { g in
              ZStack(alignment: .leading) {
                Capsule().fill(Theme.sunken)
                Capsule().fill(Theme.accent).frame(width: g.size.width * v)
              }
            }
            .frame(height: 10)
            Text("\(Int((v * 100).rounded())) %").font(.sans(14, .semibold)).monospacedDigit().frame(width: 44, alignment: .trailing)
          }
          .accessibilityElement(children: .combine)
        }
      }
      VStack(alignment: .leading, spacing: 4) {
        Text("Häufigstes Körpersymptom").font(.sans(14)).foregroundStyle(Theme.muted)
        Text(sym.map { "\(Texts.symptom[$0.id] ?? $0.id) · \(Int(($0.share * 100).rounded())) %" } ?? (s.n > 0 ? "Keins eingetragen" : "Noch keine Einträge in dieser Phase"))
          .font(.sans(16, .semibold))
      }
    }
    .card()
  }

  private func phaseArt(_ k: Phase) -> String {
    switch k { case .men: return "kachel-tropfen"; case .fol: return "zweig-klein"; case .ovu: return "kachel-blume"; case .lut: return "kachel-herbstblatt" }
  }

  /// Alle Gefühle je Phase als Tabelle, für alle, die Zahlen mögen
  @ViewBuilder private func allMoods(_ st: [Phase: PhaseStats]) -> some View {
    let used = Model.moods.filter { id in Phase.allCases.contains { st[$0]!.moods[id] != nil } }
      .map { id in (id, Phase.allCases.reduce(0) { $0 + (st[$1]!.moods[id] ?? 0) }) }
      .enumerated().sorted { $0.element.1 != $1.element.1 ? $0.element.1 > $1.element.1 : $0.offset < $1.offset }.map { $0.element.0 }
    if !used.isEmpty {
      DisclosureGroup {
        VStack(alignment: .leading, spacing: 8) {
          Text("Anteil der eingetragenen Tage einer Phase.").font(.sans(13)).foregroundStyle(Theme.muted)
          Grid(alignment: .trailing, horizontalSpacing: 6, verticalSpacing: 8) {
            GridRow {
              Text("Gefühl").gridColumnAlignment(.leading)
              ForEach(Phase.allCases, id: \.self) { Text(Texts.phaseShort[$0]!) }
            }
            .font(.sans(12, .semibold)).foregroundStyle(Theme.muted)
            ForEach(used, id: \.self) { id in
              GridRow {
                Text(Texts.mood[id] ?? id).font(.sans(13, .semibold)).lineLimit(1).minimumScaleFactor(0.8)
                ForEach(Phase.allCases, id: \.self) { ph in
                  Text(st[ph]!.n > 0 ? "\(Int((Double(st[ph]!.moods[id] ?? 0) / Double(st[ph]!.n) * 100).rounded())) %" : "–").font(.sans(13)).monospacedDigit()
                }
              }
            }
          }
        }
        .padding(.top, 8)
      } label: { Text("Alle Gefühle je Phase").font(.sans(14, .medium)).foregroundStyle(Theme.ink) }
      .tint(Theme.accentText)
      .padding(.horizontal, 4)
    }
  }

  /// Text mit **fett** aus den Satzbausteinen
  private func md(_ s: String) -> AttributedString { (try? AttributedString(markdown: s)) ?? AttributedString(s) }
}

// ---------- Bausteine der Analyse ----------

/// Zahl, die beim Einblenden von 0 auf ihren Wert zählt
private struct CountText: View {
  let value: Double
  let decimals: Int
  let shown: Bool
  var body: some View {
    let v = shown ? value : 0
    Text(decimals == 0 ? "\(Int(v.rounded()))" : Texts.dec(v))
      .monospacedDigit()
      .contentTransition(.numericText(value: v))
      .animation(.easeOut(duration: 0.9), value: shown)
  }
}

/// Energie je Phase als weiche Kurve mit Punkten; die gewählte Phase ist gefüllt
private struct EnergyCurve: View {
  let values: [Double?]
  let selected: Int
  let shown: Bool
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  var body: some View {
    GeometryReader { g in
      let w = g.size.width, sx = w / 320
      let X = [40.0, 120, 200, 280].map { $0 * sx }
      let y = { (v: Double) in 80 - v / 5 * 60 }
      let pts = values.enumerated().compactMap { i, v in v.map { CGPoint(x: X[i], y: y($0)) } }
      ZStack(alignment: .topLeading) {
        Path { p in p.move(to: CGPoint(x: 20 * sx, y: 80)); p.addLine(to: CGPoint(x: 300 * sx, y: 80)) }.stroke(Theme.lineSoft, lineWidth: 1)
        Path { p in
          guard let f = pts.first else { return }
          p.move(to: f)
          for i in 1..<max(1, pts.count) {
            let a = pts[i - 1], b = pts[i], m = (a.x + b.x) / 2
            p.addCurve(to: b, control1: CGPoint(x: m, y: a.y), control2: CGPoint(x: m, y: b.y))
          }
        }
        .trim(from: 0, to: shown ? 1 : 0)
        .stroke(Theme.sage, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
        .animation(reduceMotion ? nil : .easeOut(duration: 1).delay(0.25), value: shown)
        ForEach(0..<4, id: \.self) { i in
          Text(Texts.phaseShort[Phase.allCases[i]]!).font(.sans(10.5)).foregroundStyle(Theme.muted).fixedSize().position(x: X[i], y: 96)
          if let v = values[i] {
            Text(Texts.dec(v)).font(.sans(12, .semibold)).fixedSize().position(x: X[i], y: y(v) - 13)
            Circle().fill(i == selected ? Theme.sage : Theme.surface).overlay(Circle().stroke(Theme.sage, lineWidth: 2))
              .frame(width: i == selected ? 14 : 8, height: i == selected ? 14 : 8)
              .position(x: X[i], y: y(v))
          }
        }
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Energie je Phase: " + Phase.allCases.enumerated().map { i, ph in "\(Texts.phaseShort[ph]!) \(values[i].map(Texts.dec) ?? "keine Angabe")" }.joined(separator: ", ") + " (von 5)")
  }
}

/// Umschalter mit gleitender Pille (wie in Porto)
private struct PhasePicker: View {
  @Binding var selection: Phase
  @Namespace private var ns
  var body: some View {
    HStack(spacing: 0) {
      ForEach(Phase.allCases, id: \.self) { ph in
        let on = selection == ph
        Button { selection = ph } label: {
          Text(Texts.phaseShort[ph]!).font(.sans(14, on ? .semibold : .medium))
            .foregroundStyle(on ? Theme.ink : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 40)
            .background {
              if on { Capsule().fill(Theme.surface).shadow(color: .black.opacity(0.15), radius: 4, y: 2).matchedGeometryEffect(id: "thumb", in: ns) }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
      }
    }
    .padding(4)
    .background(Capsule().fill(Theme.sunken))
  }
}

/// Gestrichelte Trennlinie
struct DashedDivider: View {
  var body: some View {
    Line().stroke(Theme.lineSoft, style: StrokeStyle(lineWidth: 1, dash: [4, 3])).frame(height: 1)
  }
  private struct Line: Shape {
    func path(in r: CGRect) -> Path { var p = Path(); p.move(to: CGPoint(x: 0, y: 0.5)); p.addLine(to: CGPoint(x: r.width, y: 0.5)); return p }
  }
}

extension View {
  /// Karte gleitet beim Öffnen von unten herein (gestaffelt nach Index)
  func rise(_ shown: Bool, _ i: Double) -> some View { modifier(Rise(shown: shown, i: i)) }
  /// Bild springt schräg herein
  func pop(_ shown: Bool, delay: Double) -> some View { modifier(Pop(shown: shown, delay: delay)) }
}

struct Rise: ViewModifier {
  let shown: Bool, i: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content.opacity(shown ? 1 : 0).offset(y: shown ? 0 : 14)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.55).delay(i * 0.07), value: shown)
  }
}

struct Pop: ViewModifier {
  let shown: Bool, delay: Double
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func body(content: Content) -> some View {
    content.opacity(shown ? 1 : 0).offset(y: shown ? 0 : 30).rotationEffect(.degrees(shown ? 0 : -14))
      .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.6).delay(delay), value: shown)
  }
}
