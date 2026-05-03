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
    let taskType: String?
    let taskLabel: String?
    let taskColor: String?
    let statusColor: String?
    let displayTitle: String?
    let displaySubtitle: String?
    let isInternal: Bool?
    let sessionID: String?
    let transcriptPath: String?
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
        case taskType = "task_type"
        case taskLabel = "task_label"
        case taskColor = "task_color"
        case statusColor = "status_color"
        case displayTitle = "display_title"
        case displaySubtitle = "display_subtitle"
        case isInternal = "is_internal"
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
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
    let taskType: String?
    let taskLabel: String?
    let taskColor: String?
    let statusColor: String?
    let displayTitle: String?
    let displaySubtitle: String?
    let isInternal: Bool?
    let sessionID: String?
    let transcriptPath: String?
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
        case taskType = "task_type"
        case taskLabel = "task_label"
        case taskColor = "task_color"
        case statusColor = "status_color"
        case displayTitle = "display_title"
        case displaySubtitle = "display_subtitle"
        case isInternal = "is_internal"
        case sessionID = "session_id"
        case transcriptPath = "transcript_path"
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
        let task = event?.taskLabel ?? level.label
        titleLabel.stringValue = event?.displayTitle ?? event?.title ?? "Codex 空闲"
        bodyLabel.stringValue = "\(task) · \(event?.displaySubtitle ?? event?.body ?? "等待 Codex 事件")"
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

private final class SessionCardView: NSView {
    private let color: NSColor
    private let sessionID: String?
    private let statusSymbol: String
    private let titleText: String
    private let subtitleText: String

