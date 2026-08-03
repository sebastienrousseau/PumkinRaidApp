import AVFoundation

@MainActor
final class AudioManager {
  static let shared = AudioManager()

  private var musicPlayer: AVAudioPlayer?
  private var effectPlayers: [AVAudioPlayer] = []

  func startMusic(enabled: Bool) {
    guard enabled else {
      stopMusic()
      return
    }
    guard musicPlayer?.isPlaying != true,
      let url = Bundle.pumkinRaidResources.url(
        forResource: "mysterious_house", withExtension: "mp3", subdirectory: "Audio")
        ?? Bundle.pumkinRaidResources.url(forResource: "mysterious_house", withExtension: "mp3")
    else { return }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      player.numberOfLoops = -1
      player.volume = 1
      player.prepareToPlay()
      guard player.play() else {
        print("PumkinRaidApp: the music player could not start")
        return
      }
      musicPlayer = player
    } catch {
      print("PumkinRaidApp: failed to load music: \(error)")
    }
  }

  func stopMusic() {
    musicPlayer?.stop()
    musicPlayer = nil
  }

  func stopAll() {
    stopMusic()
    for player in effectPlayers {
      player.stop()
    }
    effectPlayers.removeAll()
  }

  func play(_ name: String, enabled: Bool) {
    guard enabled,
      let url = Bundle.pumkinRaidResources.url(
        forResource: name, withExtension: "wav", subdirectory: "Audio")
        ?? Bundle.pumkinRaidResources.url(forResource: name, withExtension: "wav")
        ?? Bundle.pumkinRaidResources.url(
          forResource: name, withExtension: "aifc", subdirectory: "Audio")
        ?? Bundle.pumkinRaidResources.url(forResource: name, withExtension: "aifc")
    else { return }
    do {
      let player = try AVAudioPlayer(contentsOf: url)
      effectPlayers.removeAll { !$0.isPlaying }
      player.volume = 1
      player.prepareToPlay()
      guard player.play() else {
        print("PumkinRaidApp: effect '\(name)' could not start")
        return
      }
      effectPlayers.append(player)
    } catch {
      print("PumkinRaidApp: failed to load effect '\(name)': \(error)")
    }
  }
}
