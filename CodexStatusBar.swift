import AppKit
import Foundation
import UserNotifications

private struct CodexStatusEvent: Decodable {
    let eventID: String
    let timestamp: TimeInterval
    let hookEventName: String?
    let kind: String?
    let phase: String?
    let level: String?
    let statusLabel: String?
    let requiresUser: Bool?
    let shouldAlert: Bool?
    let priority: Int?
    let sessionID: String?
    let workspace: String?
    let project: String?
    let title: String?
    let body: String?
    let progress: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case timestamp
        case hookEventName = "hook_event_name"
        case kind
        case phase
        case level
        case statusLabel = "status_label"
        case requiresUser = "requires_user"
        case shouldAlert = "should_alert"
        case priority
        case sessionID = "session_id"
        case workspace
        case project
        case title
        case body
        case progress
    }
}

private struct CodexSessionSummary: Decodable {
    let eventID: String?
    let timestamp: TimeInterval?
    let hookEventName: String?
    let kind: String?
    let phase: String?
    let level: String?
    let statusLabel: String?
    let requiresUser: Bool?
    let shouldAlert: Bool?
    let priority: Int?
    let sessionID: String?
    let workspace: String?
    let project: String?
    let title: String?
    let body: String?
    let progress: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case timestamp
        case hookEventName = "hook_event_name"
        case kind
        case phase
        case level
        case statusLabel = "status_label"
        case requiresUser = "requires_user"
        case shouldAlert = "should_alert"
        case priority
        case sessionID = "session_id"
        case workspace
        case project
        case title
        case body
        case progress
    }
}

private enum StatusLevel {
    case idle
    case running
    case done
    case needsFeedback

    init(level: String?, hookEventName: String?) {
        switch level {
        case "needs_feedback":
            self = .needsFeedback
        case "done":
            self = .done
        case "running":
            self = .running
        default:
            switch hookEventName {
            case "Notification", "PermissionRequest":
                self = .needsFeedback
            case "Stop":
                self = .done
            case nil:
                self = .idle
            default:
                self = .running
            }
        }
    }

    init(event: CodexStatusEvent?) {
        self.init(level: event?.level, hookEventName: event?.hookEventName)
    }

    init(session: CodexSessionSummary) {
        self.init(level: session.level, hookEventName: session.hookEventName)
    }

    var label: String {
        switch self {
        case .idle: return "空闲"
        case .running: return "运行中"
        case .done: return "已完成"
        case .needsFeedback: return "需要反馈"
        }
    }

    var menuTitle: String {
        switch self {
        case .idle: return "Codex -"
        case .running: return "Codex 运行中"
        case .done: return "Codex 已完成"
        case .needsFeedback: return "Codex 需要你"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .idle:
            return NSColor(calibratedWhite: 0.12, alpha: 0.90)
        case .running:
            return NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.45, alpha: 0.94)
        case .done:
            return NSColor(calibratedRed: 0.06, green: 0.34, blue: 0.18, alpha: 0.94)
        case .needsFeedback:
            return NSColor(calibratedRed: 0.62, green: 0.18, blue: 0.04, alpha: 0.96)
        }
    }

    var borderColor: NSColor {
        switch self {
        case .idle:
            return NSColor(calibratedWhite: 0.45, alpha: 0.80)
        case .running:
            return NSColor(calibratedRed: 0.35, green: 0.62, blue: 1.0, alpha: 0.95)
        case .done:
            return NSColor(calibratedRed: 0.34, green: 0.88, blue: 0.52, alpha: 0.95)
        case .needsFeedback:
            return NSColor(calibratedRed: 1.0, green: 0.70, blue: 0.35, alpha: 1.0)
        }
    }
}

private final class IslandContentView: NSView {
    private let badgeLabel = NSTextField(labelWithString: "空闲")
    private let titleLabel = NSTextField(labelWithString: "Codex 空闲")
    private let bodyLabel = NSTextField(labelWithString: "等待 Codex 事件")
    private var level: StatusLevel = .idle

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        for label in [badgeLabel, titleLabel, bodyLabel] {
            label.translatesAutoresizingMaskIntoConstraints = false
            label.lineBreakMode = .byTruncatingTail
            label.textColor = .white
            addSubview(label)
        }

        badgeLabel.font = .systemFont(ofSize: 13, weight: .bold)
        titleLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        bodyLabel.font = .systemFont(ofSize: 12, weight: .regular)
        bodyLabel.textColor = NSColor(white: 1.0, alpha: 0.78)

        NSLayoutConstraint.activate([
            badgeLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 18),
            badgeLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        badgeLabel.widthAnchor.constraint(equalToConstant: 88),

            titleLabel.leadingAnchor.constraint(equalTo: badgeLabel.trailingAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -18),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 9),

            bodyLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            bodyLabel.trailingAnchor.constraint(equalTo: titleLabel.trailingAnchor),
            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(event: CodexStatusEvent?) {
        level = StatusLevel(event: event)
        badgeLabel.stringValue = level.label
        titleLabel.stringValue = event?.title ?? "Codex 空闲"
        bodyLabel.stringValue = event?.body ?? "等待 Codex 事件"
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 18, yRadius: 18)
        level.backgroundColor.setFill()
        path.fill()
        level.borderColor.setStroke()
        path.lineWidth = 2
        path.stroke()
    }
}

private final class IslandWindowController {
    private let panel: NSPanel
    private let contentView: IslandContentView
    private var hideWorkItem: DispatchWorkItem?

    init() {
        contentView = IslandContentView(frame: NSRect(x: 0, y: 0, width: 540, height: 58))
        panel = NSPanel(
            contentRect: contentView.bounds,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = contentView
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true
    }

    func show(event: CodexStatusEvent?) {
        contentView.update(event: event)
        position()
        panel.orderFrontRegardless()

        hideWorkItem?.cancel()
        let level = StatusLevel(event: event)
        let duration: TimeInterval = level == .needsFeedback ? 18 : 7
        let item = DispatchWorkItem { [weak self] in
            self?.panel.orderOut(nil)
        }
        hideWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: item)
    }

