import AppKit
import Foundation
import UserNotifications

private struct CodexStatusEvent: Decodable {
    let eventID: String
    let timestamp: TimeInterval
    let hookEventName: String?
    let sessionID: String?
    let workspace: String?
    let title: String?
    let body: String?

    enum CodingKeys: String, CodingKey {
        case eventID = "event_id"
        case timestamp
        case hookEventName = "hook_event_name"
        case sessionID = "session_id"
        case workspace
        case title
        case body
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let latestURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexStatusBar/latest.json")
    private let eventsURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/CodexStatusBar/events.jsonl")

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
        let title = event?.title ?? "Codex idle"
        let workspace = event?.workspace ?? "Waiting for events"
        let body = event?.body ?? "New Codex activity will appear here."

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
        menu.addItem(NSMenuItem(title: "Open Codex", action: #selector(openCodex), keyEquivalent: "o"))
        menu.addItem(NSMenuItem(title: "Open Event Log", action: #selector(openEventLog), keyEquivalent: "l"))
        if let sessionID = event?.sessionID, !sessionID.isEmpty {
            let item = NSMenuItem(title: "Open Current Thread", action: #selector(openCurrentThread), keyEquivalent: "t")
            item.representedObject = sessionID
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Codex Status", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    private func shortStatusTitle(for event: CodexStatusEvent?) -> String {
        guard let event else { return "Codex -" }
        switch event.hookEventName {
        case "SessionStart":
            return "Codex ..."
        case "UserPromptSubmit":
            return "Codex ->"
        case "Stop":
            return "Codex OK"
        case "PreToolUse":
            return "Codex *"
        default:
            return "Codex"
        }
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
        return event.hookEventName == "Stop" || event.hookEventName == "UserPromptSubmit"
    }

    private func notify(_ event: CodexStatusEvent) {
        let content = UNMutableNotificationContent()
        content.title = event.title ?? "Codex"
        content.body = event.body ?? "Codex updated."
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
