// Modell: Stammdaten, Datumsformat, leere Einträge, Validierung, Schema-Version.
// Entspricht src/model.js. Beschriftungen für die Anzeige stehen in der App (Texts.swift).

import Foundation

public enum Model {
  public static let appID = "zyklus-tracker"
  public static let schemaVersion = 1

  // ---------- Stammdaten (stabile IDs, nie umbenennen, nur ergänzen) ----------
  /// Blutungsstärke 0 keine, 1 Schmierblutung, 2 leicht, 3 mittel, 4 stark
  public static let flow = [0, 1, 2, 3, 4]
  /// Ab dieser Stärke zählt ein Tag als Periodentag
  public static let flowPeriod = 2
  public static let moods = [
    "gluecklich", "ruhig", "energiegeladen", "selbstbewusst",
    "gut", "zufrieden", "dankbar", "entspannt",
    "ausgeglichen", "motiviert", "kreativ", "optimistisch",
    "verliebt", "gesellig",
    "sensibel", "gereizt", "traurig", "aengstlich",
    "gestresst", "muede", "lustlos", "unruhig",
  ]
  public static let symptoms = [
    "kraempfe", "kopfschmerzen", "brustspannen", "blaehungen",
    "rueckenschmerzen", "unreine_haut", "heisshunger",
    "schlafprobleme", "uebelkeit", "unterleibsziehen",
  ]
  /// Stimmung des Tages, im Kalender als farbiger Punkt
  public static let stimmung = ["gut", "ok", "schlecht", "abends"]
  /// Ohne eigene Stimmungsangabe wird der Punkt aus den Gefühlen abgeleitet (sonst "gut")
  public static let moodTone: [String: String] = [
    "sensibel": "ok", "muede": "ok", "lustlos": "ok", "unruhig": "ok",
    "gereizt": "schlecht", "traurig": "schlecht", "aengstlich": "schlecht", "gestresst": "schlecht",
  ]
  /// Energie 0 = nicht erfasst, 1–5 sehr niedrig bis sehr hoch
  public static let energy = [0, 1, 2, 3, 4, 5]
  public static let themes = ["auto", "light", "dark"]
  public static let fonts = ["klassisch", "klar", "mix"]
  public static let noteMax = 2000
}

/// Zyklusphasen: Menstruation, Follikel, Eisprung, Luteal
public enum Phase: String, Codable, CaseIterable, Sendable {
  case men, fol, ovu, lut
}

// ---------- Datum: ganze Tage seit 1970 als Zahl, zeitzonenfest ----------
/// Tagnummer: ganze Tage seit dem 1.1.1970 (UTC). Rechnet ohne Kalender und Zeitzone.
public typealias DayNum = Int

public enum Day {
  /// "YYYY-MM-DD" → Tagnummer. Monate und Tage außerhalb des Bereichs laufen über wie in JavaScript (Date.UTC).
  public static func num(_ s: String) -> DayNum {
    let p = s.split(separator: "-").map { Int($0) ?? 0 }
    guard p.count == 3 else { return 0 }
    return num(year: p[0], month: p[1], day: p[2])
  }

  public static func num(year: Int, month: Int, day: Int) -> DayNum {
    let m0 = month - 1
    let y = year + Int((Double(m0) / 12).rounded(.down)), m = ((m0 % 12) + 12) % 12 + 1
    return civil(y, m, 1) + day - 1
  }

  /// Tagnummer → "YYYY-MM-DD"
  public static func str(_ n: DayNum) -> String {
    let (y, m, d) = ymd(n)
    return String(format: "%04d-%02d-%02d", y, m, d)
  }

  /// Tagnummer → Jahr, Monat, Tag
  public static func ymd(_ n: DayNum) -> (Int, Int, Int) {
    // Algorithmus von Howard Hinnant (civil_from_days)
    let z = n + 719_468
    let era = (z >= 0 ? z : z - 146_096) / 146_097
    let doe = z - era * 146_097
    let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146_096) / 365
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
    let mp = (5 * doy + 2) / 153
    let d = doy - (153 * mp + 2) / 5 + 1
    let m = mp < 10 ? mp + 3 : mp - 9
    return (yoe + era * 400 + (m <= 2 ? 1 : 0), m, d)
  }

  /// Wochentag 0 = Montag … 6 = Sonntag
  public static func weekday(_ n: DayNum) -> Int { ((n + 3) % 7 + 7) % 7 }

  private static func civil(_ year: Int, _ m: Int, _ d: Int) -> DayNum {
    let y = m <= 2 ? year - 1 : year
    let era = (y >= 0 ? y : y - 399) / 400
    let yoe = y - era * 400
    let doy = (153 * (m > 2 ? m - 3 : m + 9) + 2) / 5 + d - 1
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
    return era * 146_097 + doe - 719_468
  }
}

