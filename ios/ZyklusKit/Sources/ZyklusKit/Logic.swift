// Logik: reine Funktionen. Daten rein, Daten raus.
// Entspricht src/logic.js. Keine Oberfläche, kein Speicher, keine aktuelle Zeit: "heute" kommt immer als Tagnummer herein.

import Foundation

private func mean(_ a: [Double]) -> Double { a.reduce(0, +) / Double(a.count) }

public struct Period: Codable, Equatable, Sendable {
  public var start: DayNum, end: DayNum, len: Int
}

public struct Cycle: Codable, Equatable, Sendable {
  public var start: DayNum, len: Int, periodLen: Int, ok: Bool
}

public struct Current: Codable, Equatable, Sendable {
  public var start: DayNum, day: Int, next: DayNum, overdue: Int
  /// Eisprung, fruchtbares Fenster von/bis
  public var ov: DayNum, fs: DayNum, fe: DayNum
  public var inPeriod: Bool
  /// Fenster dieses Zyklus ist vorbei, gezeigt wird das nächste
  public var fertileNext: Bool?
}

public struct Analysis: Codable, Equatable, Sendable {
  public var today: DayNum
  public var periods: [Period]
  public var cycles: [Cycle]
  public var recent: [Cycle]
  public var avgCycle: Double?
  public var avgPeriod: Double?
  public var sd: Double?
  /// Zykluslänge, Periodendauer, Lutealphase, mit denen gerechnet wird
  public var C: Int, P: Int, L: Int
  public var current: Current?

  // null-Werte ausdrücklich schreiben, damit die Ausgabe den Test-Fixtures entspricht
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: CodingKeys.self)
    try c.encode(today, forKey: .today); try c.encode(periods, forKey: .periods)
    try c.encode(cycles, forKey: .cycles); try c.encode(recent, forKey: .recent)
    try c.encode(avgCycle, forKey: .avgCycle); try c.encode(avgPeriod, forKey: .avgPeriod); try c.encode(sd, forKey: .sd)
    try c.encode(C, forKey: .C); try c.encode(P, forKey: .P); try c.encode(L, forKey: .L)
    try c.encode(current, forKey: .current)
  }
}

public struct DayPhase: Codable, Equatable, Sendable {
  public var phase: Phase
  public var predicted: Bool
  public var fertile: Bool
  public var ovu: Bool
  public var cycleDay: Int
  public var next: DayNum
}

public struct PhaseStats: Codable, Equatable, Sendable {
  public var n = 0
  public var moods: [String: Int] = [:]
  public var syms: [String: Int] = [:]
  public var energy: [Int] = []
}

public enum Pattern: Equatable, Sendable {
  case frequency(kind: Kind, id: String, phase: Phase, share: Double, otherShare: Double)
  case energy(high: PhaseAvg, low: PhaseAvg)

  public enum Kind: String, Codable, Sendable { case mood, symptom }
  public struct PhaseAvg: Codable, Equatable, Sendable { public var phase: Phase; public var avg: Double }
}

extension Pattern: Encodable {
  enum Keys: String, CodingKey { case kind, id, phase, share, otherShare, high, low }
  public func encode(to encoder: Encoder) throws {
    var c = encoder.container(keyedBy: Keys.self)
    switch self {
    case let .frequency(kind, id, phase, share, otherShare):
      try c.encode(kind, forKey: .kind); try c.encode(id, forKey: .id); try c.encode(phase, forKey: .phase)
      try c.encode(share, forKey: .share); try c.encode(otherShare, forKey: .otherShare)
    case let .energy(high, low):
      try c.encode("energy", forKey: .kind); try c.encode(high, forKey: .high); try c.encode(low, forKey: .low)
    }
  }
}

