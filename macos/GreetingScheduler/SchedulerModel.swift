import SwiftUI
import AppKit

struct RunRecord: Decodable {
    let pid: Int32
    let started: String
    let finished: String
    let exitCode: Int?
    var live: Bool { exitCode == nil && kill(pid, 0) == 0 }
    var summary: String {
        if live { return "Running since \(display(started))" }
        guard let code = exitCode else { return "Interrupted run (stale status) · \(display(started))" }
        return "\(code == 0 ? "Greeting succeeded" : "Greeting failed (exit \(code))") · \(display(finished))"
    }
    func display(_ value: String) -> String {
        guard let date = ISO8601DateFormatter().date(from: value) else { return value }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}
@MainActor final class SchedulerModel: ObservableObject {
    @Published var drafts = Settings().providers
    @Published var applied: [String: Configuration] = [:]
    @Published var inspections: [String: Inspection] = [:]
    @Published var records: [String: RunRecord] = [:]
    @Published var errors: [String: String] = [:]
    @Published var busy: Set<String> = []
    @Published var setupError: String?
    @Published var refreshing = false
    @Published var replacement: Set<String> = []
    private var initialized = false
    let manager = LaunchAgentManager()
    var needsSetup: Bool { Provider.allCases.contains { inspections[$0.rawValue]?.managed != true && drafts[$0.rawValue]?.enabled == true } }
    func refresh() async {
        guard !refreshing, busy.isEmpty else { return }
        refreshing = true
        defer { refreshing = false }
        let manager = manager
        do {
            let snapshot = try await Task.detached { () -> (Settings, [String: Inspection], [String: RunRecord]) in
                let settings = try manager.store.load()
                var inspections: [String: Inspection] = [:]
                var records: [String: RunRecord] = [:]
                for provider in Provider.allCases {
                    inspections[provider.rawValue] = try manager.inspect(provider, fallback: settings.providers[provider.rawValue]!)
                    let file = manager.store.root.appendingPathComponent("status/\(provider.rawValue).json")
                    if let data = try? Data(contentsOf: file) { records[provider.rawValue] = try? JSONDecoder().decode(RunRecord.self, from: data) }
                }
                return (settings, inspections, records)
            }.value
            guard busy.isEmpty else { return }
            inspections = snapshot.1; records = snapshot.2
            for provider in Provider.allCases {
                let key = provider.rawValue
                var actual = snapshot.1[key]?.configuration ?? snapshot.0.providers[key]!
                actual.enabled = snapshot.1[key]?.loaded == true
                if !initialized {
                    drafts[key] = snapshot.1[key]?.exists == true ? actual : snapshot.0.providers[key]!
                    if FileManager.default.fileExists(atPath: manager.store.file.path) { drafts[key] = actual }
                }
                applied[key] = actual
            }
            initialized = true; setupError = nil
        } catch { setupError = error.localizedDescription }
    }
    func update(_ provider: Provider) async {
        guard busy.isEmpty, setupError == nil else { return }
        let key = provider.rawValue
        guard records[key]?.live != true else { errors[key] = "Wait for the current greeting to finish before updating its schedule."; return }
        if inspections[key]?.unsupported == true && !replacement.contains(key) {
            errors[key] = "Confirm replacement of this unsupported schedule before applying."; return
        }
        busy.insert(key); errors[key] = nil
        let manager = manager; let config = drafts[key]!
        do {
            try await Task.detached { try manager.apply(provider, config: config) }.value
            replacement.remove(key)
        } catch { errors[key] = error.localizedDescription }
        busy.remove(key)
        await refresh()
    }
    func install() async { for provider in Provider.allCases { await update(provider) } }
    func run(_ provider: Provider) async {
        guard busy.isEmpty, setupError == nil else { return }
        let key = provider.rawValue
        busy.insert(key); errors[key] = nil
        let manager = manager; let config = drafts[key]!
        do {
            let result = try await Task.detached { try manager.run(provider, config: config) }.value
            if result.code == 75 && result.output.contains("GREETING_SCHEDULER_ALREADY_RUNNING") { errors[key] = "Already running. No duplicate greeting was sent." }
            else if result.code != 0 { errors[key] = "Greeting failed (exit \(result.code)). View logs for details." }
        } catch { errors[key] = error.localizedDescription }
        busy.remove(key); await refresh()
    }
    func logs(_ provider: Provider) {
        let file = manager.store.root.appendingPathComponent("logs/\(provider.rawValue).log")
        if FileManager.default.fileExists(atPath: file.path) { NSWorkspace.shared.open(file) }
        else { errors[provider.rawValue] = "No log file yet. Logs are created when a greeting runs." }
    }
    func chooseExecutable(_ provider: Provider) {
        let panel = NSOpenPanel(); panel.canChooseDirectories = false; panel.allowsMultipleSelection = false
        panel.title = "Select \(provider.title) executable"; panel.showsHiddenFiles = true
        if panel.runModal() == .OK, let url = panel.url { drafts[provider.rawValue]?.executable = url.path }
    }
}
