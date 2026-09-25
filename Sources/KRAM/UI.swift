import Foundation
import KRAMCore

public struct SkippedFileInfo {
    public let name: String
    public let reason: String

    public init(name: String, reason: String) {
        self.name = name
        self.reason = reason
    }
}

public final class UI {
    public static let divider = String(repeating: "━", count: 46)
    public static let thinDivider = String(repeating: "─", count: 42)

    public static func printError(_ message: String) {
        fputs("\(ANSI.red)\(message)\(ANSI.reset)\n", stderr)
    }

    public static func printWarning(_ message: String) {
        print("\(ANSI.yellow)⚠  \(message)\(ANSI.reset)")
    }

    public static func printFlagConflict() {
        print("""
\(ANSI.yellow)⚠  Conflicting flags: -n (dry-run) and -a (apply)
   Defaulting to dry-run for safety.\(ANSI.reset)
""")
    }

    public static func printUnknownCommand(_ cmd: String) {
        print("""
\(ANSI.yellow)⚠  Unknown command: \(cmd)\(ANSI.reset)

Did you mean one of these?
  \(ANSI.cyan)kr dl\(ANSI.reset)         → ~/Downloads
  \(ANSI.cyan)kr desk\(ANSI.reset)       → ~/Desktop
  \(ANSI.cyan)kr docs\(ANSI.reset)       → ~/Documents
  \(ANSI.cyan)kr here\(ANSI.reset)       → current directory

Run  \(ANSI.bold)kr help\(ANSI.reset)  to see all commands.
""")
    }

    public static func formatDisplayPath(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = url.standardizedFileURL.path
        if path == home { return "~" }
        if path.hasPrefix(home + "/") {
            return path.replacingOccurrences(of: home, with: "~")
        }
        return path
    }