public enum Logic {
  /// Erkennt Perioden und Zyklen, rechnet Durchschnitt und aktuellen Stand.
  public static func analyze(_ entries: [DayEntry], settings: Settings, today: DayNum) -> Analysis {
    let L = settings.luteal
    let bleed = entries.filter { $0.flow >= Model.flowPeriod }.map(\.num).sorted()
    var periods: [Period] = []
    for n in bleed {
      if let p = periods.last, n - p.end <= 2 { periods[periods.count - 1].end = n }
      else { periods.append(Period(start: n, end: n, len: 0)) }
    }
    for i in periods.indices { periods[i].len = periods[i].end - periods[i].start + 1 }

    var cycles: [Cycle] = []
    if periods.count > 1 {
      for i in 0..<(periods.count - 1) {
        let len = periods[i + 1].start - periods[i].start
        cycles.append(Cycle(start: periods[i].start, len: len, periodLen: periods[i].len, ok: len >= 15 && len <= 60))
      }
    }
    let recent = Array(cycles.filter(\.ok).suffix(6))
    let avgCycle = recent.isEmpty ? nil : mean(recent.map { Double($0.len) })
    let done = Array(periods.filter { $0.end < today - 1 }.suffix(6))
    let avgPeriod = done.isEmpty ? nil : mean(done.map { Double($0.len) })
    let sd = recent.count > 1 ? mean(recent.map { pow(Double($0.len) - avgCycle!, 2) }).squareRoot() : nil
    let C = Int(Sanitize.jsRound(avgCycle ?? Double(settings.cycleLen)))
    let P = Int(Sanitize.jsRound(avgPeriod ?? Double(settings.periodLen)))

    var current: Current?
    if let last = periods.last {
      let next = last.start + C
      var c = Current(start: last.start, day: today - last.start + 1, next: next,
                      overdue: today > next ? today - next : 0,
                      ov: next - L, fs: next - L - 5, fe: next - L + 1,
                      inPeriod: today <= last.end)
      if c.fe < today && c.overdue == 0 { // Fenster dieses Zyklus vorbei → nächstes zeigen
        c.fs += C; c.fe += C; c.ov += C; c.fertileNext = true
      }
      current = c
    }
    return Analysis(today: today, periods: periods, cycles: cycles, recent: recent, avgCycle: avgCycle,
                    avgPeriod: avgPeriod, sd: sd, C: C, P: P, L: L, current: current)
  }

  /// Phase eines Tages: echte Periodenstarts, danach Fortschreibung mit Ø-Länge.
  public static func phaseOf(_ an: Analysis, _ n: DayNum) -> DayPhase? {
    let periods = an.periods, C = an.C, P = an.P, L = an.L
    guard let i = periods.lastIndex(where: { $0.start <= n }) else { return nil }
    let p = periods[i]
    var start = p.start, end = p.end, next: DayNum, predicted = false
    if i + 1 < periods.count { next = periods[i + 1].start }
    else if n < p.start + C { next = p.start + C }
    else {
      let k = (n - p.start) / C
      start = p.start + k * C; end = start + P - 1; next = start + C; predicted = true
    }
    if !predicted && i == periods.count - 1 && n > an.today { predicted = true }
    let ov = next - L
    let phase: Phase = n <= end ? .men : n < ov - 2 ? .fol : n <= ov + 1 ? .ovu : .lut
    return DayPhase(phase: phase, predicted: predicted, fertile: n >= ov - 5 && n <= ov + 1, ovu: n == ov,
                    cycleDay: n - start + 1, next: next)
  }

  /// Farbpunkte für den Kalender: eigene Stimmungsangabe, sonst aus den Gefühlen. Liefert Stimmungs-IDs.
  public static func moodDots(_ e: DayEntry) -> [String] {
    let set = Set(e.stimmung.isEmpty ? e.moods.map { Model.moodTone[$0] ?? "gut" } : e.stimmung)
    return Model.stimmung.filter(set.contains)
  }

