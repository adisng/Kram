import Foundation
import KRAMCore

/// Runs the foreground `kr watch <directory>` loop.
/// On each debounced filesystem change, runs the identical
/// scan → plan → apply → save-transaction pipeline that
/// `kr <dir> -a` uses in main.swift.
public enum WatchMode {

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