// ---------- Tageseintrag ----------
public struct DayEntry: Codable, Equatable, Hashable, Sendable {
  public var date: String
  public var flow: Int
  public var stimmung: [String]
  public var moods: [String]
  public var symptoms: [String]
  public var energy: Int
  public var note: String

  public init(date: String, flow: Int = 0, stimmung: [String] = [], moods: [String] = [], symptoms: [String] = [], energy: Int = 0, note: String = "") {
    self.date = date; self.flow = flow; self.stimmung = stimmung; self.moods = moods
    self.symptoms = symptoms; self.energy = energy; self.note = note
  }

  public static func blank(_ date: String) -> DayEntry { DayEntry(date: date) }

  public var num: DayNum { Day.num(date) }

  public var isEmpty: Bool {
    flow == 0 && stimmung.isEmpty && moods.isEmpty && symptoms.isEmpty && energy == 0
      && note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  /// Hat der Tag Angaben außer der Blutung?
  public var hasDetail: Bool {
    !stimmung.isEmpty || !moods.isEmpty || !symptoms.isEmpty || energy != 0
      || !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}

// ---------- Einstellungen ----------
public struct Settings: Codable, Equatable, Sendable {
  public var cycleLen: Int
  public var periodLen: Int
  public var luteal: Int
  public var theme: String
  public var font: String

  public init(cycleLen: Int = 28, periodLen: Int = 5, luteal: Int = 14, theme: String = "auto", font: String = "klar") {
    self.cycleLen = cycleLen; self.periodLen = periodLen; self.luteal = luteal; self.theme = theme; self.font = font
  }

  public static let defaults = Settings()
}

// ---------- Prüfen (Werte aus Speicher oder Import, wie JSONSerialization sie liefert) ----------
public enum Sanitize {
  /// Prüft einen Eintrag. Unbekannte IDs fallen weg, Zahlen werden begrenzt.
  public static func entry(_ raw: Any?) -> DayEntry? {
    guard let o = raw as? [String: Any], let date = o["date"] as? String,
          date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return nil }
    func list(_ v: Any?, _ ok: [String]) -> [String] {
      guard let a = v as? [Any] else { return [] }
      var seen = Set<String>(), out: [String] = []
      for case let s as String in a where ok.contains(s) && !seen.contains(s) { seen.insert(s); out.append(s) }
      return out
    }
    var note = (o["note"] as? String) ?? ""
    if note.utf16.count > Model.noteMax { note = String(decoding: Array(note.utf16.prefix(Model.noteMax)), as: UTF16.self) }
    return DayEntry(
      date: date,
      flow: clampInt(o["flow"], 0, 4),
      stimmung: list(o["stimmung"], Model.stimmung),
      moods: list(o["moods"], Model.moods),
      symptoms: list(o["symptoms"], Model.symptoms),
      energy: clampInt(o["energy"], 0, 5),
      note: note
    )
  }

  /// Bringt Einstellungen in gültige Bereiche, fehlende Werte werden Standard.
  public static func settings(_ raw: Any?) -> Settings {
    let s = raw as? [String: Any] ?? [:]
    func clamp(_ v: Any?, _ lo: Int, _ hi: Int, _ d: Int) -> Int {
      let x = jsRound(jsNumber(v))
      return x.isNaN ? d : min(hi, max(lo, Int(x)))
    }
    let d = Settings.defaults
    let theme = s["theme"] as? String, font = s["font"] as? String
    return Settings(
      cycleLen: clamp(s["cycleLen"], 15, 60, d.cycleLen),
      periodLen: clamp(s["periodLen"], 1, 12, d.periodLen),
      luteal: clamp(s["luteal"], 8, 18, d.luteal),
      theme: theme.map { Model.themes.contains($0) } == true ? theme! : "auto",
      font: font.map { Model.fonts.contains($0) } == true ? font! : d.font
    )
  }

  /// Begrenzt bereits typisierte Einstellungen (aus der Oberfläche)
  public static func settings(_ s: Settings) -> Settings {
    settings(["cycleLen": s.cycleLen, "periodLen": s.periodLen, "luteal": s.luteal, "theme": s.theme, "font": s.font] as [String: Any])
  }

  /// Wie JavaScript: Math.min(hi, Math.max(lo, Math.round(Number(v) || 0)))
  static func clampInt(_ v: Any?, _ lo: Int, _ hi: Int) -> Int {
    var x = jsNumber(v)
    if x.isNaN { x = 0 }
    return min(hi, max(lo, Int(jsRound(x).clamped)))
  }

  /// Wie JavaScript Number(v): Zahlen, Wahrheitswerte und Zahl-Texte, sonst NaN; fehlend = NaN, null = 0
  static func jsNumber(_ v: Any?) -> Double {
    switch v {
    case nil: return .nan
    case is NSNull: return 0
    case let n as NSNumber: return n.doubleValue
    case let i as Int: return Double(i)
    case let d as Double: return d
    case let b as Bool: return b ? 1 : 0
    case let s as String:
      let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
      return t.isEmpty ? 0 : Double(t) ?? .nan
    case let a as [Any]: return a.isEmpty ? 0 : a.count == 1 ? jsNumber(a[0]) : .nan
    default: return .nan
    }
  }

  /// Math.round rundet .5 immer nach oben
  static func jsRound(_ x: Double) -> Double { x.isNaN ? x : (x + 0.5).rounded(.down) }
}

private extension Double {
  var clamped: Double { Swift.min(Swift.max(self, -1e9), 1e9) }
}

// ---------- Export / Import ----------
public struct BackupFile: Codable, Equatable, Sendable {
  public var app: String
  public var version: Int
  public var exportedAt: String
  public var settings: Settings
  public var days: [DayEntry]
}

public enum ImportError: String, Error, Sendable {
  case invalidJSON = "invalid_json", noEntries = "no_entries", newerVersion = "newer_version"
}

public enum Backup {
  /// Baut die Backup-Datei. Der Zeitstempel wird übergeben, nicht hier erzeugt.
  public static func build(settings: Settings, days: [DayEntry], exportedAt: String) -> BackupFile {
    BackupFile(app: Model.appID, version: Model.schemaVersion, exportedAt: exportedAt, settings: settings,
               days: days.sorted { $0.date < $1.date })
  }

