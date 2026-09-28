import Foundation
import KRAMCore

/// Runs the foreground `kr watch <directory>` loop.
/// On each debounced filesystem change, runs the identical
/// scan → plan → apply → save-transaction pipeline that
/// `kr <dir> -a` uses in main.swift.
public enum WatchMode {

    public static func install(target: URL) throws {
        guard !SafetyGuard.shared.isProtectedPath(target) else { throw SafetyViolation.protectedUserPath(path: target.path) }
        let slug = target.path.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let plist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/com.kram.watch.\(slug).plist")
        let logs = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/KRAM")
        try FileManager.default.createDirectory(at: plist.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: logs, withIntermediateDirectories: true)
        let executable = CommandLine.arguments[0]
        let xml = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>Label</key><string>com.kram.watch.\(slug)</string><key>ProgramArguments</key><array><string>\(executable)</string><string>watch</string><string>\(target.path)</string></array><key>RunAtLoad</key><true/><key>KeepAlive</key><true/><key>StandardOutPath</key><string>\(logs.appendingPathComponent("\(slug).log").path)</string><key>StandardErrorPath</key><string>\(logs.appendingPathComponent("\(slug).error.log").path)</string></dict></plist>
"""
        try xml.write(to: plist, atomically: true, encoding: .utf8)
        try launchctl(["bootstrap", "gui/\(getuid())", plist.path])
        print("Installed launch agent: \(plist.path)")
        print("Logs: \(logs.path)")
    }

    public static func uninstall(target: URL) throws {
        let slug = target.path.replacingOccurrences(of: "/", with: "-").trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let label = "com.kram.watch.\(slug)"
        let plist = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents/\(label).plist")
        try? launchctl(["bootout", "gui/\(getuid())", label])
        try? FileManager.default.removeItem(at: plist)
        print("Uninstalled launch agent: \(plist.path)")
    }

    private static func launchctl(_ args: [String]) throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: "/bin/launchctl"); process.arguments = args
        try process.run(); process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw KRAMError.operationFailed(source: "launchctl", reason: "command failed") }
    }

    // MARK: - Entry Point

    public static func run(directory: URL) {
        let displayPath = UI.formatDisplayPath(directory)
        UI.printWatchHeader(directory: directory)

        let watcher = DirectoryWatcher(directory: directory)

        let signalSource = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
        signal(SIGINT, SIG_IGN)
        signalSource.setEventHandler {
            watcher.stop()
            print("\n\(ANSI.gray)Stopped watching \(displayPath).\(ANSI.reset)")
            exit(0)
        }
        signalSource.resume()

        do {
            try watcher.start {
            organizeOnce(directory: directory, displayPath: displayPath)
            }
        } catch {
            signalSource.cancel()
            UI.printError("Unable to watch \(displayPath): \(error.localizedDescription)")
            return
        }

        // Block the main thread with a run loop so Ctrl-C signals are delivered
        // and FSEvents keeps firing. Signal handler calls exit(0) on SIGINT.
        RunLoop.main.run()
    }

    // MARK: - One Organize Cycle

    private static func organizeOnce(directory: URL, displayPath: String) {
        let scanner = FileScanner(classifier: ClassifierFactory.makeDefault(), recentFileThreshold: 5, requireStableFiles: true)
        let planner = OperationPlanner()
        let mover   = FileMover()

        guard let files = try? scanner.scan(directory: directory, recursive: false) else { return }

        let operations = planner.plan(files: files, boundary: directory)
        guard !operations.isEmpty else { return }   // nothing to do — stay silent

        var succeededOps: [PlannedOperation] = []

        for op in operations {
            let result = mover.apply(operations: [op], boundary: directory, verbose: false)
            if let succ = result.succeeded.first {
                succeededOps.append(succ)
            }
        }

        guard !succeededOps.isEmpty else { return }

        // Save transaction — identical to main.swift lines 191-195
        let transaction = Transaction(rootDirectory: directory, operations: succeededOps)
        let txManager   = TransactionManager()
        try? txManager.save(transaction: transaction)

        UI.printWatchBatch(succeededOps: succeededOps, timestamp: Date())
    }

}
