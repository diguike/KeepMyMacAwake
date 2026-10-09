import Foundation
import AwakeCore

final class PMSetBackend: SleepBackend {
    func readDisabled() throws -> Bool {
        // Custom power profiles do not contain the global SleepDisabled flag.
        let output = try run(["-g"])
        let values = output.split(separator: "\n").compactMap { line -> String? in
            let fields = line.split(whereSeparator: { $0.isWhitespace })
            guard fields.count == 2, fields[0].lowercased() == "sleepdisabled" else { return nil }
            return String(fields[1])
        }
        guard values.count == 1, let value = values.first, value == "0" || value == "1" else {
            throw AwakeError.backend("无法可靠读取 SleepDisabled，未修改设置")
        }
        return value == "1"
    }
    func setDisabled(_ value: Bool) throws { _ = try run(["-a", "disablesleep", value ? "1" : "0"]) }
    private func run(_ arguments: [String]) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        process.arguments = arguments
        process.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin", "LC_ALL": "C"]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        // Bound every invocation so a stuck command cannot block the watchdog forever.
        let deadline = Date().addingTimeInterval(3)
        while process.isRunning && Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        if process.isRunning {
            process.terminate()
            Thread.sleep(forTimeInterval: 0.1)
            if process.isRunning { kill(process.processIdentifier, SIGKILL) }
            process.waitUntilExit()
            throw AwakeError.backend("pmset 超时，恢复机制会继续重试")
        }
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0, let text = String(data: data, encoding: .utf8) else {
            throw AwakeError.backend("pmset 返回失败（\(process.terminationStatus)）")
        }
        return text
    }
}