    init(title: String, subtitle: String, statusSymbol: String, color: NSColor, sessionID: String?) {
        self.titleText = title
        self.subtitleText = subtitle
        self.statusSymbol = statusSymbol
        self.color = color
        self.sessionID = sessionID
        super.init(frame: NSRect(x: 0, y: 0, width: 540, height: 78))
        wantsLayer = true
        toolTip = sessionID?.isEmpty == false ? "点击打开这个 Codex 线程" : nil
        buildLabels()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func buildLabels() {
        let titleLabel = NSTextField(labelWithString: titleText)
        titleLabel.frame = NSRect(x: 52, y: 41, width: 410, height: 24)
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        addSubview(titleLabel)

        let subtitleLabel = NSTextField(labelWithString: subtitleText)
        subtitleLabel.frame = NSRect(x: 52, y: 15, width: 410, height: 22)
        subtitleLabel.font = .systemFont(ofSize: 13, weight: .regular)
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.lineBreakMode = .byTruncatingTail
        addSubview(subtitleLabel)

        let statusLabel = NSTextField(labelWithString: statusSymbol)
        statusLabel.frame = NSRect(x: 486, y: 39, width: 30, height: 26)
        statusLabel.font = .systemFont(ofSize: 18, weight: .bold)
        statusLabel.alignment = .center
        statusLabel.textColor = color
        addSubview(statusLabel)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let card = bounds.insetBy(dx: 10, dy: 6)
        let path = NSBezierPath(roundedRect: card, xRadius: 18, yRadius: 18)
        NSColor.controlBackgroundColor.withAlphaComponent(0.92).setFill()
        path.fill()
        NSColor.separatorColor.withAlphaComponent(0.65).setStroke()
        path.lineWidth = 1
        path.stroke()

        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 26, y: 48, width: 12, height: 12)).fill()
    }

    override func mouseDown(with event: NSEvent) {
        guard let sessionID, !sessionID.isEmpty,
              let url = URL(string: "codex://threads/\(sessionID)") else {
            return
        }
        NSWorkspace.shared.open(url)
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
    private var threadTitleCache: [String: String] = [:]

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

        if let button = statusItem.button {
            button.attributedTitle = statusBarTitle(event: event, sessions: sessions)
            button.toolTip = tooltipTitle(event: event, sessions: sessions)
        }

        let headline = NSMenuItem(title: "Codex 任务看板", action: nil, keyEquivalent: "")
        headline.isEnabled = false
        menu.addItem(headline)

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
        addLegend(to: menu)

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

    private func addLegend(to menu: NSMenu) {
        menu.addItem(.separator())
        let header = NSMenuItem(title: "颜色说明", action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        let entries: [(String, String)] = [
            ("#C2410C", "橙红：需要确认/反馈"),
            ("#2563EB", "蓝：写代码/处理中"),
            ("#0F766E", "青：测试/构建"),
            ("#7C3AED", "紫：GitHub 发布"),
            ("#15803D", "绿：完成"),
            ("#475569", "灰：查看/资料")
        ]
        for entry in entries {
            let item = NSMenuItem(title: entry.1, action: nil, keyEquivalent: "")
            item.image = dotImage(color: colorFromHex(entry.0) ?? .secondaryLabelColor)
            item.isEnabled = false
            menu.addItem(item)
        }
    }

    private func addSessionSection(title: String, sessions: [CodexSessionSummary], to menu: NSMenu) {
        guard !sessions.isEmpty else {
            return
        }
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for session in sessions.prefix(6) {
            let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
            item.view = SessionCardView(
                title: displayTitle(for: session),
                subtitle: displaySubtitle(for: session),
                statusSymbol: statusSymbol(for: session),
                color: colorFor(session: session),
                sessionID: session.sessionID
            )
            menu.addItem(item)
        }
    }

    private func statusBarTitle(event: CodexStatusEvent?, sessions: [CodexSessionSummary]) -> NSAttributedString {
        let text: String
        let color: NSColor
        if let top = topSessionForStatus(sessions) {
            text = sessionStatusTitle(top)
            color = colorFor(session: top)
        } else {
            text = shortStatusTitle(event: event, sessions: sessions)
            color = colorFor(event: event)
        }

        let result = NSMutableAttributedString(
            string: "● ",
            attributes: [
                .foregroundColor: color,
                .font: NSFont.systemFont(ofSize: 13, weight: .bold)
            ]
        )
        result.append(NSAttributedString(
            string: text,
            attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold)
            ]
        ))
        return result
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
        return "\(level.menuTitle) · \(menuSafe(displayTitle(for: session), limit: 18))"
    }

    private func tooltipTitle(event: CodexStatusEvent?, sessions: [CodexSessionSummary]) -> String {
        if let top = topSessionForStatus(sessions) {
            let title = displayTitle(for: top)
            let text = displaySubtitle(for: top)
            return "\(title)\n\(text)"
        }
        let title = event?.displayTitle ?? event?.title ?? "Codex 空闲"
        let text = event?.displaySubtitle ?? event?.progress ?? event?.body ?? "新的 Codex 动态会显示在这里。"
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
        return sessions.values.filter { !isInternalSession($0) }.sorted {
            let leftPriority = $0.priority ?? priorityFallback(for: $0)
            let rightPriority = $1.priority ?? priorityFallback(for: $1)
            if leftPriority != rightPriority {
                return leftPriority > rightPriority
            }
            return ($0.timestamp ?? 0) > ($1.timestamp ?? 0)
        }
    }

    private func isInternalSession(_ session: CodexSessionSummary) -> Bool {
        if session.isInternal == true {
            return true
        }
        let project = (session.project ?? session.workspace ?? "").lowercased()
        if project == "screen_recording" {
            return true
        }
        let text = cleanDisplay(session.displaySubtitle ?? session.progress ?? session.body ?? "")
        return text.lowercased().hasPrefix("memory summary") || text.lowercased().hasPrefix("context of everything")
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

    private func taskLabel(for session: CodexSessionSummary) -> String {
        if let label = session.taskLabel, !label.isEmpty {
            return label
        }
        switch StatusLevel(session: session) {
        case .needsFeedback: return "要反馈"
        case .done: return "完成"
        case .running: return "处理"
        case .idle: return "空闲"
        }
    }

    private func displayTitle(for session: CodexSessionSummary) -> String {
        if let title = cleanOptional(session.displayTitle), title != "后台摘要" {
            return menuSafe(title, limit: 34)
        }
        if let path = session.transcriptPath,
           let title = threadTitle(from: path) {
            return menuSafe(title, limit: 34)
        }
        if let title = cleanOptional(session.title),
           !title.hasPrefix("Codex 已完成"),
           !title.hasPrefix("Codex 运行中"),
           !title.hasPrefix("Codex 需要你") {
            return menuSafe(title, limit: 34)
        }
        if let project = cleanOptional(session.project ?? session.workspace),
           !["codex", "workspace", "screen_recording"].contains(project.lowercased()) {
            return menuSafe(project, limit: 34)
        }
        return menuSafe(cleanDisplay(session.progress ?? session.body ?? "Codex 任务"), limit: 34)
    }

    private func displaySubtitle(for session: CodexSessionSummary) -> String {
        if let subtitle = cleanOptional(session.displaySubtitle) {
            return menuSafe(subtitle, limit: 64)
        }
        let text = cleanDisplay(session.progress ?? session.body ?? session.title ?? "等待更新")
        return menuSafe(text, limit: 64)
    }

    private func statusSymbol(for session: CodexSessionSummary) -> String {
        if session.requiresUser == true {
            return "!"
        }
        switch StatusLevel(session: session) {
        case .done: return "✓"
        case .running: return "○"
        case .needsFeedback: return "!"
        case .idle: return "·"
        }
    }

    private func cleanOptional(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let cleaned = cleanDisplay(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func cleanDisplay(_ value: String) -> String {
        var text = value.replacingOccurrences(of: "\n", with: " ")
        while text.hasPrefix("#") {
            text.removeFirst()
        }
        text = text.replacingOccurrences(of: "`", with: "")
        text = text.replacingOccurrences(of: "*", with: "")
        return text.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func threadTitle(from transcriptPath: String) -> String? {
        if let cached = threadTitleCache[transcriptPath] {
            return cached
        }
        guard let handle = FileHandle(forReadingAtPath: transcriptPath) else {
            return nil
        }
        defer { try? handle.close() }
        let data = handle.readData(ofLength: 256_000)
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        for line in text.split(separator: "\n").prefix(260) {
            guard let data = line.data(using: .utf8),
                  let item = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let payload = item["payload"] as? [String: Any] else {
                continue
            }
            if payload["type"] as? String == "thread_name_updated",
               let title = payload["thread_name"] as? String {
                let cleaned = cleanDisplay(title)
                threadTitleCache[transcriptPath] = cleaned
                return cleaned
            }
        }
        return nil
    }

    private func colorFor(event: CodexStatusEvent?) -> NSColor {
        if let hex = event?.statusColor, let color = colorFromHex(hex) {
            return color
        }
        return StatusLevel(event: event).borderColor
    }

    private func colorFor(session: CodexSessionSummary) -> NSColor {
        if session.requiresUser == true,
           let hex = session.statusColor,
           let color = colorFromHex(hex) {
            return color
        }
        if let hex = session.taskColor, let color = colorFromHex(hex) {
            return color
        }
        if let hex = session.statusColor, let color = colorFromHex(hex) {
            return color
        }
        return StatusLevel(session: session).borderColor
    }

    private func colorFromHex(_ value: String) -> NSColor? {
        let hex = value.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard hex.count == 6 else {
            return nil
        }
        guard let number = Int(hex, radix: 16) else {
            return nil
        }
        let red = CGFloat((number >> 16) & 0xFF) / 255.0
        let green = CGFloat((number >> 8) & 0xFF) / 255.0
        let blue = CGFloat(number & 0xFF) / 255.0
        return NSColor(calibratedRed: red, green: green, blue: blue, alpha: 1.0)
    }

    private func dotImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 12, height: 12)
        let image = NSImage(size: size)
        image.lockFocus()
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 8, height: 8)).fill()
        image.unlockFocus()
        image.isTemplate = false
        return image
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
