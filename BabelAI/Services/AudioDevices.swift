import Foundation
import CoreAudio

enum AudioDevices {
    static func hasBlackHole() -> Bool {
        let deviceNames = allDeviceNames()
        return deviceNames.contains { $0.localizedCaseInsensitiveContains("BlackHole") }
    }

    static func allDeviceNames() -> [String] {
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize)
        if status != noErr || dataSize == 0 { return [] }
        let count = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = Array(repeating: AudioDeviceID(0), count: count)
        status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &dataSize, &deviceIDs)
        if status != noErr { return [] }
        var names: [String] = []
        for id in deviceIDs {
            var name: CFString = "" as CFString
            var prop = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameSize = UInt32(MemoryLayout<CFString>.size)
            let err = AudioObjectGetPropertyData(id, &prop, 0, nil, &nameSize, &name)
            if err == noErr { names.append(name as String) }
        }
        return names
    }
}