    public static func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMM yyyy · h:mm a"
        return formatter.string(from: date)
    }

    public static func freeDiskSpace() -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        if let values = try? home.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let bytes = values.volumeAvailableCapacityForImportantUsage {
            let gb = Double(bytes) / 1_000_000_000.0
            return String(format: "%.1f GB", gb)
        }
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: home.path),
           let freeBytes = attrs[.systemFreeSize] as? NSNumber {
            let gb = freeBytes.doubleValue / 1_000_000_000.0
            return String(format: "%.1f GB", gb)
        }
        return "N/A"
    }

    // MARK: - Dry Run Preview

    public static func printDryRunPreview(
        targetURL: URL,
        scannedCount: Int,
        operations: [PlannedOperation],
        skippedFiles: [SkippedFileInfo],
        isVerbose: Bool,
        isCurrentDir: Bool = false
    ) {
        let displayPath = formatDisplayPath(targetURL) + (isCurrentDir ? "  (current)" : "")
        print("\n🐭 \(ANSI.bold)KRAM — Dry Run Preview\(ANSI.reset)")
        print(divider)
        print("Directory:   \(ANSI.cyan)\(displayPath)\(ANSI.reset)")
        print("Scanned:     \(scannedCount) files")
        print("To move:     \(operations.count) files")
        print("Skipped:     \(skippedFiles.count) files")
        print(divider)
        print()

        // Group operations by category
        var grouped: [String: [PlannedOperation]] = [:]
        for op in operations {
            grouped[op.category, default: []].append(op)
        }

        for category in FileCategory.allCases {
            guard let ops = grouped[category.rawValue], !ops.isEmpty else { continue }
            let countStr = ops.count == 1 ? "1 file" : "\(ops.count) files"
            let catHeader = "\(category.icon) \(category.rawValue)".padding(toLength: 35, withPad: " ", startingAt: 0)
            print("➤ \(catHeader)\(ANSI.gray)\(countStr)\(ANSI.reset)")

            for op in ops {
                let destName = op.destinationURL.lastPathComponent
                let srcName = op.sourceURL.lastPathComponent
                let padded = destName.padding(toLength: 30, withPad: " ", startingAt: 0)
                print("    \(padded)← \(ANSI.gray)\(srcName)\(ANSI.reset)")
            }
            print()
        }

        if isVerbose && !skippedFiles.isEmpty {
            print("➤ \(ANSI.bold)Skipped Files\(ANSI.reset)")
            for skipped in skippedFiles {
                let padded = skipped.name.padding(toLength: 30, withPad: " ", startingAt: 0)
                print("  \(ANSI.gray)◎  \(padded)→  skipped (\(skipped.reason))\(ANSI.reset)")
            }
            print()
        }

        if operations.isEmpty {
            print("  \(ANSI.gray)Nothing to organize. Everything looks good.\(ANSI.reset)")
        }

        print(divider)
        if !operations.isEmpty {
            let cmdPath = formatDisplayPath(targetURL)
            print("Run  \(ANSI.cyan)kram \(cmdPath) --apply\(ANSI.reset)  to execute.\n")
        } else {
            print()
        }
    }

    // MARK: - Ready to Apply

    public static func promptApplyConfirmation(targetURL: URL, count: Int) -> Bool {
        let displayPath = formatDisplayPath(targetURL)
        print("\n🐭 \(ANSI.bold)KRAM — Ready to Apply\(ANSI.reset)")
        print(divider)
        print("  \(count) files will be moved inside \(ANSI.cyan)\(displayPath)\(ANSI.reset)")
        print("  Undo anytime:  \(ANSI.cyan)kram \(displayPath) --undo\(ANSI.reset)")
        print(divider)
        print()
        print("Proceed? [y/N]: ", terminator: "")
        fflush(stdout)

        guard let answer = readLine(), answer.trimmingCharacters(in: .whitespaces).lowercased() == "y" else {
            print("\(ANSI.gray)Cancelled.\(ANSI.reset)\n")
            return false
        }
        return true
    }

    // MARK: - Live Move Progress

    public static func printLiveMoveHeader() {
        print("\n➤ \(ANSI.bold)Moving files\(ANSI.reset)\n")
    }

    public static func printMoveSuccess(sourceName: String, category: String) {
        let padded = sourceName.padding(toLength: 30, withPad: " ", startingAt: 0)
        print("  \(ANSI.green)✓\(ANSI.reset)  \(padded)→  \(category)/")
    }

    public static func printMoveWarning(sourceName: String, reason: String) {
        let padded = sourceName.padding(toLength: 30, withPad: " ", startingAt: 0)
        print("  \(ANSI.yellow)⚠\(ANSI.reset)  \(padded)→  skipped (\(reason))")
    }

    public static func printMoveFailure(sourceName: String, reason: String) {
        let padded = sourceName.padding(toLength: 30, withPad: " ", startingAt: 0)
        print("  \(ANSI.red)✗\(ANSI.reset)  \(padded)→  blocked (\(reason))")
    }

    public static func printMoveSummary(
        targetURL: URL,
        succeededCount: Int,
        skippedCount: Int,
        failedCount: Int
    ) {
        let displayPath = formatDisplayPath(targetURL)
        print()
        print(divider)
        print("\(ANSI.green)✓ Done\(ANSI.reset)   \(succeededCount) moved · \(skippedCount) skipped · \(failedCount) failed")
        print("  Free space: \(freeDiskSpace())")
        print("  Undo:  \(ANSI.cyan)kram \(displayPath) --undo\(ANSI.reset)")
        print(divider)
        print()
    }

    // MARK: - Undo

    public static func printUndoHeader(appliedAt: Date, count: Int) {
        print("\n🐭 \(ANSI.bold)KRAM — Undo\(ANSI.reset)")
        print(divider)
        print("Transaction:   \(formatDate(appliedAt))")
        print("Files:         \(count) to restore")
        print(divider)
        print()
    }

    public static func printUndoSuccess(fileName: String, category: String) {
        let padded = fileName.padding(toLength: 30, withPad: " ", startingAt: 0)
        print("  \(ANSI.green)✓\(ANSI.reset)  \(padded)←  \(category)/")
    }

    public static func printUndoSummary(restoredCount: Int) {
        print()
        print(divider)
        print("\(ANSI.green)✓ Undo complete\(ANSI.reset)   \(restoredCount) files restored")
        print(divider)
        print()
    }

    // MARK: - Last Transaction

    public static func printLastTransaction(_ transaction: Transaction?) {
        print("\n🐭 \(ANSI.bold)KRAM — Last Transaction\(ANSI.reset)")
        print(divider)
        guard let tx = transaction, !tx.operations.isEmpty else {
            print("  \(ANSI.yellow)No transaction found.\(ANSI.reset)")
            print(divider)
            print()
            return
        }

        let displayPath = formatDisplayPath(tx.rootDirectory)
        print("Directory:   \(ANSI.cyan)\(displayPath)\(ANSI.reset)")
        print("Applied:     \(formatDate(tx.appliedAt))")
        print("Files moved: \(tx.operations.count)")
        print()

        var grouped: [String: Int] = [:]
        for op in tx.operations {
            grouped[op.category, default: 0] += 1
        }

        for category in FileCategory.allCases {
            guard let count = grouped[category.rawValue], count > 0 else { continue }
            let countStr = count == 1 ? "1 file" : "\(count) files"
            let catHeader = "\(category.icon) \(category.rawValue)".padding(toLength: 20, withPad: " ", startingAt: 0)
            print("  \(catHeader)\(countStr)")
        }

        print()
        print(divider)
        print("Undo:  \(ANSI.cyan)kr dl -u\(ANSI.reset)   or   \(ANSI.cyan)kram \(displayPath) --undo\(ANSI.reset)")
        print(divider)
        print()
    }

    // MARK: - Stats

    public static func printStats(_ stats: KRAMStats) {
        print("\n🐭 \(ANSI.bold)KRAM — Stats\(ANSI.reset)")
        print(divider)
        print("Total runs:       \(stats.totalRuns)")
        print("Files organized:  \(stats.totalFilesMoved)")
        if let lastRun = stats.lastRunAt {
            print("Last run:         \(formatDate(lastRun))")
        } else {
            print("Last run:         Never")
        }
        print("Most used dir:    \(stats.mostUsedDirectory.isEmpty ? "None" : stats.mostUsedDirectory)")
        print()

        if !stats.categoryTotals.isEmpty {
            print("Top categories:")
            let sortedCats = stats.categoryTotals.sorted { $0.value > $1.value }
            for (catName, count) in sortedCats.prefix(5) {
                let catEnum = FileCategory(rawValue: catName)
                let icon = catEnum?.icon ?? "📁"
                let countStr = count == 1 ? "1 file" : "\(count) files"
                let line = "  \(icon) \(catName)".padding(toLength: 22, withPad: " ", startingAt: 0)
                print("\(line)\(countStr)")
            }
        }
        print(divider)
        print()
    }

    // MARK: - Help

    public static func printHelp() {
        print("""
🐭 \(ANSI.bold)KRAM 1.5.0 — Keep. Rearrange. Automate. Manage.\(ANSI.reset)

\(ANSI.bold)QUICK COMMANDS\(ANSI.reset)
  \(ANSI.cyan)kr dl\(ANSI.reset)                   Dry-run on ~/Downloads
  \(ANSI.cyan)kr dl -a\(ANSI.reset)                Organize ~/Downloads
  \(ANSI.cyan)kr dl -u\(ANSI.reset)                Undo last Downloads operation
  \(ANSI.cyan)kr desk -a\(ANSI.reset)              Organize ~/Desktop
  \(ANSI.cyan)kr docs -a\(ANSI.reset)              Organize ~/Documents
  \(ANSI.cyan)kr here -a\(ANSI.reset)              Organize current folder
  \(ANSI.cyan)kr last\(ANSI.reset)                 Show last transaction
  \(ANSI.cyan)kr stats\(ANSI.reset)                Show lifetime stats

\(ANSI.bold)FULL USAGE\(ANSI.reset)
  \(ANSI.cyan)kr <directory>\(ANSI.reset)          Dry-run preview (default, safe)
  \(ANSI.cyan)kr <directory> -a\(ANSI.reset)       Apply changes
  \(ANSI.cyan)kr <directory> -r\(ANSI.reset)       Include subdirectories
  \(ANSI.cyan)kr <directory> -ar\(ANSI.reset)      Apply + recursive
  \(ANSI.cyan)kr <directory> -u\(ANSI.reset)       Undo last transaction
  \(ANSI.cyan)kr <directory> -v\(ANSI.reset)       Verbose (show skipped files)
  \(ANSI.cyan)kr <directory> -n\(ANSI.reset)       Explicit dry-run

\(ANSI.bold)LONG FLAGS\(ANSI.reset) (also work)
  --apply  --recursive  --undo  --verbose  --dry-run
  --help   --version

\(ANSI.bold)ALIASES\(ANSI.reset)
  kr = kram
  dl   → ~/Downloads
  desk → ~/Desktop
  docs → ~/Documents
  here → current directory (pwd)

\(ANSI.bold)SAFETY\(ANSI.reset)
  Dry-run is always default. Use -a to make real changes.
  KRAM never touches files outside your chosen directory.
  Every change is undoable with -u.
""")
    }
}
