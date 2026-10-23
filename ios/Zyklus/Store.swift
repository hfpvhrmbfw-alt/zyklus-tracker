// Speicher: hält Einträge und Einstellungen, schreibt sie als Datei in den App-Container
// und legt nach jeder Änderung eine Sicherung im Ordner „Auf meinem iPhone › Zyklus“ ab.

import Foundation
import Observation
import ZyklusKit

@Observable
final class EntryStore {
  private(set) var days: [String: DayEntry] = [:]
  private(set) var settings = Settings.defaults
  private(set) var onboarded = false
  private(set) var demo = false
  /// Tag der letzten automatischen Sicherung
  private(set) var lastBackup: DayNum?
  /// Wird bei Datumswechsel neu gesetzt, damit „heute“ stimmt
  var today: DayNum = EntryStore.currentDay()

  /// Wie viele Tagessicherungen im Ordner bleiben
  static let keepBackups = 10

  private let stateURL: URL
  private let backupDir: URL

  init(directory: URL? = nil) {
    let fm = FileManager.default
    let support = directory ?? fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    try? fm.createDirectory(at: support, withIntermediateDirectories: true)
    stateURL = support.appendingPathComponent("zyklus.json")
    backupDir = directory?.appendingPathComponent("Sicherungen") ?? fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    load()
  }

  // ---------- Lesen ----------
  var entries: [DayEntry] { Array(days.values) }
  var analysis: Analysis { Logic.analyze(entries, settings: settings, today: today) }
  func entry(_ n: DayNum) -> DayEntry { days[Day.str(n)] ?? .blank(Day.str(n)) }

  /// Heute als Tagnummer in lokaler Zeit. Einzige Stelle, die die Uhr liest.
  static func currentDay(_ date: Date = Date()) -> DayNum {
    let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
    return Day.num(year: c.year!, month: c.month!, day: c.day!)
  }

  func refreshToday() { today = Self.currentDay() }

  // ---------- Ändern ----------
  func save(_ e: DayEntry) {
    if e.isEmpty { days[e.date] = nil } else { days[e.date] = e }
    persist()
  }

  func update(settings s: Settings) {
    settings = Sanitize.settings(s)
    persist()
  }

  /// Begrüßung abschließen, optional mit der letzten Periode
  func finishIntro(lastPeriodStart: DayNum?, cycleLen: Int, periodLen: Int) {
    var s = settings; s.cycleLen = cycleLen; s.periodLen = periodLen
    settings = Sanitize.settings(s)
    if let start = lastPeriodStart {
      for e in Logic.introPeriod(start: start, periodLen: settings.periodLen, today: today) { days[e.date] = e }
    }
    onboarded = true
    persist()
  }

  func skipIntro() { onboarded = true; persist() }

  func loadDemo() {
    days = Dictionary(uniqueKeysWithValues: Logic.makeDemo(today: today).map { ($0.date, $0) })
    demo = true; onboarded = true
    persist()
  }

  func wipe() {
    days = [:]; demo = false
    persist()
  }

  // ---------- Backup ----------
  /// Backup-Datei mit allen Einträgen und Einstellungen
  func backupData() throws -> Data {
    try Backup.encode(Backup.build(settings: settings, days: entries, exportedAt: ISO8601DateFormatter().string(from: Date())))
  }

  /// Lesbarer Dateiname, z. B. „Zyklus-Backup 23.10.2026.json“
  static func backupName(_ n: DayNum) -> String {
    let (y, m, d) = Day.ymd(n)
    return String(format: "Zyklus-Backup %02d.%02d.%04d.json", d, m, y)
  }

  /// Liest eine Backup-Datei ein. Einträge an gleichen Tagen werden überschrieben.
  @discardableResult
  func importBackup(_ data: Data) -> Result<Int, ImportError> {
    switch Backup.parse(data) {
    case let .success(r):
      r.days.forEach { days[$0.date] = $0 }
      if let s = r.settings { settings = s }
      demo = false; onboarded = true
      persist()
      return .success(r.days.count)
    case let .failure(e):
      return .failure(e)
    }
  }

  /// Schreibt die Sicherung des Tages in den Zyklus-Ordner und räumt alte auf. Demodaten werden nicht gesichert.
  private func autoBackup() {
    guard !demo, !days.isEmpty, let data = try? backupData() else { return }
    let fm = FileManager.default
    try? fm.createDirectory(at: backupDir, withIntermediateDirectories: true)
    do {
      try data.write(to: backupDir.appendingPathComponent(Self.backupName(today)), options: .atomic)
      lastBackup = today
    } catch { return }
    let files = ((try? fm.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
      .filter { $0.lastPathComponent.hasPrefix("Zyklus-Backup ") && $0.pathExtension == "json" }
      .sorted { modDate($0) > modDate($1) }
    files.dropFirst(Self.keepBackups).forEach { try? fm.removeItem(at: $0) }
  }

  private func modDate(_ u: URL) -> Date {
    (try? u.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
  }

  // ---------- Datei im App-Container ----------
  private func load() {
    guard let data = try? Data(contentsOf: stateURL),
          let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return }
    // Über dieselbe Prüfung wie beim Import lesen, damit auch ältere oder beschädigte Dateien sauber ankommen
    let list = ((obj["days"] as? [Any]) ?? []).compactMap(Sanitize.entry)
    days = Dictionary(list.map { ($0.date, $0) }, uniquingKeysWith: { $1 })
    settings = Sanitize.settings(obj["settings"])
    onboarded = (obj["onboarded"] as? Bool) ?? !days.isEmpty
    demo = (obj["demo"] as? Bool) ?? false
    lastBackup = obj["lastBackup"] as? Int
  }

  /// Gleiches Format wie die Backup-Datei, ergänzt um den Zustand der App
  private struct State: Encodable {
    var app = Model.appID
    var version = Model.schemaVersion
    var settings: Settings
    var days: [DayEntry]
    var onboarded: Bool
    var demo: Bool
    var lastBackup: DayNum?
  }

  private func persist() {
    autoBackup()
    let s = State(settings: settings, days: entries.sorted { $0.date < $1.date }, onboarded: onboarded, demo: demo, lastBackup: lastBackup)
    if let data = try? JSONEncoder().encode(s) { try? data.write(to: stateURL, options: .atomic) }
  }
}
