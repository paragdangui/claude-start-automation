import Foundation
struct CommandResult { let code: Int32; let output: String }
struct ProcessRunner {
    static func run(_ executable: String, _ arguments: [String]) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        // A temporary file avoids pipe-buffer deadlocks for verbose commands.
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        defer { try? FileManager.default.removeItem(at: url) }
        let handle = try FileHandle(forWritingTo: url)
        defer { try? handle.close() }
        process.standardOutput = handle; process.standardError = handle
        try process.run(); process.waitUntilExit()
        return CommandResult(code: process.terminationStatus, output: String(decoding: try Data(contentsOf: url), as: UTF8.self))
    }
}
