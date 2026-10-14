import Foundation
import GameEngineLib
import JavaScriptKit

/// A recorded arcade run entry on the Web leaderboard.
struct WebLeaderboardEntry: Codable, Equatable {
  let id: String
  let name: String
  let score: Int
  let smashed: Int
  let combo: Int
}

/// Manages local leaderboard persistence and DOM rendering for Web.
final class WebLeaderboard {
  private let storageKeyPrefix = "pumkin_raid_board_"

  private func defaultEntries() -> [WebLeaderboardEntry] {
    [
      WebLeaderboardEntry(id: "d1", name: "Sensei Ghost", score: 95, smashed: 42, combo: 6),
      WebLeaderboardEntry(id: "d2", name: "Shadow Blade", score: 70, smashed: 31, combo: 4),
      WebLeaderboardEntry(id: "d3", name: "Pumpkin Carver", score: 50, smashed: 22, combo: 3),
      WebLeaderboardEntry(id: "d4", name: "Night Ninja", score: 35, smashed: 16, combo: 2),
      WebLeaderboardEntry(id: "d5", name: "Apprentice", score: 20, smashed: 9, combo: 2),
    ]
  }

  func loadEntries(for mode: GameMode) -> [WebLeaderboardEntry] {
    guard let storage = JSObject.global.localStorage.object else {
      return defaultEntries()
    }
    let key = "\(storageKeyPrefix)\(mode.rawValue)"
    guard let stored = storage.getItem?(key).string,
      let decoded = try? JSONDecoder().decode([WebLeaderboardEntry].self, from: Data(stored.utf8))
    else {
      return defaultEntries()
    }
    return decoded.sorted { $0.score > $1.score }
  }

  func recordScore(
    score: Int,
    smashed: Int,
    combo: Int,
    mode: GameMode
  ) -> (entries: [WebLeaderboardEntry], isNewBest: Bool, currentID: String) {
    var entries = loadEntries(for: mode)
    let previousBest = entries.first?.score ?? 0
    let isNewBest = score > previousBest && score > 0
    let currentID: String
    if let generated = JSObject.global.crypto.object?.randomUUID?().string {
      currentID = generated
    } else {
      currentID = "run_\(Int(Date().timeIntervalSince1970 * 1000))"
    }

    if score > 0 {
      let newEntry = WebLeaderboardEntry(
        id: currentID,
        name: "Ninja",
        score: score,
        smashed: smashed,
        combo: combo
      )
      entries.append(newEntry)
      entries.sort { $0.score > $1.score }
      if entries.count > 7 {
        entries = Array(entries.prefix(7))
      }
      saveEntries(entries, for: mode)
    }

    return (entries, isNewBest, currentID)
  }

  func currentGlobalBest() -> Int {
    guard let storage = JSObject.global.localStorage.object else { return 0 }
    return GameMode.allCases.compactMap {
      Int(storage.getItem?("pumkinRaid.best.\($0.rawValue)").string ?? "0")
    }.max() ?? 0
  }

  func saveBestScore(_ score: Int, mode: GameMode, document: JSValue) {
    guard let storage = JSObject.global.localStorage.object else { return }
    let key = "pumkinRaid.best.\(mode.rawValue)"
    let previous = Int(storage.getItem?(key).string ?? "0") ?? 0
    _ = storage.setItem?(key, String(max(score, previous)))
    updateBestScore(document: document)
  }

  func updateBestScore(document: JSValue) {
    document.getElementById("best").object?.innerText = .string(String(currentGlobalBest()))
  }

  private func saveEntries(_ entries: [WebLeaderboardEntry], for mode: GameMode) {
    guard let storage = JSObject.global.localStorage.object,
      let data = try? JSONEncoder().encode(entries),
      let string = String(data: data, encoding: .utf8)
    else {
      return
    }
    _ = storage.setItem?("\(storageKeyPrefix)\(mode.rawValue)", string)
  }

