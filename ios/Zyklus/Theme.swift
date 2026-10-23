// Farben und Schriften wie in styles.css (Stil „Beet“): warmes Beige hell, fast Schwarz dunkel, orange Akzente.

import SwiftUI
import UIKit

extension Color {
  /// Farbe mit eigenem Wert für hell und dunkel (Hex ohne #)
  init(light: UInt32, dark: UInt32) {
    self.init(UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
  }
  init(hex: UInt32) { self.init(UIColor(hex: hex)) }
}

extension UIColor {
  convenience init(hex: UInt32) {
    self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
  }
}

enum Theme {
  static let bg = Color(light: 0xEADFCC, dark: 0x1C1B1A)
  static let surface = Color(light: 0xEFE6D6, dark: 0x252321)
  static let sunken = Color(light: 0xE0D3BD, dark: 0x302D2A)
  static let line = Color(light: 0xB9AA91, dark: 0x4E4943)
  static let lineSoft = Color(light: 0xD2C4AC, dark: 0x3A3632)
  static let ink = Color(light: 0x1E1A16, dark: 0xEFE6D6)
  static let muted = Color(light: 0x5C5247, dark: 0xB6AB9B)
  static let faint = Color(light: 0x8C8071, dark: 0x80776C)
  static let accent = Color(hex: 0xF47A4B)
  static let accentInk = Color(light: 0x1E1A16, dark: 0x1C1B1A)
  static let accentText = Color(light: 0xA9461C, dark: 0xFF9A70)
  static let accentTint = Color(light: 0xF6D2BE, dark: 0x4A2C1F)
  static let sage = Color(light: 0x5E8F6E, dark: 0x8DBB9A)
  static let sageTint = Color(light: 0xBFD6C3, dark: 0x3B5446)
  static let warnTint = Color(light: 0xF0DDB3, dark: 0x352B17)
  static let warn = Color(light: 0x7A5200, dark: 0xE3B55E)
  static let okTint = Color(light: 0xD3E2CF, dark: 0x25332A)
  static let err = Color(light: 0xA3182B, dark: 0xF08A8F)

  /// Farbe der Stimmungspunkte im Kalender
  static func mood(_ id: String) -> Color {
    switch id {
    case "gut": return Color(light: 0x2E8B47, dark: 0x6FCB85)
    case "ok": return Color(light: 0xD9A300, dark: 0xEBC84B)
    case "schlecht": return Color(light: 0xC8283C, dark: 0xF0707A)
    default: return Color(light: 0x7B4FC2, dark: 0xB596EE)
    }
  }

  static let radius: CGFloat = 20
  static let gutter: CGFloat = 20
}

/// Schriften: Überschriften DM Serif Display, Text Outfit. Wachsen mit der Textgröße des Systems mit.
extension Font {
  static func serif(_ size: CGFloat, relativeTo style: Font.TextStyle = .title) -> Font {
    .custom("DMSerifDisplay-Regular", size: size, relativeTo: style)
  }
  static func sans(_ size: CGFloat, _ weight: SansWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
    .custom(weight.rawValue, size: size, relativeTo: style)
  }
  enum SansWeight: String { case regular = "Outfit-Regular", medium = "Outfit-Medium", semibold = "Outfit-SemiBold" }
}
