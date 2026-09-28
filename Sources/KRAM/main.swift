import Foundation
import KRAMCore

func getSkippedFiles(in dir: URL, recursive: Bool) -> [SkippedFileInfo] {
    let fm = FileManager.default
    var skipped: [SkippedFileInfo] = []
    let categoryNames: Set<String> = Set(FileCategory.allCases.map { $0.rawValue })

    guard let contents = try? fm.contentsOfDirectory(
        at: dir,
        includingPropertiesForKeys: [.isHiddenKey, .isDirectoryKey],
        options: []
    ) else {
        return []
    }

    for item in contents {
        let name = item.lastPathComponent
        let vals = try? item.resourceValues(forKeys: [.isHiddenKey, .isDirectoryKey])
        let isDir = vals?.isDirectory ?? false
        let isHidden = vals?.isHidden ?? false || name.hasPrefix(".")

        if isHidden {
            skipped.append(SkippedFileInfo(name: name, reason: "hidden file"))
        } else if isDir && categoryNames.contains(name) {
            if let innerFiles = try? fm.contentsOfDirectory(at: item, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) {
                for inner in innerFiles {
                    skipped.append(SkippedFileInfo(name: inner.lastPathComponent, reason: "already in \(name)/"))
                }
            }
        }
    }
    return skipped
}

// MARK: - Main Execution

let rawArgs = Array(CommandLine.arguments.dropFirst())
var parsed = ArgumentParser.parse(rawArgs)

// 1. Unknown command handling
if let unknown = parsed.unknownCommand {
    UI.printUnknownCommand(unknown)
    exit(1)
}

// 2. Help and Version
if parsed.showHelp {
    UI.printHelp()
    exit(0)
}

if parsed.showVersion {
    print("kram 2.0.0")
    exit(0)
}

// 3. Stats and Last Transaction
if parsed.showStats {
    let stats = StatsManager.shared.load()
    UI.printStats(stats)
    exit(0)
}

if parsed.showLast {
    let tx = try? TransactionManager().loadLatest()
    UI.printLastTransaction(tx)
    exit(0)
}

// 3b. Completion
if parsed.showCompletion {
    let shell = parsed.completionShell ?? {
        if let envShell = ProcessInfo.processInfo.environment["SHELL"] {
            if envShell.hasSuffix("bash") { return "bash" }
            if envShell.hasSuffix("fish") { return "fish" }
        }
        return "zsh"
    }()
    print(Completion.generate(shell: shell))
    exit(0)
}

// 4. Conflicting flags (-n and -a)
if parsed.conflictingFlags {
    UI.printFlagConflict()
}

// 5. Undo mode
if parsed.undo {
    let txManager = TransactionManager()
    guard let latest = try? txManager.loadLatest(for: parsed.targetURL) else {
        UI.printWarning("No transaction found to undo.")
        exit(0)
    }

    let boundary = parsed.targetURL ?? latest.rootDirectory
    UI.printUndoHeader(appliedAt: latest.appliedAt, count: latest.operations.count)

    do {
        let count = try txManager.undo(boundary: boundary, verbose: true)
        UI.printUndoSummary(restoredCount: count)
    } catch KRAMError.noTransactionToUndo {
        UI.printWarning("No transaction found for this directory.")
        exit(0)
    } catch {
        UI.printError("Undo failed: \(error.localizedDescription)")
        exit(1)
    }
    exit(0)
}

// 5b. Watch Mode
if parsed.watch {
    guard let target = parsed.targetURL else {
        UI.printError("Error: kr watch requires a directory — e.g. `kr watch dl` or `kr watch ~/Downloads`.")
        exit(1)
    }
    var watchIsDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: target.path, isDirectory: &watchIsDir), watchIsDir.boolValue else {
        UI.printError("Not a directory: \(target.path)")
        exit(1)
    }
    WatchMode.run(directory: target)
    exit(0)
}

// 6. Interactive Mode when no arguments are provided
if CommandLine.arguments.count == 1 {
    if let picked = DirectoryPicker.pickDirectory() {
        parsed.targetURL = picked
        parsed.dryRun = true
    } else {
        exit(0)
    }
}

// 7. Verify Target Directory
guard let targetURL = parsed.targetURL else {
    UI.printError("Error: No directory specified.")
    UI.printHelp()
    exit(1)
}

var isDir: ObjCBool = false
guard FileManager.default.fileExists(atPath: targetURL.path, isDirectory: &isDir), isDir.boolValue else {
    UI.printError("Not a directory: \(targetURL.path)")
    exit(1)
}

// 8. Scan Directory
// The bundled local CoreML classifier is always active. Its deterministic
// extension classifier remains the fallback if the model is unavailable.
let classifier: FileClassifier = LayaClassifier()
let scanner = FileScanner(classifier: classifier)
let planner = OperationPlanner()

var files: [ScannedFile]
do {
    files = try scanner.scan(directory: targetURL, recursive: parsed.recursive)
} catch {
    UI.printError("Error: \(error.localizedDescription)")
    exit(1)
}

let operations = planner.plan(files: files, boundary: targetURL)
let skipped = getSkippedFiles(in: targetURL, recursive: parsed.recursive)

// 9. Preview
UI.printDryRunPreview(
    targetURL: targetURL,
    scannedCount: files.count,
    operations: operations,
    skippedFiles: skipped,
    isVerbose: parsed.verbose,
    isCurrentDir: parsed.isCurrentDir,
    showApplyHint: parsed.dryRun
)

// 10. Decide whether to proceed to apply
//   - --dry-run/-n → exit after preview (never prompt, never apply)
//   - no operations → exit (nothing to do)
//   - otherwise → prompt, or auto-apply if --yes
if parsed.dryRun {
    exit(0)
}

if operations.isEmpty {
    exit(0)
}

if !parsed.yes {
    let confirmed = UI.promptApplyConfirmation(targetURL: targetURL, count: operations.count)
    guard confirmed else {
        exit(0)
    }
}

// 11. Apply Changes
UI.printLiveMoveHeader()
let mover = FileMover()
var succeededOps: [PlannedOperation] = []
var skippedCount = 0
var failedCount = 0

for op in operations {
    let result = mover.apply(operations: [op], boundary: targetURL, verbose: false)
    if let succ = result.succeeded.first {
        succeededOps.append(succ)
        UI.printMoveSuccess(sourceName: succ.sourceURL.lastPathComponent, category: succ.category)
    } else if let (_, err) = result.skipped.first {
        if err is SafetyViolation {
            failedCount += 1
            UI.printMoveFailure(sourceName: op.sourceURL.lastPathComponent, reason: "safety violation")
        } else {
            skippedCount += 1
            UI.printMoveWarning(sourceName: op.sourceURL.lastPathComponent, reason: err.localizedDescription)
        }
    }
}

if !succeededOps.isEmpty {
    let transaction = Transaction(rootDirectory: targetURL, operations: succeededOps)
    let txManager = TransactionManager()
    try? txManager.save(transaction: transaction)
}

UI.printMoveSummary(
    targetURL: targetURL,
    succeededCount: succeededOps.count,
    skippedCount: skippedCount,
    failedCount: failedCount
)

exit(0)
