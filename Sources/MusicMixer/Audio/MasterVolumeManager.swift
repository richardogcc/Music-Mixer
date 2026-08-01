import Foundation
import CoreAudio
import AudioToolbox

/// Reads and writes the system's virtual main output volume.
@MainActor
final class MasterVolumeManager: ObservableObject {

    @Published var volume: Float = 1.0
    @Published var isMuted: Bool = false

    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private var volumeListenerBlock: AudioObjectPropertyListenerBlock?

    func start() {
        volume  = readVolume()
        isMuted = readMuted()
        registerListeners()
    }

    func stop() {
        removeListeners()
    }

    // MARK: - Public setters

    func setVolume(_ v: Float) {
        guard let deviceID = defaultOutputDevice() else { return }
        var addr = Self.masterVolumeAddress
        var val = Float32(min(max(v, 0), 1))
        AudioObjectSetPropertyData(deviceID, &addr, 0, nil,
                                   UInt32(MemoryLayout<Float32>.size), &val)
        volume = val
    }

    func setMuted(_ m: Bool) {
        guard let deviceID = defaultOutputDevice() else { return }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var val = UInt32(m ? 1 : 0)
        AudioObjectSetPropertyData(deviceID, &addr, 0, nil,
                                   UInt32(MemoryLayout<UInt32>.size), &val)
        isMuted = m
    }

    // MARK: - Property Addresses

    // kAudioHardwareServiceDeviceProperty_VirtualMainVolume is the Swift-visible name
    private static var masterVolumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static var defaultOutputAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultOutputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )

    // MARK: - Listeners

    private func registerListeners() {
        var sysAddr = Self.defaultOutputAddress
        let devBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.volume  = self?.readVolume()  ?? 1.0
                self?.isMuted = self?.readMuted()   ?? false
                self?.reRegisterVolumeListener()
            }
        }
        defaultDeviceListenerBlock = devBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &sysAddr, .main, devBlock)

        reRegisterVolumeListener()
    }

    private func reRegisterVolumeListener() {
        guard let deviceID = defaultOutputDevice() else { return }

        if let old = volumeListenerBlock {
            var addr = Self.masterVolumeAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &addr, .main, old)
        }

        var addr = Self.masterVolumeAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.volume  = self?.readVolume()  ?? 1.0
                self?.isMuted = self?.readMuted()   ?? false
            }
        }
        volumeListenerBlock = block
        AudioObjectAddPropertyListenerBlock(deviceID, &addr, .main, block)
    }

    private func removeListeners() {
        if let block = defaultDeviceListenerBlock {
            var addr = Self.defaultOutputAddress
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &addr, .main, block)
        }
        if let block = volumeListenerBlock, let deviceID = defaultOutputDevice() {
            var addr = Self.masterVolumeAddress
            AudioObjectRemovePropertyListenerBlock(deviceID, &addr, .main, block)
        }
    }

    // MARK: - Reads

    private func readVolume() -> Float {
        guard let deviceID = defaultOutputDevice() else { return 1.0 }
        var addr = Self.masterVolumeAddress
        var vol: Float32 = 1.0
        var size = UInt32(MemoryLayout<Float32>.size)
        AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &vol)
        return min(max(vol, 0), 1)
    }

    private func readMuted() -> Bool {
        guard let deviceID = defaultOutputDevice() else { return false }
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &muted)
        return muted != 0
    }

    private func defaultOutputDevice() -> AudioDeviceID? {
        var addr = Self.defaultOutputAddress
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }
}
