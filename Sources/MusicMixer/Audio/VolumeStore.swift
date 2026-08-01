import Foundation

/// Persists per-app volume and mute state across launches, keyed by the
/// app's persistence key (bundle ID or executable name).
struct VolumeStore {

    private static let defaultsKey = "perAppAudioState"

    struct State {
        var volume: Float
        var isMuted: Bool
    }

    /// Saved state for an app, if any.
    func state(for key: String) -> State? {
        guard let all = UserDefaults.standard.dictionary(forKey: Self.defaultsKey),
              let entry = all[key] as? [String: Any],
              let volume = entry["volume"] as? Double else { return nil }
        let muted = entry["muted"] as? Bool ?? false
        return State(volume: Float(min(max(volume, 0), 1)), isMuted: muted)
    }

    func save(volume: Float, isMuted: Bool, for key: String) {
        var all = UserDefaults.standard.dictionary(forKey: Self.defaultsKey) ?? [:]
        all[key] = ["volume": Double(volume), "muted": isMuted]
        UserDefaults.standard.set(all, forKey: Self.defaultsKey)
    }
}
