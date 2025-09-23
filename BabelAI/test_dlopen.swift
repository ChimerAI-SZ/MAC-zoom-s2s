import Foundation
import Darwin

// Test dlopen for SpeexDSP
let candidates = [
    "/opt/homebrew/lib/libspeexdsp.dylib",
    "/opt/homebrew/lib/libspeexdsp.1.dylib",  
    "/usr/local/lib/libspeexdsp.dylib",
    "libspeexdsp.1.dylib",
    "libspeexdsp.dylib"
]

print("Testing dlopen for SpeexDSP library...")
print("=====================================")

for path in candidates {
    print("\nTrying: \(path)")
    if let handle = dlopen(path, RTLD_LAZY | RTLD_LOCAL) {
        print("  ✅ Success! Library loaded from: \(path)")
        
        // Try to get function symbols
        if let sym = dlsym(handle, "speex_echo_state_init") {
            print("     Found speex_echo_state_init at: \(sym)")
        }
        if let sym = dlsym(handle, "speex_echo_cancellation") {
            print("     Found speex_echo_cancellation at: \(sym)")
        }
        
        dlclose(handle)
        break
    } else if let error = dlerror() {
        let errorStr = String(cString: error)
        print("  ❌ Failed: \(errorStr)")
    }
}

print("\n=====================================")
print("Test complete.")