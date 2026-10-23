// Dieselben Testfälle wie tests/logic.test.js. Die Fixtures liegen im Repo unter tests/fixtures/
// und werden direkt von dort gelesen, damit Web-App und iOS-App gegen dieselben Erwartungen laufen.

import XCTest
@testable import ZyklusKit

private let fixtures = URL(fileURLWithPath: #filePath)
  .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent() // ZyklusKit
  .deletingLastPathComponent().deletingLastPathComponent() // Repo
  .appendingPathComponent("tests/fixtures")

private func load(_ name: String) throws -> Any {
  try JSONSerialization.jsonObject(with: Data(contentsOf: fixtures.appendingPathComponent(name)), options: [.fragmentsAllowed])
}

/// Wandelt einen Swift-Wert über JSON in dieselbe Form wie die Fixtures.
private func plain<T: Encodable>(_ v: T) throws -> Any {
  try JSONSerialization.jsonObject(with: JSONEncoder().encode(v), options: [.fragmentsAllowed])
}

/// Vergleich mit Toleranz für Kommazahlen (Fixtures sind auf 6 Stellen gerundet).
private func near(_ a: Any?, _ e: Any?, _ path: String = "", file: StaticString = #filePath, line: UInt = #line) {
  switch (a, e) {
  case (nil, nil), (is NSNull, nil), (nil, is NSNull), (is NSNull, is NSNull): return
  case let (x as NSNumber, y as NSNumber):
    XCTAssertLessThan(abs(x.doubleValue - y.doubleValue), 1e-6, "\(path): \(x) ≠ \(y)", file: file, line: line)
  case let (x as String, y as String): XCTAssertEqual(x, y, path, file: file, line: line)
  case let (x as [Any], y as [Any]):
    XCTAssertEqual(x.count, y.count, "\(path): Länge", file: file, line: line)
    for i in 0..<min(x.count, y.count) { near(x[i], y[i], "\(path)[\(i)]", file: file, line: line) }
  case let (x as [String: Any], y as [String: Any]):
    XCTAssertEqual(Set(x.keys), Set(y.keys), "\(path): Felder", file: file, line: line)
    for (k, v) in y { near(x[k], v, "\(path).\(k)", file: file, line: line) }
  default: XCTFail("\(path): \(String(describing: a)) ≠ \(String(describing: e))", file: file, line: line)
  }
}

final class ZyklusKitTests: XCTestCase {
  func testAnalyseFixtures() throws {
    let files = try FileManager.default.contentsOfDirectory(atPath: fixtures.path).filter { $0.hasPrefix("analyse-") }.sorted()
    XCTAssertFalse(files.isEmpty, "Keine Fixtures gefunden unter \(fixtures.path)")
    for file in files {
      let fx = try load(file) as! [String: Any]
      let input = fx["input"] as! [String: Any], expected = fx["expected"] as! [String: Any]
      let today = Day.num(input["today"] as! String)
      let days = (input["days"] as! [Any]).compactMap(Sanitize.entry)
      let settings = Sanitize.settings(input["settings"])
      let an = Logic.analyze(days, settings: settings, today: today)
      near(try plain(an), expected["analyze"], "\(file) analyze")
      for (date, ph) in expected["phases"] as! [String: Any] {
        let got = Logic.phaseOf(an, Day.num(date))
        near(try got.map(plain) ?? NSNull(), ph, "\(file) phaseOf \(date)")
      }
      let st = Logic.moodStats(an, days, today: today)
      near(try plain(Dictionary(uniqueKeysWithValues: st.map { ($0.key.rawValue, $0.value) })), expected["moodStats"], "\(file) moodStats")
      near(try plain(Logic.findPatterns(st)), expected["patterns"], "\(file) findPatterns")
    }
  }

  func testDemoIstReproduzierbar() throws {
    let fx = try load("analyse-demo.json") as! [String: Any]
    let input = fx["input"] as! [String: Any]
    near(try plain(Logic.makeDemo(today: Day.num(input["today"] as! String))), input["days"], "makeDemo")
  }

  func testSanitize() throws {
    for case let c as [String: Any] in try load("sanitize.json") as! [Any] {
      let got = Sanitize.entry(c["input"] is NSNull ? nil : c["input"])
      near(try got.map(plain) ?? NSNull(), c["expected"], "sanitize")
    }
  }

  func testImport() throws {
    for case let c as [String: Any] in try load("import.json") as! [Any] {
      let name = c["name"] as! String, e = c["expected"] as! [String: Any]
      switch Backup.parse(object: c["input"] is NSNull ? nil : c["input"]) {
      case let .success(r):
        XCTAssertEqual(e["ok"] as? Bool, true, name)
        near(try plain(r.days), e["days"], name)
        near(try r.settings.map(plain) ?? NSNull(), e["settings"], name)
      case let .failure(err):
        XCTAssertEqual(e["ok"] as? Bool, false, name)
        XCTAssertEqual(err.rawValue, e["error"] as? String, name)
      }
    }
  }

  func testExportLaesstSichWiederImportieren() throws {
    let days = [DayEntry(date: "2026-03-02", flow: 3), DayEntry(date: "2026-03-01", moods: ["ruhig"])]
    let file = Backup.build(settings: .defaults, days: days, exportedAt: "2026-10-12T08:00:00.000Z")
    XCTAssertEqual(file.days.map(\.date), ["2026-03-01", "2026-03-02"])
    guard case let .success(back) = Backup.parse(try Backup.encode(file)) else { return XCTFail("Import fehlgeschlagen") }
    XCTAssertEqual(back.days, file.days)
    XCTAssertEqual(back.settings, .defaults)
    if case .failure(.invalidJSON) = Backup.parse(Data("kein json".utf8)) {} else { XCTFail("kaputte Datei nicht erkannt") }
  }

  func testEinstellungenWerdenBegrenzt() {
    XCTAssertEqual(Sanitize.settings(["cycleLen": 5, "periodLen": "x", "luteal": 30, "theme": "neon", "font": "comic"] as [String: Any]),
                   Settings(cycleLen: 15, periodLen: 5, luteal: 18, theme: "auto", font: "klar"))
    XCTAssertEqual(Sanitize.settings(["font": "mix"] as [String: Any]).font, "mix")
    XCTAssertEqual(Sanitize.settings(nil), .defaults)
  }

  func testDatumIstZeitzonenfest() {
    XCTAssertEqual(Day.str(Day.num("2026-03-29")), "2026-03-29")
    XCTAssertEqual(Day.num("2026-01-01") - Day.num("2025-12-31"), 1)
    XCTAssertEqual(Day.num("1970-01-01"), 0)
    XCTAssertEqual(Day.num("2026-10-12"), 20738)
    XCTAssertEqual(Day.weekday(Day.num("2026-10-23")), 4) // Freitag
  }

  func testKleineHelfer() {
    XCTAssertTrue(DayEntry.blank("2026-01-01").isEmpty)
    XCTAssertEqual(Logic.moodDots(DayEntry(date: "2026-01-01", moods: ["gereizt", "ruhig"])), ["gut", "schlecht"])
    XCTAssertEqual(Logic.moodDots(DayEntry(date: "2026-01-01", stimmung: ["abends"], moods: ["gereizt"])), ["abends"])
  }

  func testBackupErinnerung() {
    let t = 1000
    XCTAssertFalse(Logic.backupDue(count: 4, first: t - 90, lastBackup: nil, snoozed: nil, today: t))
    XCTAssertFalse(Logic.backupDue(count: 5, first: t - 29, lastBackup: nil, snoozed: nil, today: t))
    XCTAssertTrue(Logic.backupDue(count: 5, first: t - 30, lastBackup: nil, snoozed: nil, today: t))
    XCTAssertFalse(Logic.backupDue(count: 50, first: t - 200, lastBackup: t - 10, snoozed: nil, today: t))
    XCTAssertTrue(Logic.backupDue(count: 50, first: t - 200, lastBackup: t - 31, snoozed: nil, today: t))
    XCTAssertFalse(Logic.backupDue(count: 50, first: t - 200, lastBackup: t - 31, snoozed: t - 3, today: t))
    XCTAssertTrue(Logic.backupDue(count: 50, first: t - 200, lastBackup: t - 31, snoozed: t - 7, today: t))
  }

  func testBegruessungTraegtPeriodeEin() {
    let t = Day.num("2026-10-23")
    let list = Logic.introPeriod(start: Day.num("2026-10-21"), periodLen: 5, today: t)
    XCTAssertEqual(list.map(\.date), ["2026-10-21", "2026-10-22", "2026-10-23"])
    XCTAssertTrue(list.allSatisfy { $0.flow == 2 })
    let an = Logic.analyze(Logic.introPeriod(start: Day.num("2026-10-01"), periodLen: 5, today: t), settings: .defaults, today: t)
    XCTAssertEqual(an.periods.count, 1)
  }
}
