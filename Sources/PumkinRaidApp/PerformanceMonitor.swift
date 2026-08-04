import OSLog

#if canImport(MetricKit) && !os(tvOS)
  @preconcurrency import MetricKit

  @MainActor
  final class PerformanceMonitor: NSObject, MXMetricManagerSubscriber {
    static let shared = PerformanceMonitor()

    private let logger = Logger(
      subsystem: "com.sebastienrousseau.PumkinRaidApp",
      category: "Performance"
    )
    private var isStarted = false

    private override init() {}

    func start() {
      guard !isStarted else { return }
      isStarted = true
      MXMetricManager.shared.add(self)
    }

    nonisolated func didReceive(_ payloads: [MXMetricPayload]) {
      logger.info("Received \(payloads.count) MetricKit performance payloads")
    }

    nonisolated func didReceive(_ payloads: [MXDiagnosticPayload]) {
      logger.info("Received \(payloads.count) MetricKit diagnostic payloads")
    }
  }
#else
  @MainActor
  final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    private init() {}
    func start() {}
  }
#endif

enum FrameSignpost {
  static let log = OSLog(
    subsystem: "com.sebastienrousseau.PumkinRaidApp",
    category: "Frame"
  )

  static func begin() -> OSSignpostID {
    let identifier = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "Simulation Frame", signpostID: identifier)
    return identifier
  }

  static func end(_ identifier: OSSignpostID, steps: Int) {
    os_signpost(
      .end,
      log: log,
      name: "Simulation Frame",
      signpostID: identifier,
      "steps=%d",
      steps
    )
  }
}