  /// Zählt Gefühle, Symptome und Energie je Phase (nur Tage bis heute mit Angaben).
  public static func moodStats(_ an: Analysis, _ entries: [DayEntry], today: DayNum) -> [Phase: PhaseStats] {
    var stats = Dictionary(uniqueKeysWithValues: Phase.allCases.map { ($0, PhaseStats()) })
    for e in entries {
      let n = e.num
      guard n <= today, e.hasDetail, let ph = phaseOf(an, n) else { continue }
      var s = stats[ph.phase]!
      s.n += 1
      e.moods.forEach { s.moods[$0, default: 0] += 1 }
      e.symptoms.forEach { s.syms[$0, default: 0] += 1 }
      if e.energy != 0 { s.energy.append(e.energy) }
      stats[ph.phase] = s
    }
    return stats
  }

  /// Findet auffällige Häufungen je Phase. Liefert Daten, die Oberfläche formuliert die Sätze.
  /// Höchstens fünf Häufigkeitsmuster (stärkste zuerst), danach optional ein Energiemuster.
  public static func findPatterns(_ stats: [Phase: PhaseStats]) -> [Pattern] {
    var out: [(score: Double, pattern: Pattern)] = []
    func scan(_ key: KeyPath<PhaseStats, [String: Int]>, _ ids: [String], _ kind: Pattern.Kind) {
      for id in ids {
        let rows = Phase.allCases.map { ph in (ph: ph, n: stats[ph]!.n, c: stats[ph]![keyPath: key][id] ?? 0) }.filter { $0.n >= 3 }
        let total = rows.reduce(0) { $0 + $1.c }
        if rows.count < 2 || total < 4 { continue }
        let share = { (r: (ph: Phase, n: Int, c: Int)) in Double(r.c) / Double(r.n) }
        // wie reduce in JS: bei Gleichstand gewinnt die frühere Phase
        let top = rows.dropFirst().reduce(rows[0]) { share($1) > share($0) ? $1 : $0 }
        let rest = rows.filter { $0.ph != top.ph }
        let restN = rest.reduce(0) { $0 + $1.n }, restC = rest.reduce(0) { $0 + $1.c }
        let other = restN > 0 ? Double(restC) / Double(restN) : 0
        let p = share(top)
        if p >= 0.25 && p >= other * 1.6 + 0.05 {
          out.append((p - other, .frequency(kind: kind, id: id, phase: top.ph, share: p, otherShare: other)))
        }
      }
    }
    scan(\.moods, Model.moods, .mood)
    scan(\.syms, Model.symptoms, .symptom)
    // stabile Sortierung: bei gleichem Wert bleibt die Reihenfolge der Stammdaten
    let sorted = out.enumerated().sorted { a, b in
      a.element.score != b.element.score ? a.element.score > b.element.score : a.offset < b.offset
    }.map(\.element.pattern)
    var res = Array(sorted.prefix(5))
    let en = Phase.allCases.compactMap { ph -> Pattern.PhaseAvg? in
      let v = stats[ph]!.energy
      return v.count >= 3 ? Pattern.PhaseAvg(phase: ph, avg: mean(v.map(Double.init))) : nil
    }
    if en.count >= 2 {
      let high = en.dropFirst().reduce(en[0]) { $1.avg > $0.avg ? $1 : $0 }
      let low = en.dropFirst().reduce(en[0]) { $1.avg < $0.avg ? $1 : $0 }
      if high.avg - low.avg >= 0.5 { res.append(.energy(high: high, low: low)) }
    }
    return res
  }

  /// Durchschnittliche Energie einer Liste (1–5) oder nil.
  public static func avgEnergy(_ v: [Int]) -> Double? { v.isEmpty ? nil : mean(v.map(Double.init)) }

  /// Häufigstes Symptom einer Phase.
  public static func topSymptom(_ s: PhaseStats) -> (id: String, share: Double)? {
    // wie JS: nach Anzahl absteigend, bei Gleichstand die zuerst gezählte. Swift-Dictionaries haben keine
    // Reihenfolge, darum hier bei Gleichstand die Reihenfolge der Stammdaten.
    let best = Model.symptoms.compactMap { id in s.syms[id].map { (id, $0) } }
      .enumerated().max { a, b in a.element.1 != b.element.1 ? a.element.1 < b.element.1 : a.offset > b.offset }
    return best.map { ($0.element.0, Double($0.element.1) / Double(s.n)) }
  }

