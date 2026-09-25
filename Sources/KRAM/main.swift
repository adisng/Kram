import Foundation
import KRAMCore

// MARK: - Version

let KRAM_VERSION = "1.0.0"

// MARK: - Help

func printHelp() {
    print("""
\(ANSI.bold)KRAM \(KRAM_VERSION) — Keep. Rearrange. Automate. Manage.\(ANSI.reset)

\(ANSI.bold)USAGE:\(ANSI.reset)
  kram <directory>                    Dry-run: preview what would change
  kram <directory> --apply            Apply changes (asks for confirmation)
  kram <directory> --recursive        Include subdirectories
  kram <directory> --undo             Reverse the last transaction
  kram <directory> --verbose          Show all files including skipped
  kram --version                      Show version
  kram --help                         Show this help

\(ANSI.bold)EXAMPLES:\(ANSI.reset)
  kram ~/Downloads
  kram ~/Downloads --apply
  kram ~/Downloads --apply --recursive
  kram ~/Downloads --undo

\(ANSI.bold)SAFETY:\(ANSI.reset)
  KRAM only modifies files inside the directory you give it.
  It never touches system files, hidden files, or files outside the boundary.
  Dry-run is always the default. Use --apply to make real changes.
  Every applied change can be undone with --undo.
""")
}

// MARK: - Parse Arguments

var args = CommandLine.arguments.dropFirst() // drop executable name
var targetPath: String? = nil
var applyFlag     = false
var recursiveFlag = false
var undoFlag      = false
var verboseFlag   = false

for arg in args {
    switch arg {
    case "--apply":     applyFlag = true
    case "--recursive": recursiveFlag = true
    case "--undo":      undoFlag = true
    case "--verbose":   verboseFlag = true
    case "--version":
        print("kram \(KRAM_VERSION)")
        exit(0)
    case "--help", "-h":
        printHelp()
        exit(0)
    default:
        if arg.hasPrefix("--") {
            print("\(ANSI.red)Unknown flag: \(arg)\(ANSI.reset)")
            printHelp()
            exit(1)
        } else {
            targetPath = arg
        }
    }
}

guard let rawPath = targetPath else {
    print("\(ANSI.red)Error: No directory specified.\(ANSI.reset)")
    printHelp()
    exit(1)
}

// MARK: - Resolve Directory

let fm = FileManager.default
let expandedPath = (rawPath as NSString).expandingTildeInPath
let targetURL = URL(fileURLWithPath: expandedPath).standardizedFileURL

// MARK: - Undo Mode

if undoFlag {
    let divider = String(repeating: "━", count: 42)
    print("\n\(ANSI.bold)KRAM — Undo\(ANSI.reset)")
    print(divider)

    let txManager = TransactionManager()
    do {
        let count = try txManager.undo(boundary: targetURL, verbose: true)
        print(divider)
        if count > 0 {
            print("\(ANSI.green)Undo complete. \(count) file(s) restored.\(ANSI.reset)\n")
        } else {
            print("\(ANSI.yellow)Nothing to restore.\(ANSI.reset)\n")
        }
    } catch KRAMError.noTransactionToUndo {
        print("\(ANSI.yellow)No transaction found for this directory.\(ANSI.reset)\n")
        exit(0)
    } catch {
        print("\(ANSI.red)Undo failed: \(error.localizedDescription)\(ANSI.reset)\n")
        exit(1)
    }
    exit(0)
}

// MARK: - Scan

let scanner    = FileScanner()
let planner    = OperationPlanner()
let divider    = String(repeating: "━", count: 42)

var files: [ScannedFile]
do {
    files = try scanner.scan(directory: targetURL, recursive: recursiveFlag)
} catch {
    print("\(ANSI.red)Error: \(error.localizedDescription)\(ANSI.reset)")
    exit(1)
}

let operations = planner.plan(files: files, boundary: targetURL)

// MARK: - Preview

let displayPath = rawPath.hasPrefix(fm.homeDirectoryForCurrentUser.path)
    ? rawPath.replacingOccurrences(of: fm.homeDirectoryForCurrentUser.path, with: "~")
    : rawPath

print()
if applyFlag {
    print("\(ANSI.bold)KRAM — Ready to Apply\(ANSI.reset)")
} else {
    print("\(ANSI.bold)KRAM — Dry Run Preview\(ANSI.reset)")
}
print(divider)
print("Directory:  \(ANSI.cyan)\(displayPath)\(ANSI.reset)")
print("Files:      \(files.count) scanned, \(operations.count) to move")
if recursiveFlag { print("Mode:       recursive") }
print(divider)
print()

// Group by category for display
var grouped: [String: [PlannedOperation]] = [:]
for op in operations {
    grouped[op.category, default: []].append(op)
}

for category in FileCategory.allCases {
    guard let ops = grouped[category.rawValue], !ops.isEmpty else { continue }
    print("  \(category.icon)  \(ANSI.bold)\(category.rawValue)/\(ANSI.reset)")
    for op in ops {
        let dest = op.destinationURL.lastPathComponent
        let src  = op.sourceURL.lastPathComponent
        if dest == src {
            print("      \(ANSI.gray)\(src)\(ANSI.reset)")
        } else {
            print("      \(dest)  \(ANSI.gray)← \(src)\(ANSI.reset)")
        }
    }
    print()
}

if operations.isEmpty {
    print("  \(ANSI.gray)Nothing to organize. Everything looks good.\(ANSI.reset)\n")
    exit(0)
}

print(divider)

// MARK: - Dry Run Exit

if !applyFlag {
    print("\(ANSI.gray)Run with \(ANSI.reset)\(ANSI.bold)--apply\(ANSI.reset)\(ANSI.gray) to execute these changes.\(ANSI.reset)\n")
    exit(0)
}

// MARK: - Confirmation

print("\(ANSI.bold)\(operations.count) file(s) will be moved inside \(displayPath)\(ANSI.reset)")
print("This can be undone with: \(ANSI.cyan)kram \(displayPath) --undo\(ANSI.reset)")
print()
print("Proceed? [y/N]: ", terminator: "")

guard let answer = readLine(), answer.lowercased() == "y" else {
    print("\(ANSI.gray)Cancelled.\(ANSI.reset)\n")
    exit(0)
}

// MARK: - Apply

print()
let mover = FileMover()
let result = mover.apply(operations: operations, boundary: targetURL, verbose: true)

// MARK: - Record Transaction

if !result.succeeded.isEmpty {
    let transaction = Transaction(
        rootDirectory: targetURL,
        operations: result.succeeded
    )
    let txManager = TransactionManager()
    try? txManager.save(transaction: transaction)
}

// MARK: - Summary

print()
print(divider)
let skippedCount = result.skipped.count
print("\(ANSI.green)\(ANSI.bold)Done.\(ANSI.reset) \(result.succeeded.count) moved", terminator: "")
if skippedCount > 0 {
    print(", \(ANSI.yellow)\(skippedCount) skipped\(ANSI.reset)", terminator: "")
}
print()
if !result.succeeded.isEmpty {
    print("To undo: \(ANSI.cyan)kram \(displayPath) --undo\(ANSI.reset)")
}
print()
