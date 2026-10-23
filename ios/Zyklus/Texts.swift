// Beschriftungen zu den IDs aus ZyklusKit, wie src/texts.js.

import ZyklusKit

enum Texts {
  static let flow = ["Keine", "Schmierblutung", "Leicht", "Mittel", "Stark"]
  static let mood: [String: String] = [
    "gluecklich": "Glücklich", "ruhig": "Ruhig", "energiegeladen": "Energiegeladen", "selbstbewusst": "Selbstbewusst",
    "gut": "Gut", "zufrieden": "Zufrieden", "dankbar": "Dankbar", "entspannt": "Entspannt",
    "ausgeglichen": "Ausgeglichen", "motiviert": "Motiviert", "kreativ": "Kreativ", "optimistisch": "Optimistisch",
    "verliebt": "Verliebt", "gesellig": "Gesellig",
    "sensibel": "Sensibel", "gereizt": "Gereizt", "traurig": "Traurig", "aengstlich": "Ängstlich",
    "gestresst": "Gestresst", "muede": "Müde", "lustlos": "Lustlos", "unruhig": "Unruhig",
  ]
  static let symptom: [String: String] = [
    "kraempfe": "Krämpfe", "kopfschmerzen": "Kopfschmerzen", "brustspannen": "Brustspannen", "blaehungen": "Blähungen",
    "rueckenschmerzen": "Rückenschmerzen", "unreine_haut": "Unreine Haut", "heisshunger": "Heißhunger",
    "schlafprobleme": "Schlafprobleme", "uebelkeit": "Übelkeit", "unterleibsziehen": "Ziehen im Unterleib",
  ]
  static let stimmung: [String: String] = ["gut": "Gut", "ok": "Ist ok", "schlecht": "Schlecht", "abends": "Nur abends"]
  static let energy = ["Nicht erfasst", "Sehr niedrig", "Niedrig", "Mittel", "Hoch", "Sehr hoch"]
  static let phaseName: [Phase: String] = [.men: "Menstruation", .fol: "Follikelphase", .ovu: "Eisprungphase", .lut: "Lutealphase"]
  static let phaseShort: [Phase: String] = [.men: "Periode", .fol: "Follikel", .ovu: "Eisprung", .lut: "Luteal"]
  static let theme: [String: String] = ["auto": "System", "light": "Hell", "dark": "Dunkel"]
  static let weekdayShort = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
  static let months = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September", "Oktober", "November", "Dezember"]
  static let weekdays = ["Montag", "Dienstag", "Mittwoch", "Donnerstag", "Freitag", "Samstag", "Sonntag"]

  /// Begrüßung auf der Startseite, abhängig von der Stunde
  static func greeting(_ h: Int) -> String {
    h < 5 ? "Gute Nacht!" : h < 11 ? "Guten Morgen!" : h < 14 ? "Guten Mittag!" : h < 18 ? "Guten Tag!" : h < 23 ? "Guten Abend!" : "Gute Nacht!"
  }

  static let importError: [ImportError: String] = [
    .invalidJSON: "Diese Datei ist kein Zyklus-Backup. Bitte wähle eine Datei, die mit „Backup exportieren“ gespeichert wurde.",
    .noEntries: "In der Datei wurden keine Einträge gefunden.",
    .newerVersion: "Die Datei stammt aus einer neueren Version der App. Bitte zuerst die App aktualisieren.",
  ]

  // Seiten im Netz (GitHub Pages), auch im App-Store-Eintrag verlinkt
  static let web = "https://hfpvhrmbfw-alt.github.io/zyklus-tracker/"
  static let datenschutzURL = URL(string: web + "datenschutz.html")!
  static let hilfeURL = URL(string: web + "hilfe.html")!
  static let impressumURL = URL(string: web + "impressum.html")!

  static let disclaimer = "Alle Vorhersagen sind Schätzungen aus deinen bisherigen Einträgen. Sie sind kein medizinischer Rat und nicht zur Verhütung geeignet."

  // ---------- Datum ----------
  static func plural(_ n: Int, _ one: String, _ many: String) -> String { "\(n) \(n == 1 ? one : many)" }
  /// 23.10.
  static func short(_ n: DayNum) -> String { let (_, m, d) = Day.ymd(n); return String(format: "%02d.%02d.", d, m) }
  /// Freitag, 23. Oktober 2026
  static func long(_ n: DayNum) -> String { let (y, m, d) = Day.ymd(n); return "\(weekdays[Day.weekday(n)]), \(d). \(months[m - 1]) \(y)" }
  /// Freitag, 23. Oktober
  static func dayMonth(_ n: DayNum) -> String { let (_, m, d) = Day.ymd(n); return "\(weekdays[Day.weekday(n)]), \(d). \(months[m - 1])" }
  /// 4,5 (eine Nachkommastelle, ,0 entfällt)
  static func dec(_ v: Double) -> String {
    let s = String(format: "%.1f", v).replacingOccurrences(of: ".", with: ",")
    return s.hasSuffix(",0") ? String(s.dropLast(2)) : s
  }

  /// Formuliert ein Muster als Satz (wie patternText in ui.js)
  static func pattern(_ p: Pattern) -> String {
    switch p {
    case let .energy(high, low):
      return "Deine Energie ist in der \(phaseName[high.phase]!) am höchsten (Ø \(dec(high.avg)) von 5) und in der \(phaseName[low.phase]!) am niedrigsten (Ø \(dec(low.avg)))."
    case let .frequency(kind, id, phase, share, otherShare):
      let label = (kind == .mood ? mood[id] : symptom[id]) ?? id
      let verb = kind == .mood ? "trägst du" : "notierst du"
      return "\(label) \(verb) in der \(phaseName[phase]!) an \(Int((share * 100).rounded())) % der Tage, in den übrigen Phasen an \(Int((otherShare * 100).rounded())) %."
    }
  }
}
