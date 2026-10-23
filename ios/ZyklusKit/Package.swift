// swift-tools-version:5.9
// Modell und Logik der Zyklus-App, 1:1 aus src/model.js und src/logic.js übertragen.
// Ohne Oberfläche und ohne Speicher, damit sie für sich getestet werden können.
import PackageDescription

let package = Package(
  name: "ZyklusKit",
  platforms: [.iOS(.v17), .macOS(.v14)],
  products: [.library(name: "ZyklusKit", targets: ["ZyklusKit"])],
  targets: [
    .target(name: "ZyklusKit"),
    .testTarget(name: "ZyklusKitTests", dependencies: ["ZyklusKit"]),
  ]
)
