import AppKit
import Foundation
import UserNotifications

private struct CodexStatusEvent: Decodable {
    let eventID: String
    let timestamp: TimeInterval
    let hookEventName: String?
    let level: String?
    let sessionID: String?
    let workspace: String?
    let title: String?
    let body: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case timestamp
        case hookEventName = "hook_event_name"
        case level
        case sessionID = "session_id"
        case workspace
        case title
        case body
    }
}

private enum StatusLevel {
    case idle
    case running
    case done
    case needsFeedback

    init(event: CodexStatusEvent?) {
        switch event?.level {
        case "needs_feedback":
            self = .needsFeedback
        case "done":
            self = .done
        case "running":
            self = .running
        default:
            switch event?.hookEventName {
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
    private let island = IslandWindowController()

    private var timer: Timer?
    private var latestEventID: String?
    private var hasLoadedInitialEvent = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }

        configureMenu(event: nil)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func configureMenu(event: CodexStatusEvent?) {
        let menu = NSMenu()
        let title = event?.title ?? "Codex 空闲"
        let workspace = event?.workspace ?? "等待 Codex 事件"
        let body = event?.body ?? "新的 Codex 动态会显示在这里。"

        if let button = statusItem.button {
            button.title = shortStatusTitle(for: event)
            button.toolTip = "\(title)\n\(body)"
        }

        let headline = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        headline.isEnabled = false
        menu.addItem(headline)

        let workspaceItem = NSMenuItem(title: workspace, action: nil, keyEquivalent: "")
        workspaceItem.isEnabled = false
        menu.addItem(workspaceItem)

        let bodyItem = NSMenuItem(title: body, action: nil, keyEquivalent: "")
        bodyItem.isEnabled = false
        menu.addItem(bodyItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "打开 Codex", action: #selector(openCodex), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "打开事件日志", action: #selector(openEventLog), keyEquivalent: "l"))
        if let sessionID = event?.sessionID, !sessionID.isEmpty {
            let item = NSMenuItem(title: "打开当前线程", action: #selector(openCurrentThread), keyEquivalent: "t")
            item.representedObject = sessionID
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 Codex 状态栏", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func shortStatusTitle(for event: CodexStatusEvent?) -> String {
        StatusLevel(event: event).menuTitle
    }

    private func refresh() {
        guard let data = try? Data(contentsOf: latestURL),
              let event = try? JSONDecoder().decode(CodexStatusEvent.self, from: data) else {
            return
        }

        configureMenu(event: event)
        if latestEventID != event.eventID {
            let shouldNotify = hasLoadedInitialEvent && shouldNotify(for: event)
            latestEventID = event.eventID
            hasLoadedInitialEvent = true
            island.show(event: event)
            if shouldNotify {
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
        let level = StatusLevel(event: event)
        return level == .done || level == .needsFeedback || event.hookEventName == "UserPromptSubmit"
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
