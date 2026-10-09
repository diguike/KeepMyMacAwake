import Foundation
import IOKit
import AwakeCore

public enum SleepState {
    /// Reads an explicit live boolean. Missing or mistyped properties are never treated as false.
    public static func readDisabled() throws -> Bool {
        let entry = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard entry != 0 else { throw AwakeError.backend("无法读取电源管理状态，未修改设置") }
        defer { IOObjectRelease(entry) }
        guard let flag = IORegistryEntryCreateCFProperty(entry, "SleepDisabled" as CFString,
                  kCFAllocatorDefault, 0)?.takeRetainedValue(), CFGetTypeID(flag) == CFBooleanGetTypeID() else {
            throw AwakeError.backend("无法可靠读取 SleepDisabled，未修改设置")
        }
        return CFBooleanGetValue((flag as! CFBoolean))
    }
}