    private func position() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return
        }

        let screenFrame = screen.frame
        let visibleFrame = screen.visibleFrame
        let width = min(560, max(440, visibleFrame.width * 0.36))
        let height: CGFloat = 58
        let topInset: CGFloat
        if #available(macOS 12.0, *) {
            topInset = max(screen.safeAreaInsets.top, screenFrame.maxY - visibleFrame.maxY)
        } else {
            topInset = screenFrame.maxY - visibleFrame.maxY
        }
        let yOffset = max(topInset + 8, 12)
        let x = visibleFrame.midX - width / 2
        let y = screenFrame.maxY - yOffset - height
        panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let latestURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexStatusBar/latest.json")
    private let eventsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexStatusBar/events.jsonl")
    private let sessionsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexStatusBar/sessions.json")
    private let island = IslandWindowController()

    private var timer: Timer?
    private var latestEventID: String?
    private var hasLoadedInitialEvent = false
    private let launchTime = Date().timeIntervalSince1970

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        configureMenu(event: nil, sessions: [])
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func configureMenu(event: CodexStatusEvent?, sessions: [CodexSessionSummary]) {
        let menu = NSMenu()
        let title = event?.title ?? "Codex 空闲"
        let workspace = event?.project ?? event?.workspace ?? "等待 Codex 事件"
        let progress = event?.progress ?? event?.body ?? "新的 Codex 动态会显示在这里。"

        if let button = statusItem.button {
            button.title = shortStatusTitle(event: event, sessions: sessions)
            button.toolTip = tooltipTitle(event: event, sessions: sessions)
        }

        let headline = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        headline.isEnabled = false
        menu.addItem(headline)

        let workspaceItem = NSMenuItem(title: workspace, action: nil, keyEquivalent: "")
        workspaceItem.isEnabled = false
        menu.addItem(workspaceItem)

        let progressItem = NSMenuItem(title: "进度：\(menuSafe(progress, limit: 72))", action: nil, keyEquivalent: "")
        progressItem.isEnabled = false
        menu.addItem(progressItem)

        menu.addItem(.separator())
        addSessionSection(
            title: "需要你看",
            sessions: sessions.filter { $0.requiresUser == true },
            to: menu
        )
        addSessionSection(
            title: "运行中",
            sessions: sessions.filter { StatusLevel(session: $0) == .running && $0.requiresUser != true },
            to: menu
        )
        addSessionSection(
            title: "最近完成",
            sessions: sessions.filter { StatusLevel(session: $0) == .done },
            to: menu
        )
        if sessions.isEmpty {
            let emptyItem = NSMenuItem(title: "暂无会话进度", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开 Codex", action: #selector(openCodex), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "打开事件日志", action: #selector(openEventLog), keyEquivalent: "l"))
        menu.addItem(NSMenuItem(title: "打开会话进度", action: #selector(openSessions), keyEquivalent: "s"))
        if let sessionID = event?.sessionID, !sessionID.isEmpty {
            let item = NSMenuItem(title: "打开当前线程", action: #selector(openCurrentThread), keyEquivalent: "t")
            item.representedObject = sessionID
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Codex 状态栏", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func addSessionSection(title: String, sessions: [CodexSessionSummary], to menu: NSMenu) {
        guard !sessions.isEmpty else {
            return
        }
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for session in sessions.prefix(6) {
            let level = StatusLevel(session: session)
            let project = session.project ?? session.workspace ?? "Workspace"
            let text = session.progress ?? session.body ?? session.title ?? "等待事件"
            let item = NSMenuItem(
                title: "\(level.label) | \(menuSafe(project, limit: 24)) | \(menuSafe(text, limit: 48))",
                action: nil,
                keyEquivalent: ""
            )
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func shortStatusTitle(event: CodexStatusEvent?, sessions: [CodexSessionSummary]) -> String {
        if let top = topSessionForStatus(sessions) {
            return sessionStatusTitle(top)
        }
        let level = StatusLevel(event: event)
        guard level != .idle,
              let project = event?.project ?? event?.workspace,
              !project.isEmpty else {
            return level.menuTitle
        }
        return "\(level.menuTitle) · \(menuSafe(project, limit: 18))"
    }

    private func sessionStatusTitle(_ session: CodexSessionSummary) -> String {
        let level = StatusLevel(session: session)
        let project = session.project ?? session.workspace ?? ""
        guard !project.isEmpty else {
            return level.menuTitle
        }
        return "\(level.menuTitle) · \(menuSafe(project, limit: 18))"
    }

    private func tooltipTitle(event: CodexStatusEvent?, sessions: [CodexSessionSummary]) -> String {
        if let top = topSessionForStatus(sessions) {
            let title = top.title ?? sessionStatusTitle(top)
            let text = top.progress ?? top.body ?? "等待事件"
            return "\(title)\n\(text)"
        }
        let title = event?.title ?? "Codex 空闲"
        let text = event?.progress ?? event?.body ?? "新的 Codex 动态会显示在这里。"
        return "\(title)\n\(text)"
    }

    private func topSessionForStatus(_ sessions: [CodexSessionSummary]) -> CodexSessionSummary? {
        if let attention = sessions.first(where: { $0.requiresUser == true }) {
            return attention
        }
        if let running = sessions.first(where: { StatusLevel(session: $0) == .running }) {
            return running
        }
        return sessions.first
    }

    private func refresh() {
        guard let data = try? Data(contentsOf: latestURL),
              let event = try? JSONDecoder().decode(CodexStatusEvent.self, from: data) else {
            return
        }
        let sessions = loadSessions()

        configureMenu(event: event, sessions: sessions)
        if latestEventID != event.eventID {
            let isLiveAfterLaunch = event.timestamp >= launchTime - 2
            let shouldNotify = (hasLoadedInitialEvent || isLiveAfterLaunch) && shouldNotify(for: event)
            latestEventID = event.eventID
            hasLoadedInitialEvent = true
            if shouldNotify {
                island.show(event: event)
                notify(event)
            }
        } else {
            hasLoadedInitialEvent = true
        }
    }

    private func shouldNotify(for event: CodexStatusEvent) -> Bool {
        guard Date().timeIntervalSince1970 - event.timestamp < 30 else {
            return false
        }
        if let explicit = event.shouldAlert {
            return explicit
        }
        let level = StatusLevel(event: event)
        return level == .done || level == .needsFeedback
    }

    private func loadSessions() -> [CodexSessionSummary] {
        guard let data = try? Data(contentsOf: sessionsURL),
              let sessions = try? JSONDecoder().decode([String: CodexSessionSummary].self, from: data) else {
            return []
        }
        return sessions.values.sorted {
            let leftPriority = $0.priority ?? priorityFallback(for: $0)
            let rightPriority = $1.priority ?? priorityFallback(for: $1)
            if leftPriority != rightPriority {
                return leftPriority > rightPriority
            }
            return ($0.timestamp ?? 0) > ($1.timestamp ?? 0)
        }
    }

    private func priorityFallback(for session: CodexSessionSummary) -> Int {
        if session.requiresUser == true {
            return 90
        }
        switch StatusLevel(session: session) {
        case .needsFeedback: return 90
        case .running: return 30
        case .done: return 15
        case .idle: return 0
        }
    }

    private func menuSafe(_ value: String, limit: Int) -> String {
        let compact = value.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if compact.count <= limit {
            return compact
        }
        let end = compact.index(compact.startIndex, offsetBy: max(1, limit - 1))
        return String(compact[..<end]) + "..."
    }

    private func notify(_ event: CodexStatusEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title ?? "Codex"
        content.body = event.body ?? "Codex 状态已更新。"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: event.eventID,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    @objc private func openCodex() {
        NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/Codex.app"))
    }

    @objc private func openEventLog() {
        NSWorkspace.shared.activateFileViewerSelecting([eventsURL])
    }

    @objc private func openSessions() {
        NSWorkspace.shared.activateFileViewerSelecting([sessionsURL])
    }

    @objc private func openCurrentThread(_ sender: NSMenuItem) {
        guard let sessionID = sender.representedObject as? String,
              let url = URL(string: "codex://threads/\(sessionID)") else {
            openCodex()
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

let app = NSApplication.shared
private let delegate = AppDelegate()
app.delegate = delegate
app.run()
