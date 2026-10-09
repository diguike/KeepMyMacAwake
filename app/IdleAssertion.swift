import Foundation
import IOKit.pwr_mgt
import AwakeCore

final class IdleAssertion {
    private var id: IOPMAssertionID?
    func start() throws {
        guard id == nil else { return }
        var assertion: IOPMAssertionID = 0
        let result = IOPMAssertionCreateWithName(kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn), "KeepMyMacAwake timed session" as CFString, &assertion)
        guard result == kIOReturnSuccess else { throw AwakeError.backend("无法取得防闲置休眠断言（\(result)）") }
        id = assertion
    }
    func stop() throws {
        guard let assertion = id else { return }
        let result = IOPMAssertionRelease(assertion)
        guard result == kIOReturnSuccess else { throw AwakeError.backend("防休眠断言释放失败（\(result)）") }
        id = nil
    }
    deinit { if let id = id { IOPMAssertionRelease(id) } }
}
