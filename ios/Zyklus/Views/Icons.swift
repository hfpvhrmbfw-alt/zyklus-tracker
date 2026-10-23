// Strich-Symbole aus der Web-App (src/art.js, ICON), gleiche Pfade im 24er-Raster.

import SwiftUI

enum LineIconKind { case home, cal, chart, gear }

struct LineIcon: View {
  let kind: LineIconKind
  var size: CGFloat = 24
  var weight: CGFloat = 1.7

  var body: some View {
    Canvas { ctx, sz in
      let s = sz.width / 24
      ctx.scaleBy(x: s, y: s)
      let style = StrokeStyle(lineWidth: weight, lineCap: .round, lineJoin: .round)
      let shading = GraphicsContext.Shading.foreground
      ctx.stroke(LineIcon.path(kind), with: shading, style: style)
      if kind == .cal { ctx.fill(Path(ellipseIn: CGRect(x: 10.8, y: 13.8, width: 2.4, height: 2.4)), with: shading) }
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }

  private static func line(_ p: inout Path, _ a: CGPoint, _ b: CGPoint) { p.move(to: a); p.addLine(to: b) }

  static func path(_ kind: LineIconKind) -> Path {
    var p = Path()
    switch kind {
    case .home:
      p.move(to: CGPoint(x: 4, y: 11))
      p.addLine(to: CGPoint(x: 12, y: 4))
      p.addLine(to: CGPoint(x: 20, y: 11))
      p.addLine(to: CGPoint(x: 20, y: 19.5))
      p.addQuadCurve(to: CGPoint(x: 19.5, y: 20), control: CGPoint(x: 20, y: 20))
      p.addLine(to: CGPoint(x: 15, y: 20))
      p.addLine(to: CGPoint(x: 15, y: 14))
      p.addLine(to: CGPoint(x: 9, y: 14))
      p.addLine(to: CGPoint(x: 9, y: 20))
      p.addLine(to: CGPoint(x: 4.5, y: 20))
      p.addQuadCurve(to: CGPoint(x: 4, y: 19.5), control: CGPoint(x: 4, y: 20))
      p.closeSubpath()
    case .cal:
      p.addRoundedRect(in: CGRect(x: 3.5, y: 5, width: 17, height: 15), cornerSize: CGSize(width: 2.5, height: 2.5))
      line(&p, CGPoint(x: 3.5, y: 10), CGPoint(x: 20.5, y: 10))
      line(&p, CGPoint(x: 8, y: 3), CGPoint(x: 8, y: 7))
      line(&p, CGPoint(x: 16, y: 3), CGPoint(x: 16, y: 7))
    case .chart:
      line(&p, CGPoint(x: 4, y: 20), CGPoint(x: 20, y: 20))
      for r in [CGRect(x: 5.5, y: 11, width: 3, height: 6), CGRect(x: 10.5, y: 6, width: 3, height: 11), CGRect(x: 15.5, y: 9, width: 3, height: 8)] {
        p.addRoundedRect(in: r, cornerSize: CGSize(width: 1, height: 1))
      }
    case .gear:
      line(&p, CGPoint(x: 4, y: 7), CGPoint(x: 13, y: 7))
      line(&p, CGPoint(x: 17, y: 7), CGPoint(x: 20, y: 7))
      line(&p, CGPoint(x: 4, y: 17), CGPoint(x: 7, y: 17))
      line(&p, CGPoint(x: 11, y: 17), CGPoint(x: 20, y: 17))
      p.addEllipse(in: CGRect(x: 12.8, y: 4.8, width: 4.4, height: 4.4))
      p.addEllipse(in: CGRect(x: 6.8, y: 14.8, width: 4.4, height: 4.4))
    }
    return p
  }
}
