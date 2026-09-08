import Foundation

@main struct CoreTests {
    static func main() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Greeting core tests \(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = SettingsStore(root: root.appendingPathComponent("support"))
        let resource = URL(fileURLWithPath: CommandLine.arguments[1])
        var manager = LaunchAgentManager(store: store, agents: root.appendingPathComponent("agents"), resource: resource)
        var loaded: Set<String> = []
        var bootstraps = 0
        var bootstrapFailures = 0
        manager.command = { _, args in
            let label = args.last!.components(separatedBy: "/").last!.replacingOccurrences(of: ".plist", with: "")
            switch args[0] {
            case "print": return CommandResult(code: loaded.contains(label) ? 0 : 113, output: "")
            case "bootout": loaded.remove(label)
            case "bootstrap":
                bootstraps += 1
                if bootstrapFailures > 0 { bootstrapFailures -= 1; return CommandResult(code: 5, output: "Injected failure") }
                loaded.insert(label)
            default: fatalError("Unexpected command")
            }
            return CommandResult(code: 0, output: "")
        }
        let config = Configuration(executable: "/usr/bin/true", hour: 8, minute: 30)
        try manager.apply(.claude, config: config)
        assert(loaded == [Provider.claude.label])
        let old = try Data(contentsOf: manager.plist(.claude))
        let dict = try PropertyListSerialization.propertyList(from: old, format: nil) as! [String: Any]
        assert(dict["RunAtLoad"] as? Bool == false)
        assert((dict["StartCalendarInterval"] as! [[String: Int]]).count == 5)
        assert(tryValue { try manager.inspect(.claude, fallback: config).configuration } == config)
        try manager.apply(.codex, config: config)
        assert(loaded.count == 2)
        var changed = config; changed.hour = 10
        bootstrapFailures = 1
        do { try manager.apply(.claude, config: changed); fatalError("Expected rollback") }
        catch { assert(error.localizedDescription.contains("Previous schedule restored")) }
        assert(tryValue { try Data(contentsOf: manager.plist(.claude)) } == old)
        assert(tryValue { try store.load().providers["claude"] } == config)
        assert(loaded.count == 2)
        bootstrapFailures = 2
        do { try manager.apply(.claude, config: changed); fatalError("Expected rollback failure") }
        catch { assert(error.localizedDescription.contains("Rollback also failed")) }
        assert(tryValue { try store.load().providers["claude"] } == config)
        try manager.apply(.claude, config: config)
        var disabled = config; disabled.enabled = false; disabled.executable = "/missing/cli"
        try manager.apply(.claude, config: disabled)
        assert(!loaded.contains(Provider.claude.label) && loaded.contains(Provider.codex.label))
        assert(!FileManager.default.fileExists(atPath: manager.plist(.claude).path))
        do { var missing = config; missing.executable = "/missing/cli"; try manager.apply(.codex, config: missing); fatalError("Expected validation") } catch {}
        assert(loaded == [Provider.codex.label])
        var custom = dict; custom["StartInterval"] = 60
        try PropertyListSerialization.data(fromPropertyList: custom, format: .xml, options: 0).write(to: manager.plist(.codex))
        assert(tryValue { try manager.inspect(.codex, fallback: config).unsupported })
        print("Core checks passed: settings, plist generation, inspection, provider isolation, disabling missing CLI, validation, rollback (\(bootstraps) bootstraps).")
    }
    static func tryValue<T>(_ body: () throws -> T) -> T { try! body() }
}
