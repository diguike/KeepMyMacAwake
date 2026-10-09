import SwiftUI
import AppKit
import ServiceManagement
import AwakeCore
import AwakeShared

@MainActor final class AppModel: ObservableObject {
    @Published var durationMinutes = 60
    @Published var customMinutes = 90
    @Published var lidMode = false
    @Published var requireNetwork = false
    @Published var keepDisplay = false
    @Published var nightMode = false
    @Published var dimAmount = 0.94
    @Published var scene = "日常"
    @Published var unlimitedSession = false
    @Published var requireAC = true
    @Published var minimumBattery = 20
    @Published var active = false
    @Published var busy = false
    @Published var message = "未开启"
    @Published var remaining: Double = 0
    @Published var sample = MacMonitor.sample()
    @Published var helperState = "未检查"
    @Published var loginEnabled = false
    @Published var onboarded: Bool
    private let client = HelperClient()
    private let assertion = IdleAssertion()
    private let dimmer = NightDimmer()
    private let daemon = SMAppService.daemon(plistName: ServiceIdentity.plist)
    private var timer: Timer?
    private var lastHelperPoll: Double?
    private var leaseID: UUID?
    private var idleStart: ClockSample?
    private var idleDuration: Double = 0
    private var safety = SafetyEvaluator()
    private var idlePolicy = SafetyPolicy()
    var policy: SafetyPolicy { SafetyPolicy(requireAC: requireAC, minimumBattery: minimumBattery, requireNetwork: requireNetwork) }
    var hasSession: Bool { active || idleStart != nil || leaseID != nil }
    var helperBuildEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "AwakeHelperEnabled") as? Bool == true }
    init() {
        onboarded = UserDefaults.standard.bool(forKey: "onboarded")
        loginEnabled = SMAppService.mainApp.status == .enabled
        updateAuthorization()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let model = self else { return }
            Task { @MainActor in await model.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        Task { await refresh() }
    }
    func chooseScene(_ name: String) {
        guard !hasSession, !busy else { return }
        scene = name; lidMode = false; nightMode = false; keepDisplay = false
        requireAC = true; requireNetwork = false
        switch name {
        case "夜间": nightMode = true; durationMinutes = 480
        case "接电合盖": lidMode = true; durationMinutes = -1
        case "有网时": lidMode = true; requireAC = false; requireNetwork = true; durationMinutes = 120
        default: durationMinutes = 60
        }
        message = "未开启"
    }
    func acknowledge() { onboarded = true; UserDefaults.standard.set(true, forKey: "onboarded") }
    func updateAuthorization() {
        switch daemon.status {
        case .enabled: helperState = "已批准，等待连接检查"
        case .requiresApproval: helperState = "需要在系统设置批准后台组件"
        case .notRegistered: helperState = "尚未安装后台组件"
        case .notFound: helperState = "找不到后台组件，请重新安装"
        @unknown default: helperState = "授权状态未知"
        }
    }
    func authorize() {
        guard !busy else { return }
        guard helperBuildEnabled else { message = "当前是未签名预览。合盖授权需要使用签名证书重新构建。"; return }
        do {
            if daemon.status == .notRegistered { try daemon.register() }
            updateAuthorization()
            if daemon.status == .requiresApproval { SMAppService.openSystemSettingsLoginItems() }
            Task { await refresh() }
        } catch { message = "授权失败：\(error.localizedDescription)" }
    }
    func openApprovalSettings() { SMAppService.openSystemSettingsLoginItems() }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !loginEnabled { message = "开机启动需要在系统设置批准" }
        } catch { message = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    func start() async {
        guard !busy, !active, idleStart == nil, leaseID == nil, onboarded else { return }
        busy = true; defer { busy = false }
        let minutes = durationMinutes == 0 ? customMinutes : durationMinutes
        guard (durationMinutes == -1 || (1...1440).contains(minutes)), policy.isValid else { message = "时间需在 1–1440 分钟范围内"; return }
        let duration = durationMinutes == -1 ? 0 : Double(minutes * 60)
        let now = MacMonitor.clock()
        sample = MacMonitor.sample()
        safety = SafetyEvaluator()
        if let reason = safety.evaluate(sample, policy: policy, now: now.continuous) { message = reason.message; return }
        message = "正在启用…"
        do {
            if lidMode {
                guard daemon.status == .enabled else {
                    message = "合盖模式需要先安装并批准后台组件"; updateAuthorization(); return
                }
                let reply = try await client.send(HelperRequest(.acquire, duration: duration, policy: policy))
                guard reply.error == nil, reply.status.phase == .active, let id = reply.status.leaseID else {
                    message = reply.error ?? reply.status.error ?? "后台未确认启用"; return
                }
                leaseID = id; remaining = reply.status.remainingSeconds ?? 0
                if keepDisplay || nightMode { try assertion.start(keepDisplay: true) }
                helperState = "后台组件已连接"
                message = "合盖保活设置已就绪 · 本机效果待实测"
            } else {
                try assertion.start(keepDisplay: keepDisplay || nightMode)
                idleStart = now; idleDuration = duration; idlePolicy = policy; remaining = idleDuration
                message = "防闲置休眠运行中 · 合盖仍可能休眠"
            }
            unlimitedSession = duration == 0
            if nightMode { dimmer.start(amount: dimAmount) }
            active = true
        } catch {
            dimmer.stop(); try? assertion.stop()
            message = "启用失败：\(error.localizedDescription)"; client.disconnect()
        }
    }
    @discardableResult func stop() async -> Bool {
        guard !busy else { return false }
        busy = true; defer { busy = false }
        dimmer.stop()
        do {
            try assertion.stop()
            if let id = leaseID {
                let reply = try await client.send(HelperRequest(.release, leaseID: id))
                // A watchdog may have already restored it before release arrived.
                guard reply.status.phase == .off else { throw AwakeError.backend(reply.error ?? reply.status.error ?? "尚未恢复") }
                leaseID = nil
            }
            if leaseID == nil, idleStart == nil, daemon.status == .enabled {
                let reply = try await client.send(HelperRequest(.status))
                guard reply.status.phase == .off else {
                    throw AwakeError.backend(reply.status.error ?? "后台仍有会话或待恢复设置，请先恢复")
                }
            }
            try assertion.stop(); dimmer.stop(); idleStart = nil; active = false; remaining = 0; unlimitedSession = false
            message = "已停止本应用保活，设置已恢复"; return true
        } catch {
            active = false; message = "恢复未确认：\(error.localizedDescription)"; client.disconnect(); return false
        }
    }
    func recover() async {
        guard !busy, !active, idleStart == nil else { return }
        busy = true; defer { busy = false }
        do {
            let reply = try await client.send(HelperRequest(.recover))
            guard reply.error == nil, reply.status.phase == .off else {
                throw AwakeError.backend(reply.error ?? reply.status.error ?? "恢复尚未完成")
            }
            leaseID = nil; message = "已确认恢复设置"
        } catch { message = "恢复失败：\(error.localizedDescription)"; client.disconnect() }
    }
    func removeHelper() async {
        guard await stop() else { return }
        busy = true; defer { busy = false }
        do {
            // Verify persistent recovery before removing the independent watchdog.
            let reply = try await client.send(HelperRequest(.recover))
            guard reply.error == nil, reply.status.phase == .off else {
                throw AwakeError.backend(reply.error ?? reply.status.error ?? "设置未恢复，保留后台组件")
            }
            try await daemon.unregister()
            client.disconnect(); updateAuthorization(); message = "已恢复设置并移除后台组件"
        } catch { message = "移除失败：\(error.localizedDescription)" }
    }
    func quit() async {
        if await stop() { client.disconnect(); NSApp.terminate(nil) }
    }
    func refresh() async {
        guard !busy else { return }
        busy = true; defer { busy = false }
        sample = MacMonitor.sample()
        let now = MacMonitor.clock()
        if let start = idleStart {
            remaining = max(0, idleDuration - (now.continuous - start.continuous))
            var reason = safety.evaluate(sample, policy: idlePolicy, now: now.continuous)
            if idleDuration > 0 && remaining <= 0 { reason = .expired }
            if abs(now.wall.timeIntervalSince(start.wall) - (now.continuous - start.continuous)) > 60 { reason = .clockChanged }
            if let reason = reason {
                do { try assertion.stop(); dimmer.stop(); idleStart = nil; active = false; unlimitedSession = false; remaining = 0; message = "已停止：\(reason.message)" }
                catch { active = false; message = "断言释放失败：\(error.localizedDescription)" }
            }
            return
        }
        guard daemon.status == .enabled else {
            updateAuthorization()
            if leaseID != nil { active = false; dimmer.stop(); try? assertion.stop(); message = "后台授权不可用，恢复状态未知" }
            return
        }
        if let lastHelperPoll, now.continuous - lastHelperPoll < 5 { return }
        lastHelperPoll = now.continuous
        do {
            let operation: HelperRequest = leaseID.map { HelperRequest(.renew, leaseID: $0) } ?? HelperRequest(.status)
            let reply = try await client.send(operation)
            helperState = "后台组件已连接"
            sample = reply.sample
            if reply.status.phase == .active {
                // A new connection cannot adopt a lease from an earlier process.
                if leaseID != nil, reply.error == nil {
                    active = true; remaining = reply.status.remainingSeconds ?? 0
                    message = "合盖保活设置已就绪 · 本机效果待实测"
                } else { active = false; message = "后台有其他会话，等待结束或恢复" }
            } else {
                active = false; leaseID = nil; remaining = 0; unlimitedSession = false; dimmer.stop(); try assertion.stop()
                if reply.status.phase == .recoveryRequired { message = "需要恢复：\(reply.status.error ?? "未知错误")" }
                else if let reason = reply.status.stopReason { message = "已停止：\(reason.message)" }
            }
        } catch {
            active = false; dimmer.stop(); try? assertion.stop(); helperState = "后台连接失败，状态未知"
            if leaseID != nil { message = "连接已失联，等待独立恢复；尚未确认恢复" }
            client.disconnect()
        }
    }
}
