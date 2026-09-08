import SwiftUI
import AppKit
final class AppDelegate: NSObject, NSApplicationDelegate {
    var reopen: (() -> Void)?
    func applicationDidFinishLaunching(_ notification: Notification) { NSApp.setActivationPolicy(.regular); NSApp.activate(ignoringOtherApps: true) }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { reopen?() }
        sender.activate(ignoringOtherApps: true)
        return true
    }
}
@main struct GreetingSchedulerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = SchedulerModel()
    var body: some Scene {
        Window("Auto Session Start", id: "main") { MainWindowContent(delegate: delegate).environmentObject(model) }
            .defaultSize(width: 700, height: 760)
        SwiftUI.Settings { SettingsView().environmentObject(model) }
    }
}

struct MainWindowContent: View {
    let delegate: AppDelegate
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        SchedulerView().onAppear { delegate.reopen = { openWindow(id: "main") } }
    }
}
