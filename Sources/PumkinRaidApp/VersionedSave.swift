import Foundation

/// A small migration boundary around persisted app state. Payloads written by
/// older builds are still accepted, while unknown future schemas fail safely.
struct VersionedSave<Payload: Codable>: Codable {
  static var currentSchemaVersion: Int { 1 }

  let schemaVersion: Int
  let payload: Payload

  init(payload: Payload) {
    schemaVersion = Self.currentSchemaVersion
    self.payload = payload
  }

  static func encode(_ payload: Payload) -> Data? {
    try? JSONEncoder().encode(Self(payload: payload))
  }

  static func decode(_ data: Data) -> Payload? {
    let decoder = JSONDecoder()
    if let save = try? decoder.decode(Self.self, from: data),
      save.schemaVersion == currentSchemaVersion
    {
      return save.payload
    }
    // Migration path for the unversioned JSON written by releases before v2.
    return try? decoder.decode(Payload.self, from: data)
  }
}
