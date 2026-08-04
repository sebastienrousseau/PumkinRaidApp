import CoreText
import Foundation

@MainActor
enum RaidFontRegistrar {
  private static var didRegister = false

  static func register() {
    guard !didRegister else { return }
    didRegister = true

    for name in ["GapstownAHBold", "Creepsville"] {
      guard
        let url = Bundle.pumkinRaidResources.url(
          forResource: name,
          withExtension: "ttf",
          subdirectory: "Fonts"
        ) ?? Bundle.pumkinRaidResources.url(forResource: name, withExtension: "ttf")
      else { continue }
      CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    }
  }
}
