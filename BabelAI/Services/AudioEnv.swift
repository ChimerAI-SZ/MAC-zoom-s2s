import Foundation
#if canImport(CoreAudio)
import CoreAudio
#endif

enum AudioEnv {
    static func hasBlackHole() -> Bool {
        #if canImport(CoreAudio)
        let names = allOutputDeviceNames()
        return names.contains { $0.localizedCaseInsensitiveContains("BlackHole") }
        #else
        return false
        #endif
    }

    static func defaultOutputDeviceName() -> String? {
        #if canImport(CoreAudio)
        var addr = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let err = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &addr, 0, nil, &size, &deviceID)
        if err != noErr { return nil }

        // Try getting device name with simpler approach
        var nameAddr = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceNameCFString,  // Use CFString-specific selector
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        
        var cfName: CFString = "" as CFString
        var nameSize = UInt32(MemoryLayout<CFString>.size)
        
        let status = withUnsafeMutablePointer(to: &cfName) { ptr in
            AudioObjectGetPropertyData(
                deviceID,
                &nameAddr,
                0,
                nil,
                &nameSize,
                ptr
            )
        }
        
        guard status == noErr else { return nil }
        return cfName as String
        #else
        return nil
        #endif
    }

    #if canImport(CoreAudio)
    private static func allOutputDeviceNames() -> [String] {
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
            var size = UInt32(MemoryLayout<UInt32>.size)
            var streamsAddr = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )
            // A simple check via data size; some devices may report 0 for no outputs.
            if AudioObjectGetPropertyDataSize(id, &streamsAddr, 0, nil, &size) == noErr, size > 0 {
                var nameAddr = AudioObjectPropertyAddress(
                    mSelector: kAudioDevicePropertyDeviceNameCFString,  // Use CFString-specific selector
                    mScope: kAudioObjectPropertyScopeGlobal,
                    mElement: kAudioObjectPropertyElementMain
                )
                
                var cfName: CFString = "" as CFString
                var nameSize = UInt32(MemoryLayout<CFString>.size)
                
                let status = withUnsafeMutablePointer(to: &cfName) { ptr in
                    AudioObjectGetPropertyData(
                        id,
                        &nameAddr,
                        0,
                        nil,
                        &nameSize,
                        ptr
                    )
                }
                
                if status == noErr {
                    let name = cfName as String
                    names.append(name)
                }
            }
        }
        return names
    }
    #endif
}

