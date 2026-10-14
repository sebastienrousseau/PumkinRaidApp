import Foundation
import JavaScriptKit

/// Manages cached audio playback for the WebAssembly platform.
final class WebAudio {
  private let sounds: [String: JSObject]

  init(document: JSValue) {
    let identifiers = ["slice-sound", "hit-sound", "explode-sound", "ding-sound"]
    var soundMap: [String: JSObject] = [:]
    for id in identifiers {
      if let sound = document.getElementById(id).object {
        soundMap[id] = sound
      }
    }
    self.sounds = soundMap
  }

  func play(_ id: String) {
    guard let sound = sounds[id] else { return }
    sound.currentTime = 0
    _ = sound.play?()
  }
}