  func render(
    document: JSValue,
    entries: [WebLeaderboardEntry],
    currentID: String?,
    bestScore: Int
  ) {
    guard let container = document.getElementById("leaderboard-rows").object else { return }
    container.innerHTML = .string("")

    let topScore = max(bestScore, entries.first?.score ?? 0)
    if let recordElem = document.getElementById("top-record").object {
      recordElem.innerText = .string("\(topScore)")
    }

    for (index, entry) in entries.prefix(5).enumerated() {
      let rank = index + 1
      let row = document.createElement("div").object!
      let isCurrent = entry.id == currentID
      row.className = .string("leaderboard-row\(isCurrent ? " current-run" : "")")

      let rankClass: String
      switch rank {
      case 1: rankClass = "rank-1"
      case 2: rankClass = "rank-2"
      case 3: rankClass = "rank-3"
      default: rankClass = "rank-other"
      }
      let rankContent = rank <= 3 ? "\(rank)" : "#\(rank)"

      var html = "<div class=\"rank-badge \(rankClass)\">\(rankContent)</div>"
      html += "<div class=\"player-info\"><span class=\"player-name\">\(entry.name)</span>"
      if isCurrent {
        html += "<span class=\"you-tag\">YOU</span>"
      }
      html += "</div>"
      html += "<div class=\"row-score\">\(entry.score)</div>"

      row.innerHTML = .string(html)
      _ = container.appendChild!(row)
    }
  }

  func showGameOver(
    document: JSValue,
    score: Int,
    smashed: Int,
    combo: Int,
    mode: GameMode,
    bestScore: Int
  ) {
    let result = recordScore(score: score, smashed: smashed, combo: combo, mode: mode)
    document.getElementById("final-score").object?.innerText = .string("\(score)")
    document.getElementById("stat-smashed").object?.innerText = .string("\(smashed)")
    document.getElementById("stat-combo").object?.innerText = .string("\(combo)")

    if let badge = document.getElementById("new-high-badge").object {
      if result.isNewBest {
        _ = badge.classList.remove("hidden")
      } else {
        _ = badge.classList.add("hidden")
      }
    }

    if let title = document.getElementById("gameover-title").object {
      title.innerHTML = .string("GAME<br><span>OVER</span>")
    }

    let top = max(bestScore, result.entries.first?.score ?? 0)
    render(document: document, entries: result.entries, currentID: result.currentID, bestScore: top)

    _ = document.getElementById("menu").object?.classList.add("hidden")
    _ = document.getElementById("gameover").object?.classList.remove("hidden")
  }

  func showLeaderboard(document: JSValue, mode: GameMode, bestScore: Int) {
    let entries = loadEntries(for: mode)
    if let title = document.getElementById("gameover-title").object {
      title.innerHTML = .string("HIGH<br><span>SCORES</span>")
    }
    _ = document.getElementById("new-high-badge").object?.classList.add("hidden")
    document.getElementById("final-score").object?.innerText = .string("\(bestScore)")
    document.getElementById("stat-smashed").object?.innerText = .string("-")
    document.getElementById("stat-combo").object?.innerText = .string("-")

    render(document: document, entries: entries, currentID: nil, bestScore: bestScore)

    _ = document.getElementById("menu").object?.classList.add("hidden")
    _ = document.getElementById("gameover").object?.classList.remove("hidden")
  }

  func installButtons(
    document: JSValue,
    onShowScores: @escaping () -> Void,
    onReplay: @escaping () -> Void
  ) -> [JSClosure] {
    var closures: [JSClosure] = []
    if let scoresBtn = document.getElementById("scores-btn").object {
      let closure = JSClosure { _ in
        onShowScores()
        return .undefined
      }
      scoresBtn.onclick = JSValue.object(closure)
      closures.append(closure)
    }
    if let replayBtn = document.getElementById("replay-btn").object {
      let closure = JSClosure { _ in
        onReplay()
        return .undefined
      }
      replayBtn.onclick = JSValue.object(closure)
      closures.append(closure)
    }
    if let menuBtn = document.getElementById("menu-btn").object {
      let closure = JSClosure { _ in
        _ = document.getElementById("gameover").object?.classList.add("hidden")
        _ = document.getElementById("menu").object?.classList.remove("hidden")
        return .undefined
      }
      menuBtn.onclick = JSValue.object(closure)
      closures.append(closure)
    }
    return closures
  }
}

extension GameMode {
  var displayTitle: String {
    switch self {
    case .classicRaid: "CLASSIC RAID"
    case .moonRush: "MOON RUSH"
    case .spiritZen: "SPIRIT ZEN"
    case .dailyHaunt: "DAILY HAUNT"
    case .bossRaid: "BOSS RAID"
    }
  }

  var webAtmosphereTint: String {
    switch self {
    case .classicRaid: "rgba(0,0,0,0)"
    case .moonRush: "rgba(255,86,10,.07)"
    case .spiritZen: "rgba(40,190,240,.07)"
    case .dailyHaunt: "rgba(130,40,220,.09)"
    case .bossRaid: "rgba(190,0,0,.12)"
    }
  }

  static func dailySeed() -> UInt64 {
    let days = Int(Date.now.timeIntervalSince1970 / 86_400)
    return UInt64(max(0, days)) ^ 0x4441_494C_595F_5241
  }
}
