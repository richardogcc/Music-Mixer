import Foundation
import CoreAudio
import AppKit

/// Manages enumeration of CoreAudio per-process objects and exposes
/// an observable list of AudioProcess models. Each process gets its own
/// ProcessTapController, so volume and mute are fully independent per app.
@MainActor
final class AudioProcessManager: ObservableObject {

    @Published var processes: [AudioProcess] = []

    private var tapControllers: [AudioObjectID: ProcessTapController] = [:]
    private let volumeStore = VolumeStore()
    private var processListListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var refreshTimer: Timer?

    // MARK: - Lifecycle

    nonisolated init() {}

    func start() {
        registerProcessListListener()
        registerDefaultDeviceListener()
        refresh()
        // Fallback poll: kAudioProcessPropertyIsRunningOutput transitions don't
        // always fire the process-list listener.
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
        if let block = processListListenerBlock {
            var addr = Self.processListAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
            processListListenerBlock = nil
        }
        if let block = defaultDeviceListenerBlock {
            var addr = Self.defaultOutputDeviceAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
            defaultDeviceListenerBlock = nil
        }
        tapControllers.removeAll()
    }

    // MARK: - Public setters

    /// Set volume (0–1) for a single process via its tap gain.
    /// Fully independent — no other app is affected.
    func setVolume(_ volume: Float, for process: AudioProcess) {
        let v = min(max(volume, 0), 1)
        process.volume = v
        if !process.isMuted {
            tapControllers[process.id]?.gain = v
        }
        volumeStore.save(volume: v, isMuted: process.isMuted,
                         for: process.persistenceKey)
    }

    /// Mute / unmute a single process by zeroing its tap gain.
    func setMuted(_ muted: Bool, for process: AudioProcess) {
        process.isMuted = muted
        tapControllers[process.id]?.gain = muted ? 0 : process.volume
        volumeStore.save(volume: process.volume, isMuted: muted,
                         for: process.persistenceKey)
    }

    // MARK: - Property Addresses

    static var processListAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyProcessObjectList,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    static var defaultOutputDeviceAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // MARK: - Private: Listener registration

    private func registerProcessListListener() {
        var addr = Self.processListAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        processListListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
    }

    /// When the default output device changes (e.g. headphones plugged in),
    /// rebuild all taps so audio follows the new device.
    private func registerDefaultDeviceListener() {
        var addr = Self.defaultOutputDeviceAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.rebuildAllTaps() }
        }
        defaultDeviceListenerBlock = block
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
    }

    private func rebuildAllTaps() {
        for process in processes {
            tapControllers[process.id] = nil // teardown old tap first
            let gain = process.isMuted ? 0 : process.volume
            tapControllers[process.id] = ProcessTapController(
                processObjectID: process.id, initialGain: gain)
        }
    }

    // MARK: - Private: Refresh

    private func refresh() {
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let liveIDs = Set(fetchProcessObjectIDs())

        // Remove processes that disappeared or stopped producing output.
        var removedIDs: Set<AudioObjectID> = []
        for process in processes {
            if !liveIDs.contains(process.id) || !isRunningOutput(for: process.id) {
                removedIDs.insert(process.id)
            }
        }
        for id in removedIDs {
            tapControllers.removeValue(forKey: id)
        }
        processes.removeAll { removedIDs.contains($0.id) }

        // Add new audio-producing processes.
        let currentIDs = Set(processes.map(\.id))
        for objectID in liveIDs.subtracting(currentIDs) {
            guard let pid = readPID(for: objectID), pid != ownPID else { continue }
            guard isRunningOutput(for: objectID) else { continue }
            let process = AudioProcess(id: objectID, pid: pid,
                                       volume: 1.0, isMuted: false)
            if let saved = volumeStore.state(for: process.persistenceKey) {
                process.volume = saved.volume
                process.isMuted = saved.isMuted
            }
            let initialGain = process.isMuted ? 0 : process.volume
            guard let controller = ProcessTapController(
                processObjectID: objectID, initialGain: initialGain) else {
                NSLog("MusicMixer: could not tap process pid \(pid); skipping")
                continue
            }
            tapControllers[objectID] = controller
            processes.append(process)
        }

        processes.sort { $0.appName < $1.appName }
    }

    // MARK: - Private: CoreAudio reads

    private func fetchProcessObjectIDs() -> [AudioObjectID] {
        var addr = Self.processListAddress
        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize
        ) == noErr, dataSize > 0 else { return [] }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.size
        var ids = [AudioObjectID](repeating: 0, count: count)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &ids
        ) == noErr else { return [] }
        return ids
    }

    private func readPID(for objectID: AudioObjectID) -> pid_t? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyPID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var pid: pid_t = 0
        var size = UInt32(MemoryLayout<pid_t>.size)
        guard AudioObjectGetPropertyData(
            objectID, &addr, 0, nil, &size, &pid
        ) == noErr else { return nil }
        return pid
    }

    private func isRunningOutput(for objectID: AudioObjectID) -> Bool {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioProcessPropertyIsRunningOutput,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(objectID, &addr, 0, nil, &size, &running)
        return running != 0
    }
}
