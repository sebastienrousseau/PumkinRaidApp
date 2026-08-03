import SpriteKit

#if os(iOS) || os(tvOS)
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
    let bundle = Bundle.pumkinRaidResources
    return bundle.url(forResource: name, withExtension: "png", subdirectory: "Images")
      ?? bundle.url(forResource: name, withExtension: "jpg", subdirectory: "Images/Adaptive")
      ?? bundle.url(forResource: name, withExtension: "png")
      ?? bundle.url(forResource: name, withExtension: "jpg")
  }

  #if os(iOS) || os(tvOS)
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
    #if os(iOS) || os(tvOS)
      guard let image = image(name) else { return SKTexture() }
      return SKTexture(image: image)
    #elseif os(macOS)
      guard let image = image(name) else { return SKTexture() }
      return SKTexture(image: image)
    #endif
  }
}
