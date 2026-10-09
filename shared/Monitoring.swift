import Foundation
import IOKit.ps
import Darwin
import Network
import AwakeCore

public enum MacMonitor {
    public static func clock() -> ClockSample {
        var timebase = mach_timebase_info_data_t()
        mach_timebase_info(&timebase)
        let seconds = Double(mach_continuous_time()) * Double(timebase.numer) / Double(timebase.denom) / 1e9
        return ClockSample(wall: Date(), continuous: seconds)
    }
    public static func sample() -> PowerSample {
        var onAC: Bool?
        var percent: Int?
        if let blob = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            if let type = IOPSGetProvidingPowerSourceType(blob)?.takeUnretainedValue() as String? {
                if type == kIOPSACPowerValue { onAC = true }
                else if type == kIOPSBatteryPowerValue { onAC = false }
            }
            if let sources = IOPSCopyPowerSourcesList(blob)?.takeRetainedValue() as? [CFTypeRef] {
                for source in sources {
                    guard let info = IOPSGetPowerSourceDescription(blob, source)?.takeUnretainedValue() as? [String: Any],
                          info[kIOPSTypeKey] as? String == kIOPSInternalBatteryType,
                          let current = info[kIOPSCurrentCapacityKey] as? Int,
                          let maximum = info[kIOPSMaxCapacityKey] as? Int, maximum > 0 else { continue }
                    let value = Int(Double(current) / Double(maximum) * 100)
                    if (0...100).contains(value) { percent = value }
                }
            }
        }
        let thermal: ThermalLevel
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = .nominal
        case .fair: thermal = .fair
        case .serious: thermal = .serious
        case .critical: thermal = .critical
        @unknown default: thermal = .unknown
        }
        return PowerSample(onAC: onAC, batteryPercent: percent, thermal: thermal, networkAvailable: NetworkAvailability.shared.available)
    }
}

/// Both App and helper observe paths independently; the helper never trusts UI telemetry.
private final class NetworkAvailability: @unchecked Sendable {
    static let shared = NetworkAvailability()
    private let monitor = NWPathMonitor()
    private let lock = NSLock()
    private var value: Bool?
    var available: Bool? { lock.lock(); defer { lock.unlock() }; return value }
    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            self.lock.lock(); self.value = path.status == .satisfied; self.lock.unlock()
        }
        monitor.start(queue: DispatchQueue(label: "io.github.diguike.keepmymacawake.path"))
    }
}
