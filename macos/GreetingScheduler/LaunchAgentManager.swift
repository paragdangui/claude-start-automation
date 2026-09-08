import Foundation

struct Inspection {
    var loaded: Bool
    var exists: Bool
    var configuration: Configuration?
    var managed: Bool
    var unsupported: Bool
}
struct LaunchAgentManager {
    let store: SettingsStore
    let agents: URL
    let resource: URL
    var command: (String, [String]) throws -> CommandResult = ProcessRunner.run
    var domain: String { "gui/\(getuid())" }
    init(store: SettingsStore = SettingsStore(), agents: URL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents"), resource: URL? = nil) {
        self.store = store; self.agents = agents
        self.resource = resource ?? Bundle.main.url(forResource: "runner", withExtension: "sh")!
    }
    func plist(_ provider: Provider) -> URL { agents.appendingPathComponent(provider.label + ".plist") }
    func runner(_ provider: Provider) -> URL { store.root.appendingPathComponent("runners/start-\(provider.rawValue)-timer.sh") }
    func loaded(_ provider: Provider) throws -> Bool {
        try command("/bin/launchctl", ["print", "\(domain)/\(provider.label)"]).code == 0
    }
    func inspect(_ provider: Provider, fallback: Configuration) throws -> Inspection {
        let exists = FileManager.default.fileExists(atPath: plist(provider).path)
        let isLoaded = try loaded(provider)
        guard exists else { return Inspection(loaded: isLoaded, exists: false, configuration: nil, managed: false, unsupported: isLoaded) }
        let dictionary = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist(provider)), format: nil) as? [String: Any] ?? [:]
        let entries = dictionary["StartCalendarInterval"] as? [[String: Int]] ?? []
        let first = entries.first ?? [:]
        let representable = entries.count == 5 && Set(entries.compactMap { $0["Weekday"] }) == Set(1...5) && entries.allSatisfy { $0.count == 3 && $0["Hour"] == first["Hour"] && $0["Minute"] == first["Minute"] } && (0...23).contains(first["Hour"] ?? -1) && (0...59).contains(first["Minute"] ?? -1)
        let arguments = dictionary["ProgramArguments"] as? [String] ?? []
        let managed = arguments.count == 5 && arguments[1] == runner(provider).path
        var config = fallback
        config.enabled = isLoaded
        if representable { config.hour = first["Hour"]!; config.minute = first["Minute"]! }
        if managed { config.executable = arguments[3] }
        // Other triggers cannot be represented by the version-one controls.
        let extraTriggers = dictionary["StartInterval"] != nil || dictionary["KeepAlive"] != nil || (dictionary["RunAtLoad"] as? Bool == true) || dictionary["WatchPaths"] != nil || dictionary["QueueDirectories"] != nil || dictionary["StartOnMount"] as? Bool == true || dictionary["LaunchEvents"] != nil || dictionary["Sockets"] != nil || dictionary["MachServices"] != nil
        return Inspection(loaded: isLoaded, exists: true, configuration: config, managed: managed, unsupported: !representable || extraTriggers)
    }
    func prepareRunner(_ provider: Provider) throws {
        try store.prepare()
        try Data(contentsOf: resource).write(to: runner(provider), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: runner(provider).path)
    }
    func data(_ provider: Provider, _ config: Configuration) throws -> Data {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let dictionary: [String: Any] = [
            "Label": provider.label,
            "ProgramArguments": ["/bin/bash", runner(provider).path, provider.rawValue, config.executable, store.root.path],
            "StartCalendarInterval": (1...5).map { ["Weekday": $0, "Hour": config.hour, "Minute": config.minute] },
            "RunAtLoad": false,
            "WorkingDirectory": home,
            "EnvironmentVariables": ["HOME": home, "PATH": "\(home)/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"],
            "StandardOutPath": store.root.appendingPathComponent("logs/\(provider.rawValue)-launchd.log").path,
            "StandardErrorPath": store.root.appendingPathComponent("logs/\(provider.rawValue)-launchd.log").path
        ]
        return try PropertyListSerialization.data(fromPropertyList: dictionary, format: .xml, options: 0)
    }
    func checked(_ arguments: [String]) throws {
        let result = try command("/bin/launchctl", arguments)
        guard result.code == 0 else { throw SchedulerError.message("launchctl \(arguments.first ?? ""): \(result.output) (exit \(result.code))") }
    }
    func apply(_ provider: Provider, config: Configuration) throws {
        // Disabling must remain possible even after a CLI has been removed.
        if config.enabled { try config.validate() }
        var settings = try store.load()
        let oldData = try FileManager.default.fileExists(atPath: plist(provider).path) ? Data(contentsOf: plist(provider)) : nil
        let wasLoaded = try loaded(provider)
        guard !wasLoaded || oldData != nil else { throw SchedulerError.message("The loaded job has no plist to restore. Restore its original plist before replacing this job.") }
        let oldRunner = try FileManager.default.fileExists(atPath: runner(provider).path) ? Data(contentsOf: runner(provider)) : nil
        try store.prepare()
        try FileManager.default.createDirectory(at: agents, withIntermediateDirectories: true)
        if let oldData { try oldData.write(to: store.root.appendingPathComponent("backups/\(provider.label)-\(UUID().uuidString).plist"), options: .atomic) }
        do {
            if wasLoaded { try checked(["bootout", "\(domain)/\(provider.label)"]) }
            try prepareRunner(provider)
            if config.enabled {
                try data(provider, config).write(to: plist(provider), options: .atomic)
                try checked(["bootstrap", domain, plist(provider).path])
            } else if FileManager.default.fileExists(atPath: plist(provider).path) { try FileManager.default.removeItem(at: plist(provider)) }
            guard try loaded(provider) == config.enabled else { throw SchedulerError.message("Installed job state did not match the requested state") }
            settings.providers[provider.rawValue] = config
            try store.save(settings)
        } catch {
            let original = error.localizedDescription
            do {
                if try loaded(provider) { try checked(["bootout", "\(domain)/\(provider.label)"]) }
                if let oldRunner { try oldRunner.write(to: runner(provider), options: .atomic) }
                else if FileManager.default.fileExists(atPath: runner(provider).path) { try FileManager.default.removeItem(at: runner(provider)) }
                if let oldData { try oldData.write(to: plist(provider), options: .atomic) }
                else if FileManager.default.fileExists(atPath: plist(provider).path) { try FileManager.default.removeItem(at: plist(provider)) }
                if wasLoaded { try checked(["bootstrap", domain, plist(provider).path]) }
            } catch { throw SchedulerError.message("\(original)\nRollback also failed: \(error.localizedDescription)") }
            throw SchedulerError.message("\(original)\nPrevious schedule restored.")
        }
    }
    func run(_ provider: Provider, config: Configuration) throws -> CommandResult {
        try config.validate(); try prepareRunner(provider)
        return try command("/bin/bash", [runner(provider).path, provider.rawValue, config.executable, store.root.path])
    }
}
