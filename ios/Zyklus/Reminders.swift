// Erinnerungen als lokale Mitteilungen (ohne Server) und die App-Sperre mit Face ID, Touch ID oder Code.
// Beide kennen nur das, was ihnen übergeben wird; die Logik (wann ist die nächste Periode) kommt aus ZyklusKit.

import Foundation
import LocalAuthentication
import UserNotifications
import ZyklusKit

enum Reminders {
  static let periodID = "zyklus-periode"
  static let dailyID = "zyklus-taeglich"
  /// So viele Tage vor der erwarteten Periode kommt die Erinnerung, um 9 Uhr
  static let daysBefore = 2

  /// Fragt einmal nach der Erlaubnis für Mitteilungen. true = erlaubt.
  static func requestPermission() async -> Bool {
    let c = UNUserNotificationCenter.current()
    let s = await c.notificationSettings()
    switch s.authorizationStatus {
    case .authorized, .provisional, .ephemeral: return true
    case .denied: return false
    default: return (try? await c.requestAuthorization(options: [.alert, .sound])) ?? false
    }
  }

  /// Plant alle Erinnerungen neu (nach jeder Änderung an Einträgen oder Einstellungen).
  static func schedule(prefs: DevicePrefs, analysis an: Analysis, paused: Bool, today: DayNum) {
    let c = UNUserNotificationCenter.current()
    c.removePendingNotificationRequests(withIdentifiers: [periodID, dailyID])

    if prefs.remindPeriod, !paused, let cur = an.current, cur.overdue == 0 {
      let day = cur.next - daysBefore
      if day > today || (day == today && Calendar.current.component(.hour, from: Date()) < 9) {
        let (y, m, d) = Day.ymd(day)
        add(c, periodID, body: "Deine Periode beginnt voraussichtlich in \(daysBefore) Tagen.",
            DateComponents(year: y, month: m, day: d, hour: 9, minute: 0), repeats: false)
      }
    }
    if prefs.remindDaily {
      add(c, dailyID, body: "Wie geht es dir heute? Magst du kurz eintragen?",
          DateComponents(hour: prefs.dailyMinute / 60, minute: prefs.dailyMinute % 60), repeats: true)
    }
  }

  private static func add(_ c: UNUserNotificationCenter, _ id: String, body: String, _ when: DateComponents, repeats: Bool) {
    let content = UNMutableNotificationContent()
    content.title = "Zyklus"
    content.body = body
    content.sound = .default
    c.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: repeats)))
  }
}

enum AppLock {
  /// Gibt es auf dem Gerät einen Code (und damit Face ID oder Touch ID)?
  static var available: Bool {
    var err: NSError?
    return LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)
  }

  /// Face ID, Touch ID oder Gerätecode abfragen. true = entsperrt.
  static func unlock(reason: String = "Zyklus entsperren") async -> Bool {
    let ctx = LAContext()
    ctx.localizedCancelTitle = "Abbrechen"
    return (try? await ctx.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
  }
}
