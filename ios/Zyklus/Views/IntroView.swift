// Begrüßung beim ersten Start: was die App kann, Daten bleiben lokal, letzte Periode eintragen.

import SwiftUI
import ZyklusKit

struct IntroView: View {
  @Environment(EntryStore.self) private var store
  @State private var step = 0
  @State private var knowsStart = true
  @State private var start = Date()
  @State private var periodLen = 5
  @State private var cycleLen = 28

  var body: some View {
    VStack(spacing: 0) {
      HStack {
        HStack(spacing: 6) {
          ForEach(0..<3, id: \.self) { i in
            Capsule().fill(i == step ? Theme.accent : Theme.line).frame(width: i == step ? 22 : 8, height: 8)
          }
        }
        .accessibilityLabel("Schritt \(step + 1) von 3")
        Spacer()
        Button("Überspringen") { store.skipIntro() }.font(.sans(14, .medium)).foregroundStyle(Theme.muted)
      }
      .padding(.top, 8)
      .animation(.easeOut(duration: 0.2), value: step)

      ScrollView {
        VStack(alignment: .leading, spacing: 14) {
          switch step {
          case 0:
            art("phase-eisprung")
            title("Schön, dass du da bist")
            text("Trag ein, wie es dir geht: Blutung, Stimmung, Gefühle, Energie und Körper. Daraus erkennt die App deinen Zyklus, schätzt die nächste Periode und zeigt dir deine Muster.")
          case 1:
            art("phase-luteal")
            title("Deine Daten bleiben bei dir")
            text("Es gibt kein Konto und keinen Server. Alles liegt nur auf diesem iPhone. Die App sichert deine Einträge automatisch in der Dateien-App unter „Auf meinem iPhone › Zyklus“.")
          default:
            art("phase-periode", small: true)
            title("Wann hat deine letzte Periode begonnen?")
            text("Wenn du es nicht genau weißt, schalte es aus. Alles lässt sich später ändern.").font(.sans(14))
            VStack(spacing: 0) {
              Toggle("Ich weiß den ersten Tag", isOn: $knowsStart).padding(.vertical, 8)
              if knowsStart {
                Divider()
                DatePicker("Erster Tag", selection: $start, in: ...Date(), displayedComponents: .date).padding(.vertical, 8)
              }
              Divider()
              Stepper("Periode dauert meist \(periodLen) Tage", value: $periodLen, in: 1...12).padding(.vertical, 8)
              Divider()
              Stepper("Zyklus dauert meist \(cycleLen) Tage", value: $cycleLen, in: 15...60).padding(.vertical, 8)
            }
            .font(.sans(16))
            .card(padding: 16)
          }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }

      VStack(spacing: 10) {
        if step < 2 {
          Button { step += 1 } label: { Text("Weiter  →").frame(maxWidth: .infinity) }.buttonStyle(.pill)
        } else {
          Button { finish() } label: { Text("Los geht’s  →").frame(maxWidth: .infinity) }.buttonStyle(.pill)
          Button { store.loadDemo() } label: { Text("Erst mit Beispieldaten ausprobieren").frame(maxWidth: .infinity) }.buttonStyle(.pillGhost)
        }
      }
      .padding(.vertical, 16)
    }
    .padding(.horizontal, Theme.gutter)
    .background(Theme.bg.ignoresSafeArea())
    .foregroundStyle(Theme.ink)
    .onAppear { periodLen = store.settings.periodLen; cycleLen = store.settings.cycleLen }
    .interactiveDismissDisabled()
  }

  private func finish() {
    store.finishIntro(lastPeriodStart: knowsStart ? EntryStore.currentDay(start) : nil, cycleLen: cycleLen, periodLen: periodLen)
  }

  private func art(_ name: String, small: Bool = false) -> some View {
    Image(name).resizable().scaledToFit().frame(maxWidth: small ? 190 : 300)
      .frame(maxWidth: .infinity).padding(.vertical, small ? 12 : 28).accessibilityHidden(true)
  }
  private func title(_ s: String) -> some View { Text(s).font(.serif(32, relativeTo: .largeTitle)).accessibilityAddTraits(.isHeader) }
  private func text(_ s: String) -> Text { Text(s).font(.sans(16)).foregroundColor(Theme.muted) }
}
