import AVFoundation
import OSLog

@MainActor
final class AudioManager {
  static let shared = AudioManager()

  private let logger = Logger(subsystem: "com.sebastienrousseau.PumkinRaidApp", category: "Audio")
  private var musicPlayer: AVAudioPlayer?
  private var effectPlayers: [AVAudioPlayer] = []
  private var effectData: [String: Data] = [:]
  private var variationCounter = 0
  private var currentIntensity = -1

  private init() {
    configureSession()
    preloadEffects(["bow_wah", "creaking_door", "ding", "explode", "female_scream", "slice"])
  }

  func startMusic(enabled: Bool) {
    guard enabled else {
      stopMusic()
      return
    }
    if let musicPlayer {
      if !musicPlayer.isPlaying { musicPlayer.play() }
      return
    }
    guard let url = resourceURL(name: "mysterious_house", extensions: ["mp3"]) else {
      logger.error("Music resource is missing")
      return
    }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = 0.82
      player.enableRate = true
      player.rate = 1
      player.prepareToPlay()
      guard player.play() else {
        logger.error("Music player could not start")
        return
      }
      musicPlayer = player
    } catch {
      logger.error("Failed to load music: \(error.localizedDescription, privacy: .public)")
    }
  }

  /// Adjusts the available music bed without changing gameplay. New stems can be
  /// added later without changing scene call sites.
  func setIntensity(_ normalized: Double) {
    let bucket = min(4, max(0, Int(normalized * 4)))
    guard bucket != currentIntensity else { return }
    currentIntensity = bucket
    let amount = Float(bucket) / 4
    musicPlayer?.setVolume(0.72 + amount * 0.22, fadeDuration: 0.35)
    musicPlayer?.rate = 0.96 + amount * 0.08
  }

  func stopMusic() {
    musicPlayer?.stop()
    musicPlayer = nil
    currentIntensity = -1
  }

  func stopAll() {
    stopMusic()
    for player in effectPlayers { player.stop() }
    effectPlayers.removeAll(keepingCapacity: true)
  }

  func play(_ name: String, enabled: Bool) {
    guard enabled else { return }
    do {
      let player: AVAudioPlayer
      if let data = effectData[name] {
        player = try AVAudioPlayer(data: data)
      } else if let url = resourceURL(name: name, extensions: ["wav", "aifc"]) {
        player = try AVAudioPlayer(contentsOf: url)
      } else {
        logger.error("Effect resource is missing: \(name, privacy: .public)")
        return
      }
      effectPlayers.removeAll { !$0.isPlaying }
      variationCounter &+= 1
      player.enableRate = true
      player.rate = [0.96, 1, 1.04][variationCounter % 3]
      player.volume = 0.94
      player.prepareToPlay()
      guard player.play() else {
        logger.error("Effect could not start: \(name, privacy: .public)")
        return
      }
      effectPlayers.append(player)
    } catch {
      logger.error(
        "Failed to load effect \(name, privacy: .public): \(error.localizedDescription, privacy: .public)"
      )
    }
  }

  private func preloadEffects(_ names: [String]) {
    for name in names {
      guard let url = resourceURL(name: name, extensions: ["wav", "aifc"]),
        let data = try? Data(contentsOf: url)
      else { continue }
      effectData[name] = data
    }
  }

  private func resourceURL(name: String, extensions: [String]) -> URL? {
    for fileExtension in extensions {
      if let url = Bundle.pumkinRaidResources.url(
        forResource: name,
        withExtension: fileExtension,
        subdirectory: "Audio"
      ) ?? Bundle.pumkinRaidResources.url(forResource: name, withExtension: fileExtension) {
        return url
      }
    }
    return nil
  }

  private func configureSession() {
    #if os(iOS) || os(tvOS)
      do {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try session.setActive(true)
      } catch {
        logger.error(
          "Could not configure audio session: \(error.localizedDescription, privacy: .public)")
      }
    #endif
  }
}
