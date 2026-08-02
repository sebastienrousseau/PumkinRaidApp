import SpriteKit

#if os(iOS)
  import UIKit
#elseif os(macOS)
  import AppKit
#endif

extension Bundle {
  static var pumkinRaidResources: Bundle {
    #if SWIFT_PACKAGE
      .module
    #else
      .main
    #endif
  }
}

@MainActor
enum AssetLoader {
  static func imageURL(_ name: String) -> URL? {
    Bundle.pumkinRaidResources.url(forResource: name, withExtension: "png", subdirectory: "Images")
      ?? Bundle.pumkinRaidResources.url(forResource: name, withExtension: "png")
  }

  #if os(iOS)
    static func image(_ name: String) -> UIImage? {
      guard let url = imageURL(name) else { return nil }
      return UIImage(contentsOfFile: url.path)
    }
  #elseif os(macOS)
    static func image(_ name: String) -> NSImage? {
      guard let url = imageURL(name) else { return nil }
      return NSImage(contentsOf: url)
    }
  #endif

  static func texture(_ name: String) -> SKTexture {
    #if os(iOS)
      guard let image = image(name) else { return SKTexture() }
      return SKTexture(image: image)
    #elseif os(macOS)
      guard let image = image(name) else { return SKTexture() }
      return SKTexture(image: image)
    #endif
  }
}