  /// Backup-Datei als JSON-Daten (lesbar eingerückt, Felder sortiert)
  public static func encode(_ file: BackupFile) throws -> Data {
    let enc = JSONEncoder()
    enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try enc.encode(file)
  }

  /// Liest eine Backup-Datei aus Rohdaten. Ältere Versionen werden migriert.
  public static func parse(_ data: Data) -> Result<(days: [DayEntry], settings: Settings?), ImportError> {
    guard let obj = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return .failure(.invalidJSON) }
    return parse(object: obj)
  }

  /// Liest eine bereits geparste Backup-Datei (wie parseImport in model.js).
  public static func parse(object data: Any?) -> Result<(days: [DayEntry], settings: Settings?), ImportError> {
    if let o = data as? [String: Any], Sanitize.jsNumber(o["version"]) > Double(Model.schemaVersion) { return .failure(.newerVersion) }
    let m = migrate(data)
    let days = m.days.compactMap(Sanitize.entry)
    if days.isEmpty { return .failure(.noEntries) }
    return .success((days, m.settings.map(Sanitize.settings)))
  }

  /// Hebt ältere Formate auf die aktuelle Schema-Version. Bisher: nackte Liste von Tagen oder Version 1.
  static func migrate(_ data: Any?) -> (days: [Any], settings: Any?) {
    if let a = data as? [Any] { return (a, nil) }
    let o = data as? [String: Any]
    let s = o?["settings"]
    return ((o?["days"] as? [Any]) ?? [], s is NSNull ? nil : s)
  }
}
