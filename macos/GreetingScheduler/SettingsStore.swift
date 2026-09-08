import Foundation

enum Provider: String, Codable, CaseIterable, Identifiable {
    case claude, codex
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var label: String { "com.user.\(rawValue).timer" }
}
struct Configuration: Codable, Equatable {
    var executable: String
    var enabled = true
    var hour: Int
    var minute: Int
    var time: String { String(format: "%02d:%02d", hour, minute) }
    func validate() throws {
        guard (0...23).contains(hour), (0...59).contains(minute) else { throw SchedulerError.message("Invalid schedule time") }
        guard executable.hasPrefix("/"), FileManager.default.isExecutableFile(atPath: executable),
              (try? URL(fileURLWithPath: executable).resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == false
        else { throw SchedulerError.message("Select an executable file at an absolute path: \(executable)") }
    }
}
struct Settings: Codable {
    var version = 1
    var providers: [String: Configuration] = [
        "claude": Configuration(executable: FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".local/bin/claude").path, hour: 8, minute: 30),
        "codex": Configuration(executable: "/Applications/ChatGPT.app/Contents/Resources/codex", hour: 8, minute: 0)
    ]
}
enum SchedulerError: LocalizedError {
    case message(String)
    var errorDescription: String? { if case .message(let text) = self { return text }; return nil }
}
struct SettingsStore {
    let root: URL
    init(root: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/GreetingScheduler")) { self.root = root }
    var file: URL { root.appendingPathComponent("settings.json") }
    func load() throws -> Settings {
        guard FileManager.default.fileExists(atPath: file.path) else { return Settings() }
        let settings = try JSONDecoder().decode(Settings.self, from: Data(contentsOf: file))
        guard settings.version == 1, Provider.allCases.allSatisfy({ settings.providers[$0.rawValue] != nil }) else { throw SchedulerError.message("Unsupported or incomplete settings file") }
        return settings
    }
    func prepare() throws {
        for sub in ["", "runners", "logs", "status", "backups"] {
            try FileManager.default.createDirectory(at: root.appendingPathComponent(sub), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        }
    }
    func save(_ settings: Settings) throws {
        try prepare()
        try JSONEncoder().encode(settings).write(to: file, options: .atomic)
    }
}
