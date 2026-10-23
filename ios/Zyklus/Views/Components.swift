// Bausteine: Karten, Pillen-Knöpfe, Auswahl-Chips, Abschnittsköpfe, Leerzustände.

import SwiftUI

/// Abgerundete Karte mit feiner Linie
struct CardStyle: ViewModifier {
  var padding: CGFloat = 20
  func body(content: Content) -> some View {
    content
      .padding(padding)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Theme.surface, in: RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous).stroke(Theme.line, lineWidth: 1))
  }
}

extension View {
  func card(padding: CGFloat = 20) -> some View { modifier(CardStyle(padding: padding)) }
}

/// Orange Pille (Hauptaktion) oder umrandete Pille (Nebenaktion)
struct PillStyle: ButtonStyle {
  var ghost = false
  var small = false
  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.sans(small ? 14 : 15, .medium))
      .foregroundStyle(ghost ? Theme.ink : Theme.accentInk)
      .padding(.horizontal, small ? 16 : 20)
      .frame(minHeight: small ? 40 : 46)
      .background(Capsule().fill(ghost ? (configuration.isPressed ? Theme.sunken : .clear) : Theme.accent.opacity(configuration.isPressed ? 0.85 : 1)))
      .overlay(Capsule().stroke(ghost ? Theme.line : Theme.accent, lineWidth: 1))
      .contentShape(Capsule())
  }
}

extension ButtonStyle where Self == PillStyle {
  static var pill: PillStyle { PillStyle() }
  static var pillGhost: PillStyle { PillStyle(ghost: true) }
  static var pillSmall: PillStyle { PillStyle(small: true) }
  static var pillGhostSmall: PillStyle { PillStyle(ghost: true, small: true) }
}

/// Auswahl-Chip: grün mit Haken, Blutung orange, Stimmung mit Farbpunkt
struct Chip: View {
  let label: String
  let selected: Bool
  var tint: Color = Theme.sageTint
  var border: Color = Theme.sage
  var dot: Color?
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 7) {
        if let dot { Circle().fill(dot).frame(width: 10, height: 10) }
        else if selected { Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)) }
        Text(label)
      }
      .font(.sans(14, .medium))
      .foregroundStyle(Theme.ink)
      .padding(.horizontal, 15)
      .frame(minHeight: 40)
      .background(Capsule().fill(selected ? tint : .clear))
      .overlay(Capsule().stroke(selected ? border : Theme.line, lineWidth: 1))
      .contentShape(Capsule())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}

/// Zeilenumbrechendes Layout für Chips
struct FlowLayout: Layout {
  var spacing: CGFloat = 8

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let rows = arrange(proposal.width ?? .infinity, subviews)
    let h = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
    return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: h)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var y = bounds.minY
    for row in arrange(bounds.width, subviews) {
      var x = bounds.minX
      for i in row.items {
        let s = subviews[i].sizeThatFits(.unspecified)
        subviews[i].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
        x += s.width + spacing
      }
      y += row.height + spacing
    }
  }

  private struct Row { var items: [Int] = []; var width: CGFloat = 0; var height: CGFloat = 0 }

  private func arrange(_ maxWidth: CGFloat, _ subviews: Subviews) -> [Row] {
    var rows = [Row()]
    for i in subviews.indices {
      let s = subviews[i].sizeThatFits(.unspecified)
      if !rows[rows.count - 1].items.isEmpty && rows[rows.count - 1].width + spacing + s.width > maxWidth { rows.append(Row()) }
      var r = rows[rows.count - 1]
      r.width += (r.items.isEmpty ? 0 : spacing) + s.width
      r.height = max(r.height, s.height)
      r.items.append(i)
      rows[rows.count - 1] = r
    }
    return rows
  }
}

/// Überschrift eines Abschnitts, optional mit Link rechts
struct SectionHead<Trailing: View>: View {
  let title: String
  @ViewBuilder var trailing: Trailing
  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(title).font(.serif(24)).foregroundStyle(Theme.ink)
      Spacer()
      trailing
    }
    .padding(.bottom, 4)
  }
}

extension SectionHead where Trailing == EmptyView {
  init(_ title: String) { self.title = title; self.trailing = EmptyView() }
}

/// Hinweisfeld (farbig hinterlegt, fettes Stichwort vorne)
struct Note: View {
  let label: String
  let text: String
  var tint: Color = Theme.warnTint
  var labelColor: Color = Theme.warn
  var body: some View {
    (Text(label + "  ").font(.sans(14, .semibold)).foregroundColor(labelColor) + Text(text).font(.sans(14)).foregroundColor(Theme.ink))
      .padding(.horizontal, 18).padding(.vertical, 14)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(tint, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
  }
}

/// Leerzustand: Bild, Überschrift, kurzer Text, ein Knopf
struct EmptyCard: View {
  let image: String
  let title: String
  let text: String
  var button: String?
  var action: () -> Void = {}
  var body: some View {
    VStack(spacing: 10) {
      Image(image).resizable().scaledToFit().frame(maxWidth: 220).accessibilityHidden(true)
      Text(title).font(.serif(24)).multilineTextAlignment(.center)
      Text(text).font(.sans(15)).foregroundStyle(Theme.muted).multilineTextAlignment(.center).frame(maxWidth: 300)
      if let button { Button("\(button)  →", action: action).buttonStyle(.pill).padding(.top, 8) }
    }
    .frame(maxWidth: .infinity)
    .card(padding: 26)
  }
}
