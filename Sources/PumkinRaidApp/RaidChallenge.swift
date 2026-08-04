import Foundation
import GameEngineLib

struct RaidChallenge: Equatable, Codable {
  let seed: UInt64
  let mode: GameMode
  let targetScore: Int
  let replayDigest: UInt64

  init(seed: UInt64, mode: GameMode, targetScore: Int, replayDigest: UInt64) {
    self.seed = seed
    self.mode = mode
    self.targetScore = max(0, targetScore)
    self.replayDigest = replayDigest
  }

  var code: String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let data = try! encoder.encode(self)
    return data.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }

  static func decode(_ code: String) -> RaidChallenge? {
    var base64 = code.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    guard let data = Data(base64Encoded: base64) else { return nil }
    return try? JSONDecoder().decode(RaidChallenge.self, from: data)
  }

  var shareText: String {
    "Beat my \(targetScore)-point Pumkin Raid! Challenge code: \(code)"
  }
}
