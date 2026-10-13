import Foundation
import IOKit.pwr_mgt
import AwakeCore

final class IdleAssertion {
    private var id: IOPMAssertionID?
    private var displayID: IOPMAssertionID?
    func start(keepDisplay: Bool = false) throws {
        guard id == nil else { return }
        var assertion: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "KeepMyMacAwake timed session" as CFString, &assertion)
        guard result == kIOReturnSuccess else { throw AwakeError.backend("无法取得防闲置休眠断言（\(result)）") }
        id = assertion
        if keepDisplay {
            var display: IOPMAssertionID = 0
            let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
                IOPMAssertionLevel(kIOPMAssertionLevelOn), "KeepMyMacAwake display session" as CFString, &display)
            guard result == kIOReturnSuccess else {
                try stop(); throw AwakeError.backend("无法保持屏幕常亮（\(result)）")
            }
            displayID = display
        }
    }
    func stop() throws {
        if let display = displayID {
            let result = IOPMAssertionRelease(display)
            guard result == kIOReturnSuccess else { throw AwakeError.backend("屏幕断言释放失败（\(result)）") }
            displayID = nil
        }
        guard let assertion = id else { return }
        let result = IOPMAssertionRelease(assertion)
        guard result == kIOReturnSuccess else { throw AwakeError.backend("防休眠断言释放失败（\(result)）") }
        id = nil
    }
    deinit { if let id { IOPMAssertionRelease(id) }; if let displayID { IOPMAssertionRelease(displayID) } }
}