  // ---------- Backup-Erinnerung ----------
  public static let backupEvery = 30
  public static let backupSnooze = 7

  /// Ist eine Backup-Erinnerung fällig? Ohne bisheriges Backup zählt der erste Eintrag. Erst ab fünf Einträgen.
  public static func backupDue(count: Int, first: DayNum?, lastBackup: DayNum?, snoozed: DayNum?, today: DayNum) -> Bool {
    if count < 5 { return false }
    if let s = snoozed, today - s < backupSnooze { return false }
    guard let ref = lastBackup ?? first else { return false }
    return today - ref >= backupEvery
  }

  // ---------- Erster Start ----------
  /// Einträge für die letzte Periode aus der Begrüßung: ab Start so viele Tage wie periodLen mit Blutung „Leicht“, höchstens bis heute.
  public static func introPeriod(start: DayNum, periodLen: Int, today: DayNum) -> [DayEntry] {
    guard periodLen > 0, start <= today else { return [] }
    return (start...min(start + periodLen - 1, today)).map { DayEntry(date: Day.str($0), flow: Model.flowPeriod) }
  }

  // ---------- Demodaten (erfunden, reproduzierbar) ----------
  public static func makeDemo(today: DayNum) -> [DayEntry] {
    var seed = 42
    func rnd() -> Double { seed = (seed * 16807) % 2_147_483_647; return Double(seed) / 2_147_483_647 }
    func pick(_ arr: [String], _ k: Double) -> [String] { arr.filter { _ in rnd() < k } }
    let lens = [29, 27, 31, 28, 30, 28]
    var start = today - lens.reduce(0, +) - 3
    var out: [DayEntry] = []
    for c in 0...lens.count {
      let len = c < lens.count ? lens[c] : 28
      let plen = 4 + Int((rnd() * 3).rounded(.down)), ov = start + len - 14
      for d in 0..<len {
        let n = start + d
        if n > today { break }
        var e = DayEntry.blank(Day.str(n))
        if d < plen { e.flow = d == 0 ? 3 : d == 1 ? 4 : d < plen - 1 ? 2 + Int(Sanitize.jsRound(rnd())) : 2 }
        if d == plen { e.flow = rnd() < 0.4 ? 1 : 0 }
        if rnd() < 0.65 {
          var moods: [String], syms: [String] = [], energy: Int
          if d < plen {
            moods = pick(["muede", "sensibel", "lustlos", "ruhig"], 0.45)
            syms = pick(["kraempfe", "rueckenschmerzen", "kopfschmerzen"], 0.45)
            energy = 2 + Int(Sanitize.jsRound(rnd()))
          } else if n < ov - 2 {
            moods = pick(["gluecklich", "energiegeladen", "selbstbewusst", "ruhig"], 0.45)
            energy = 3 + Int(Sanitize.jsRound(rnd() * 2))
          } else if n <= ov + 1 {
            moods = pick(["gluecklich", "selbstbewusst", "energiegeladen"], 0.55)
            energy = 4 + Int(Sanitize.jsRound(rnd()))
          } else if n > start + len - 6 {
            moods = pick(["gereizt", "traurig", "sensibel", "gestresst", "muede"], 0.45)
            syms = pick(["brustspannen", "heisshunger", "blaehungen", "unreine_haut"], 0.45)
            energy = 1 + Int(Sanitize.jsRound(rnd() * 2))
          } else {
            moods = pick(["ruhig", "muede", "gestresst", "gluecklich"], 0.35)
            syms = pick(["blaehungen"], 0.2)
            energy = 2 + Int(Sanitize.jsRound(rnd() * 2))
          }
          e.moods = moods; e.symptoms = syms; e.energy = energy
          if rnd() < 0.25 { e.stimmung = [rnd() < 0.5 ? "abends" : "ok"] }
        }
        if !e.isEmpty { out.append(e) }
      }
      start += len
    }
    return out
  }
}
