import SwiftUI
import AppKit
import ServiceManagement
import AwakeCore
import AwakeShared

@MainActor final class AppModel: ObservableObject {
    static let shared = AppModel()
    @Published var durationMinutes = 60 { didSet { savePreferences() } }
    @Published var customMinutes = 90 { didSet { savePreferences() } }
    @Published var lidMode = false { didSet { savePreferences() } }
    @Published var requireNetwork = false { didSet { savePreferences() } }
    @Published var screenMode = "自动熄屏" { didSet { savePreferences() } }
    @Published var showCountdown = true { didSet { savePreferences() } }
    @Published private(set) var notifyOnEnd = false
    @Published var notificationMessage = "只提醒保持唤醒已结束，不代表 AI 任务已完成。"
    var keepDisplay: Bool { get { screenMode == "保持常亮" } set { screenMode = newValue ? "保持常亮" : "自动熄屏" } }
    var nightMode: Bool { get { screenMode == "夜间柔光" } set { screenMode = newValue ? "夜间柔光" : "自动熄屏" } }
    @Published var dimAmount = 0.94 { didSet { savePreferences() } }
    @Published var scene = "日常" { didSet { savePreferences() } }
    @Published var unlimitedSession = false
    @Published var requireAC = true { didSet { savePreferences() } }
    @Published var minimumBattery = 20 { didSet { savePreferences() } }
    @Published var active = false
    @Published var busy = false
    @Published var message = ""
    @Published var remaining: Double = 0
    @Published var sample = MacMonitor.sample()
    @Published var helperState = "未检查"
    @Published var helperConnected = false
    @Published var needsRecovery = false
    @Published var startedAt: Date?
    @Published var sessionSeconds: Double = 0
    @Published var loginEnabled = false
    /// Survives scene changes so a returning user can see how the last session ended.
    @Published var lastResult: String?
    @Published private(set) var lastSession: SessionResult?
    @Published var onboarded: Bool
    private let readSample: () -> PowerSample
    private let readClock: () -> ClockSample
    private let readHelperStatus: (() -> SMAppService.Status)?
    private let requestHelper: ((HelperRequest) async throws -> HelperReply)?
    private let defaults: UserDefaults?
    private let notifyEnd: (SessionResult) -> Void
    private let enableNotifications: () async throws -> Bool
    private var preferencesReady = false
    private let client = HelperClient()
    private let assertion = IdleAssertion()
    private let dimmer = NightDimmer()
    private let daemon = SMAppService.daemon(plistName: ServiceIdentity.plist)
    private var timer: Timer?
    private var isRefreshing = false
    private var actionGeneration: UInt64 = 0
    private var notificationGeneration: UInt64 = 0
    private var lastHelperPoll: Double?
    private var leaseID: UUID?
    private var idleStart: ClockSample?
    private var idleDuration: Double = 0
    private var safety = SafetyEvaluator()
    private var idlePolicy = SafetyPolicy()
    var policy: SafetyPolicy { SafetyPolicy(requireAC: requireAC, minimumBattery: minimumBattery, requireNetwork: requireNetwork) }
    var hasSession: Bool { active || idleStart != nil || leaseID != nil }
    var helperBuildEnabled: Bool { Bundle.main.object(forInfoDictionaryKey: "AwakeHelperEnabled") as? Bool == true }
    private var serviceStatus: SMAppService.Status {
        if let readHelperStatus { return readHelperStatus() }
        return helperBuildEnabled ? daemon.status : .notRegistered
    }
    var helperNeedsApproval: Bool { serviceStatus == .requiresApproval }
    var helperNeedsInstall: Bool { serviceStatus == .notRegistered || serviceStatus == .notFound }
    init(defaults: UserDefaults? = .standard, sample: @escaping () -> PowerSample = MacMonitor.sample,
         clock: @escaping () -> ClockSample = MacMonitor.clock,
         helperStatus: (() -> SMAppService.Status)? = nil,
         helperRequest: ((HelperRequest) async throws -> HelperReply)? = nil,
         notifyEnd: ((SessionResult) -> Void)? = nil,
         enableNotifications: (() async throws -> Bool)? = nil,
         startMonitoring: Bool = true) {
        self.defaults = defaults; self.readSample = sample; self.readClock = clock
        self.readHelperStatus = helperStatus; self.requestHelper = helperRequest
        self.notifyEnd = notifyEnd ?? { SessionNotifications().send($0) }
        self.enableNotifications = enableNotifications ?? { try await SessionNotifications().enable() }
        onboarded = defaults?.bool(forKey: "onboarded") ?? false
        notifyOnEnd = defaults?.bool(forKey: "notifyOnEnd.v1") ?? false
        if let data = defaults?.data(forKey: "lastResult.v1"),
           let result = try? JSONDecoder().decode(SessionResult.self, from: data), result.isValid {
            lastResult = result.text; lastSession = result
        }
        if let data = defaults?.data(forKey: "preferences.v1"),
           let preferences = try? JSONDecoder().decode(AwakePreferences.self, from: data), preferences.isValid {
            scene = preferences.scene; durationMinutes = preferences.durationMinutes; customMinutes = preferences.customMinutes
            lidMode = preferences.lidMode; requireAC = preferences.requireAC; requireNetwork = preferences.requireNetwork
            screenMode = preferences.screenMode; minimumBattery = preferences.minimumBattery
            dimAmount = preferences.dimAmount; showCountdown = preferences.showCountdown
        }
        preferencesReady = true
        loginEnabled = SMAppService.mainApp.status == .enabled
        updateAuthorization()
        guard startMonitoring else { return }
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            guard let model = self else { return }
            Task { @MainActor in await model.refresh() }
        }
        if let timer { RunLoop.main.add(timer, forMode: .common) }
        Task { await refresh() }
    }
    private func publish<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<AppModel, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
    private func send(_ request: HelperRequest) async throws -> HelperReply {
        if let requestHelper { return try await requestHelper(request) }
        return try await client.send(request)
    }
    var preferences: AwakePreferences {
        var value = AwakePreferences()
        value.scene = scene; value.durationMinutes = durationMinutes; value.customMinutes = customMinutes
        value.lidMode = lidMode; value.requireAC = requireAC; value.requireNetwork = requireNetwork
        value.screenMode = screenMode; value.minimumBattery = minimumBattery
        value.dimAmount = dimAmount; value.showCountdown = showCountdown
        return value
    }
    private func savePreferences() {
        guard preferencesReady, let defaults else { return }
        let value = preferences
        if value.isValid, let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "preferences.v1") }
    }
    enum Phase { case off, on, confirming, recovery }
    var phase: Phase { needsRecovery ? .recovery : active ? .on : hasSession ? .confirming : .off }
    var phaseText: String {
        switch phase {
        case .off: return "未开启"
        case .on: return "保持唤醒中"
        case .confirming: return "正在确认"
        case .recovery: return "需要恢复"
        }
    }
    var statusTitle: String {
        if needsRecovery { return "需要恢复睡眠设置" }
        if hasSession && !active { return "正在确认恢复" }
        if !active { return readinessTitle }
        if unlimitedSession { return "直到手动停止" }
        return SessionText.timer(ceil(remaining))
    }
    /// Read from the injected clock so tests and screenshots stay deterministic.
    var elapsedSeconds: Double? {
        guard active, let startedAt else { return nil }
        return max(0, readClock().wall.timeIntervalSince(startedAt))
    }
    var startTimeText: String? { startedAt.map { SessionText.clock($0) } }
    var powerText: String {
        switch (sample.onAC, sample.batteryPercent) {
        case (true?, let percent?): return "已接电 · \(percent)%"
        case (true?, nil): return "已接电"
        case (false?, let percent?): return "使用电池 · \(percent)%"
        case (false?, nil): return "使用电池 · 电量未知"
        case (nil, _): return "未知"
        }
    }
    var networkText: String { sample.networkAvailable.map { $0 ? "已连接" : "未连接" } ?? "未知" }
    /// Idle title says what would block a start instead of a generic ready state.
    var readinessTitle: String {
        if lidMode && !helperBuildEnabled { return "未签名构建无法合盖" }
        if lidMode && serviceStatus != .enabled { return "合盖需先授权后台组件" }
        if requireAC && sample.onAC == false { return "请接通电源" }
        var evaluator = SafetyEvaluator()
        if let reason = evaluator.evaluate(sample, policy: policy, now: readClock().continuous) { return reason.message }
        return "可以开始"
    }
    /// One line under the title: the promise of the running session, or what a start will request.
    var statusDetail: String {
        if active {
            if unlimitedSession { return "\(sceneDisplayName) · 直到手动停止" }
            guard let startedAt else { return "\(sceneDisplayName) · 保持唤醒中" }
            return "\(sceneDisplayName) · " + SessionText.endTime(startedAt.addingTimeInterval(sessionSeconds), now: readClock().wall)
        }
        let value = preferences
        return "\(sceneDisplayName)\(value.isCustomized ? "（已调整）" : "") · \(value.summary)"
    }
    var sceneDisplayName: String { ScenePreset.named(scene)?.displayName ?? scene }
    private func recordEnd(_ reason: String) {
        if let startedAt {
            let result = SessionResult(start: startedAt, end: readClock().wall, reason: reason)
            lastResult = result.text; lastSession = result
            if let data = try? JSONEncoder().encode(result) { defaults?.set(data, forKey: "lastResult.v1") }
            if notifyOnEnd { notifyEnd(result) }
        }
        startedAt = nil
    }
    func setNotifications(_ enabled: Bool) async {
        notificationGeneration &+= 1
        let generation = notificationGeneration
        if !enabled {
            notifyOnEnd = false; defaults?.set(false, forKey: "notifyOnEnd.v1"); return
        }
        do {
            let granted = try await enableNotifications()
            guard generation == notificationGeneration else { return }
            notifyOnEnd = granted
            defaults?.set(notifyOnEnd, forKey: "notifyOnEnd.v1")
            notificationMessage = notifyOnEnd ? "结束时发送系统通知；是否响铃取决于你的通知设置。" : "通知未获允许，可在系统设置 → 通知中开启。"
        } catch { if generation == notificationGeneration { notificationMessage = "通知授权失败：\(error.localizedDescription)" } }
    }
    var sessionProgress: Double { active && !unlimitedSession && sessionSeconds > 0 ? max(0, min(1, remaining / sessionSeconds)) : 1 }
    var thermalDescription: String {
        switch sample.thermal {
        case .nominal: return "正常"
        case .fair: return "略高"
        case .serious: return "较高"
        case .critical: return "严重"
        case .unknown: return "未知"
        }
    }
    func chooseScene(_ name: String) {
        guard !hasSession, !busy, let preset = ScenePreset.named(name) else { return }
        scene = preset.name; durationMinutes = preset.durationMinutes; screenMode = preset.screenMode
        lidMode = preset.lidMode; requireAC = preset.requireAC; requireNetwork = preset.requireNetwork
        message = ""
    }
    func acknowledge() { onboarded = true; defaults?.set(true, forKey: "onboarded") }
    func updateAuthorization() {
        publish(\.helperConnected, false)
        if !helperBuildEnabled && readHelperStatus == nil {
            publish(\.helperState, "未签名构建不可用")
            return
        }
        switch serviceStatus {
        case .enabled: publish(\.helperState, "已授权，正在检查连接")
        case .requiresApproval: publish(\.helperState, "等待在系统设置中授权")
        case .notRegistered, .notFound: publish(\.helperState, "未安装")
        @unknown default: publish(\.helperState, "授权状态未知")
        }
    }
    func authorize() {
        guard !busy else { return }
        guard helperBuildEnabled else { message = "当前是未签名构建。合盖功能需要使用签名证书构建的版本。"; return }
        actionGeneration &+= 1
        do {
            if daemon.status == .notRegistered || daemon.status == .notFound { try daemon.register() }
        } catch {
            // macOS may register the daemon while returning EPERM until the user approves it.
            guard daemon.status == .requiresApproval else {
                updateAuthorization(); message = "授权失败：\(error.localizedDescription)"; return
            }
        }
        updateAuthorization()
        if helperNeedsApproval {
            message = "请在系统设置中允许 KeepMyMacAwake 在后台运行，并用触控 ID 或登录密码确认。"
            SMAppService.openSystemSettingsLoginItems()
        }
        Task { await refresh() }
    }
    func installHelper() async { authorize(); lastHelperPoll = nil; await refresh() }
    func openApprovalSettings() { SMAppService.openSystemSettingsLoginItems() }
    func setLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginEnabled = SMAppService.mainApp.status == .enabled
            if enabled && !loginEnabled { message = "登录时启动需要在系统设置中允许" }
        } catch { message = error.localizedDescription; loginEnabled = SMAppService.mainApp.status == .enabled }
    }
    func start() async {
        guard !busy, !active, idleStart == nil, leaseID == nil else { return }
        actionGeneration &+= 1
        busy = true; defer { busy = false }
        let minutes = durationMinutes == 0 ? customMinutes : durationMinutes
        guard (durationMinutes == -1 || (1...1440).contains(minutes)), policy.isValid else { message = "时间需在 1–1440 分钟范围内"; return }
        let duration = durationMinutes == -1 ? 0 : Double(minutes * 60)
        let now = readClock()
        sample = readSample()
        safety = SafetyEvaluator()
        if let reason = safety.evaluate(sample, policy: policy, now: now.continuous) { message = reason.message; return }
        message = "正在开启…"
        do {
            if lidMode {
                guard serviceStatus == .enabled else {
                    message = "合盖需要先安装并授权后台组件"; updateAuthorization(); return
                }
                let reply = try await send(HelperRequest(.acquire, duration: duration, policy: policy))
                guard reply.error == nil, reply.status.phase == .active, let id = reply.status.leaseID else {
                    message = reply.error ?? reply.status.error ?? "后台组件未确认开启"; return
                }
                leaseID = id; remaining = reply.status.remainingSeconds ?? 0
                if keepDisplay || nightMode { try assertion.start(keepDisplay: true) }
                helperState = "已连接"; helperConnected = true
                message = "已就绪，可以合盖 · 请放在通风处"
            } else {
                try assertion.start(keepDisplay: keepDisplay || nightMode)
                idleStart = now; idleDuration = duration; idlePolicy = policy; remaining = idleDuration
                message = nightMode ? "屏幕已调暗，停止后恢复 · 请保持开盖" : "可以锁屏离开 · 请保持开盖"
            }
            startedAt = now.wall; sessionSeconds = duration
            unlimitedSession = duration == 0
            if nightMode { dimmer.start(amount: dimAmount) }
            active = true
            // Starting once means the first-run tips have done their job.
            if !onboarded { acknowledge() }
        } catch {
            dimmer.stop(); try? assertion.stop()
            message = "开启失败：\(error.localizedDescription)"; client.disconnect()
        }
    }
    func extendSession() async {
        // Confirm the deadline and protection conditions before adding time.
        await refresh()
        guard active, !unlimitedSession, !busy, sessionSeconds + 900 <= 86400 else { return }
        actionGeneration &+= 1
        busy = true; defer { busy = false }
        do {
            if let id = leaseID {
                let reply = try await send(HelperRequest(.extend, leaseID: id, duration: 900))
                guard reply.error == nil, reply.status.phase == .active else {
                    throw AwakeError.backend(reply.error ?? reply.status.error ?? "会话已结束，无法延长")
                }
                remaining = reply.status.remainingSeconds ?? 0
            } else if idleStart != nil { idleDuration += 900; remaining += 900 }
            sessionSeconds += 900; message = "已延长 15 分钟"
        } catch { message = "延长失败：\(error.localizedDescription)" }
    }
    @discardableResult func stop() async -> Bool {
        guard !busy else { return false }
        actionGeneration &+= 1
        busy = true; defer { busy = false }
        dimmer.stop()
        do {
            try assertion.stop()
            if let id = leaseID {
                let reply = try await send(HelperRequest(.release, leaseID: id))
                // A watchdog may have already restored it before release arrived.
                guard reply.status.phase == .off else { throw AwakeError.backend(reply.error ?? reply.status.error ?? "睡眠设置尚未恢复") }
                leaseID = nil
            }
            if leaseID == nil, idleStart == nil, serviceStatus == .enabled {
                let reply = try await send(HelperRequest(.status))
                guard reply.status.phase == .off else {
                    throw AwakeError.backend(reply.status.error ?? "后台仍有会话或待恢复的睡眠设置，请先恢复")
                }
            }
            if active { recordEnd(StopReason.manual.message) }
            idleStart = nil; active = false; remaining = 0; unlimitedSession = false; needsRecovery = false; startedAt = nil
            message = "已停止，本应用不再阻止睡眠"; return true
        } catch {
            active = false; message = "恢复未确认：\(error.localizedDescription)"; client.disconnect(); return false
        }
    }
    func recover() async {
        guard helperBuildEnabled || requestHelper != nil else { message = "此预览没有合盖会话；请用已安装的签名 App 管理后台组件。"; return }
        guard !busy, !active, idleStart == nil else { return }
        actionGeneration &+= 1
        busy = true; defer { busy = false }
        do {
            let reply = try await send(HelperRequest(.recover))
            guard reply.error == nil, reply.status.phase == .off else {
                throw AwakeError.backend(reply.error ?? reply.status.error ?? "恢复尚未完成")
            }
            leaseID = nil; needsRecovery = false; message = "已确认睡眠设置已恢复"
        } catch { message = "恢复失败：\(error.localizedDescription)"; client.disconnect() }
    }
    func removeHelper() async {
        guard helperBuildEnabled else { message = "请用已安装的签名 App 移除后台组件。"; return }
        guard await stop() else { return }
        busy = true; defer { busy = false }
        do {
            // Verify persistent recovery before removing the independent watchdog.
            let reply = try await send(HelperRequest(.recover))
            guard reply.error == nil, reply.status.phase == .off else {
                throw AwakeError.backend(reply.error ?? reply.status.error ?? "睡眠设置未恢复，保留后台组件")
            }
            try await daemon.unregister()
            client.disconnect(); updateAuthorization(); message = "已恢复睡眠设置并卸载后台组件"
        } catch { message = "卸载失败：\(error.localizedDescription)" }
    }
    func quit() async {
        if await stop() { client.disconnect(); NSApp.terminate(nil) }
    }
    func refresh() async {
        guard !busy else { return }
        publish(\.sample, readSample())
        let now = readClock()
        if let start = idleStart {
            publish(\.remaining, max(0, idleDuration - (now.continuous - start.continuous)))
            var reason = safety.evaluate(sample, policy: idlePolicy, now: now.continuous)
            if idleDuration > 0 && remaining <= 0 { reason = .expired }
            if abs(now.wall.timeIntervalSince(start.wall) - (now.continuous - start.continuous)) > 60 { reason = .clockChanged }
            if let reason = reason {
                do {
                    try assertion.stop(); dimmer.stop(); idleStart = nil; active = false; unlimitedSession = false; remaining = 0
                    message = "已停止：\(reason.message)"; recordEnd(reason.message)
                }
                catch { active = false; message = "无法取消睡眠阻止：\(error.localizedDescription)" }
            }
            return
        }
        guard serviceStatus == .enabled else {
            updateAuthorization()
            if leaseID != nil {
                publish(\.active, false); dimmer.stop(); try? assertion.stop()
                publish(\.message, "后台组件授权已失效，无法确认睡眠设置是否已恢复")
            }
            return
        }
        guard !isRefreshing else { return }
        if let lastHelperPoll, now.continuous - lastHelperPoll < 5 { return }
        lastHelperPoll = now.continuous
        isRefreshing = true; defer { isRefreshing = false }
        let generation = actionGeneration
        do {
            let operation: HelperRequest = leaseID.map { HelperRequest(.renew, leaseID: $0) } ?? HelperRequest(.status)
            let reply = try await send(operation)
            // A user action may finish while this older status request is awaiting XPC.
            guard generation == actionGeneration else { return }
            publish(\.helperState, "已连接"); publish(\.helperConnected, true)
            publish(\.sample, reply.sample)
            if reply.status.phase == .active {
                // A new connection cannot adopt a lease from an earlier process.
                if leaseID != nil, reply.error == nil {
                    publish(\.active, true); publish(\.remaining, reply.status.remainingSeconds ?? 0)
                    publish(\.message, "已就绪，可以合盖 · 请放在通风处")
                } else { publish(\.active, false); publish(\.message, "后台有其他会话，等待结束或恢复") }
            } else {
                if leaseID != nil {
                    let reason = reply.status.stopReason?.message ?? "后台会话已结束"
                    recordEnd(reason + (reply.status.phase == .recoveryRequired ? "；恢复未确认" : ""))
                }
                publish(\.active, false); leaseID = nil; publish(\.remaining, 0); publish(\.unlimitedSession, false)
                dimmer.stop(); try assertion.stop()
                publish(\.needsRecovery, reply.status.phase == .recoveryRequired)
                if reply.status.phase == .recoveryRequired { publish(\.message, "需要恢复：\(reply.status.error ?? "未知错误")") }
                else if let reason = reply.status.stopReason { publish(\.message, "已停止：\(reason.message)") }
            }
        } catch {
            guard generation == actionGeneration else { return }
            publish(\.helperConnected, false)
            publish(\.active, false); dimmer.stop(); try? assertion.stop(); publish(\.helperState, "连接失败，状态未知")
            if leaseID != nil { publish(\.message, "与后台组件失去联系；它会自动恢复睡眠设置，但尚未确认") }
            client.disconnect()
        }
    }
}
