import AppKit
import CoreAudio
import Darwin

/// Observable model for a single audio-producing process.
final class AudioProcess: ObservableObject, Identifiable {

    /// The CoreAudio AudioObjectID for this process object.
    let id: AudioObjectID

    /// Unix PID.
    let pid: pid_t

    /// Display name resolved from the owning app (walking up the process
    /// tree for helpers), falling back to the executable name.
    let appName: String

    /// App icon resolved from NSRunningApplication (generic icon for daemons).
    let appIcon: NSImage?

    /// Stable key for persisting volume/mute across launches
    /// (bundle ID when available, executable name otherwise).
    let persistenceKey: String

    /// Volume in [0.0, 1.0].
    @MainActor @Published var volume: Float

    /// Whether the process is muted.
    @MainActor @Published var isMuted: Bool

    @MainActor
    init(id: AudioObjectID, pid: pid_t, volume: Float, isMuted: Bool) {
        self.id = id
        self.pid = pid
        self.volume = min(max(volume, 0), 1)
        self.isMuted = isMuted

        let executableName = Self.executableName(for: pid)
        if let app = Self.resolveOwningApplication(for: pid) {
            let name = app.localizedName
                ?? app.bundleIdentifier
                ?? executableName
                ?? "PID \(pid)"
            self.appName = name
            self.appIcon = app.icon
            self.persistenceKey = app.bundleIdentifier ?? executableName ?? name
        } else {
            let name = executableName ?? "PID \(pid)"
            self.appName = name
            self.appIcon = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: nil
            )
            self.persistenceKey = name
        }
    }

    // MARK: - Name resolution

    /// Audio is often produced by helper processes (e.g. browser renderer /
    /// audio service processes) that aren't registered applications. Walk up
    /// the parent-process chain until we hit a real NSRunningApplication.
    private static func resolveOwningApplication(for pid: pid_t) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<10 {
            if let app = NSRunningApplication(processIdentifier: current) {
                return app
            }
            guard let parent = parentPID(of: current),
                  parent > 1, parent != current else { break }
            current = parent
        }
        return nil
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0) == 0,
              size > 0 else { return nil }
        return info.kp_eproc.e_ppid
    }

    private static func executableName(for pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        guard proc_name(pid, &buffer, UInt32(buffer.count)) > 0 else { return nil }
        let name = String(cString: buffer)
        return name.isEmpty ? nil : name
    }
}
