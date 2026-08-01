import Foundation
import CoreAudio
import AudioToolbox

/// Gives one process a truly independent volume by routing its audio through
/// a CoreAudio process tap (macOS 14.4+): the process's direct output is muted
/// (`.mutedWhenTapped`) and we re-render its captured audio into the default
/// output device through a private aggregate device, scaled by `gain`.
final class ProcessTapController {

    private var tapID = AudioObjectID(kAudioObjectUnknown)
    private var aggregateID = AudioObjectID(kAudioObjectUnknown)
    private var ioProcID: AudioDeviceIOProcID?

    private let gainLock = NSLock()
    private var _gain: Float = 1.0

    /// Software gain (0–1) applied on the realtime IO thread.
    var gain: Float {
        get { gainLock.lock(); defer { gainLock.unlock() }; return _gain }
        set {
            gainLock.lock()
            _gain = min(max(newValue, 0), 1)
            gainLock.unlock()
        }
    }

    init?(processObjectID: AudioObjectID, initialGain: Float) {
        _gain = min(max(initialGain, 0), 1)

        // 1. Create the tap: stereo mixdown of the process, muting its direct output.
        let tapDescription = CATapDescription(stereoMixdownOfProcesses: [processObjectID])
        tapDescription.uuid = UUID()
        tapDescription.muteBehavior = .mutedWhenTapped
        tapDescription.isPrivate = true

        var newTapID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateProcessTap(tapDescription, &newTapID) == noErr,
              newTapID != kAudioObjectUnknown else {
            NSLog("MusicMixer: failed to create process tap for object \(processObjectID)")
            return nil
        }
        tapID = newTapID

        // 2. Private aggregate device: default output device + the tap.
        guard let outputUID = Self.defaultOutputDeviceUID() else {
            AudioHardwareDestroyProcessTap(tapID)
            return nil
        }
        let description: [String: Any] = [
            kAudioAggregateDeviceNameKey: "MusicMixer Tap \(processObjectID)",
            kAudioAggregateDeviceUIDKey: UUID().uuidString,
            kAudioAggregateDeviceMainSubDeviceKey: outputUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceIsStackedKey: false,
            kAudioAggregateDeviceSubDeviceListKey: [
                [kAudioSubDeviceUIDKey: outputUID]
            ],
            kAudioAggregateDeviceTapListKey: [
                [kAudioSubTapUIDKey: tapDescription.uuid.uuidString]
            ],
            kAudioAggregateDeviceTapAutoStartKey: true,
        ]
        var newAggregateID = AudioObjectID(kAudioObjectUnknown)
        guard AudioHardwareCreateAggregateDevice(description as CFDictionary,
                                                 &newAggregateID) == noErr,
              newAggregateID != kAudioObjectUnknown else {
            NSLog("MusicMixer: failed to create aggregate device")
            AudioHardwareDestroyProcessTap(tapID)
            return nil
        }
        aggregateID = newAggregateID

        // 3. IO proc: copy tap input to device output, scaled by gain.
        let err = AudioDeviceCreateIOProcIDWithBlock(&ioProcID, aggregateID, nil) {
            [weak self] _, inInputData, _, outOutputData, _ in
            let inputList = UnsafeMutableAudioBufferListPointer(
                UnsafeMutablePointer(mutating: inInputData))
            let outputList = UnsafeMutableAudioBufferListPointer(outOutputData)
            let gain = self?.gain ?? 0

            for (index, outBuffer) in outputList.enumerated() {
                guard let outData = outBuffer.mData else { continue }
                let outSamples = outData.assumingMemoryBound(to: Float32.self)
                let outCount = Int(outBuffer.mDataByteSize) / MemoryLayout<Float32>.size

                guard index < inputList.count,
                      let inData = inputList[index].mData else {
                    memset(outData, 0, Int(outBuffer.mDataByteSize))
                    continue
                }
                let inSamples = inData.assumingMemoryBound(to: Float32.self)
                let inCount = Int(inputList[index].mDataByteSize) / MemoryLayout<Float32>.size

                let n = min(inCount, outCount)
                for i in 0..<n {
                    outSamples[i] = inSamples[i] * gain
                }
                if n < outCount {
                    memset(outSamples + n, 0,
                           (outCount - n) * MemoryLayout<Float32>.size)
                }
            }
        }
        guard err == noErr, let procID = ioProcID else {
            teardown()
            return nil
        }
        guard AudioDeviceStart(aggregateID, procID) == noErr else {
            teardown()
            return nil
        }
    }

    deinit {
        teardown()
    }

    private func teardown() {
        if let procID = ioProcID, aggregateID != kAudioObjectUnknown {
            AudioDeviceStop(aggregateID, procID)
            AudioDeviceDestroyIOProcID(aggregateID, procID)
            ioProcID = nil
        }
        if aggregateID != kAudioObjectUnknown {
            AudioHardwareDestroyAggregateDevice(aggregateID)
            aggregateID = AudioObjectID(kAudioObjectUnknown)
        }
        if tapID != kAudioObjectUnknown {
            AudioHardwareDestroyProcessTap(tapID)
            tapID = AudioObjectID(kAudioObjectUnknown)
        }
    }

    private static func defaultOutputDeviceUID() -> String? {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID
        ) == noErr, deviceID != kAudioObjectUnknown else { return nil }

        var uidAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var uid: CFString = "" as CFString
        var uidSize = UInt32(MemoryLayout<CFString>.size)
        guard withUnsafeMutablePointer(to: &uid, { ptr in
            AudioObjectGetPropertyData(deviceID, &uidAddr, 0, nil, &uidSize, ptr)
        }) == noErr else { return nil }
        return uid as String
    }
}
