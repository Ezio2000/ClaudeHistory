import SwiftUI
import AppKit

@main
struct ClaudeHistoryApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 空场景，菜单栏应用不需要窗口
        WindowGroup("", id: "empty") {
            EmptyView()
        }
        .defaultSize(width: 0, height: 0)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var sessionViewModel = SessionViewModel()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 隐藏 Dock 图标
        NSApp.setActivationPolicy(.accessory)

        // 创建菜单栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        guard let button = statusItem?.button else {
            print("Failed to create status item button")
            return
        }

        // 设置图标和标题
        button.title = "💬"
        button.action = #selector(togglePopover)
        button.target = self

        print("Status item created successfully")

        // 创建弹出窗口
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 600)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: SessionListView(viewModel: sessionViewModel))

        print("Popover created")

        // 加载会话数据
        sessionViewModel.loadSessions()
    }

    @objc func togglePopover() {
        guard let popover = popover, let button = statusItem?.button else { return }

        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
