import Foundation

public enum SpecialCommand {
    case here, last, stats, undo, dl, desk, docs, help, version
}

public struct KRAMArguments {
    public var targetURL: URL?
    public var apply: Bool = false
    public var recursive: Bool = false
    public var undo: Bool = false
    public var verbose: Bool = false
    public var dryRun: Bool = false
    public var showHelp: Bool = false
    public var showVersion: Bool = false
    public var showLast: Bool = false
    public var showStats: Bool = false
    public var command: SpecialCommand?
    public var unknownCommand: String?
    public var conflictingFlags: Bool = false
    public var isCurrentDir: Bool = false

    public init() {}
}

public final class ArgumentParser {

    public static func resolveTarget(_ arg: String) -> URL? {
        let home = FileManager.default.homeDirectoryForCurrentUser
        switch arg.lowercased() {
        case "dl":
            return home.appendingPathComponent("Downloads")
        case "desk":
            return home.appendingPathComponent("Desktop")
        case "docs":
            return home.appendingPathComponent("Documents")
        case "here":
            return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        default:
            return nil
        }
    }

    public static func parse(_ rawArgs: [String]) -> KRAMArguments {
        var result = KRAMArguments()
        var nonFlagArgs: [String] = []

        for arg in rawArgs {
            if arg == "--apply" {
                result.apply = true
            } else if arg == "--recursive" {
                result.recursive = true
            } else if arg == "--undo" {
                result.undo = true
            } else if arg == "--verbose" {
                result.verbose = true
            } else if arg == "--dry-run" {
                result.dryRun = true
            } else if arg == "--help" || arg == "-h" {
                result.showHelp = true
            } else if arg == "--version" {
                result.showVersion = true
            } else if arg.hasPrefix("--") {
                result.unknownCommand = arg
            } else if arg.hasPrefix("-") && arg.count > 1 {
                // Parse combined short flags like -ar, -arv, -na
                var hasA = false
                var hasN = false
                for char in arg.dropFirst() {
                    switch char {
                    case "a": hasA = true
                    case "r": result.recursive = true
                    case "v": result.verbose = true
                    case "u": result.undo = true
                    case "n": hasN = true
                    default:
                        result.unknownCommand = "-\(char)"
                    }
                }
                if hasA && hasN {
                    result.conflictingFlags = true
                    result.dryRun = true
                    result.apply = false
                } else if hasN {
                    result.dryRun = true
                } else if hasA {
                    result.apply = true
                }
            } else {
                nonFlagArgs.append(arg)
            }
        }

        // Process non-flag arguments
        for (index, arg) in nonFlagArgs.enumerated() {
            let lower = arg.lowercased()
            if index == 0 {
                switch lower {
                case "last":
                    result.showLast = true
                    result.command = .last
                    continue
                case "stats":
                    result.showStats = true
                    result.command = .stats
                    continue
                case "help":
                    result.showHelp = true
                    result.command = .help
                    continue
                case "version":
                    result.showVersion = true
                    result.command = .version
                    continue
                case "undo":
                    result.undo = true
                    result.command = .undo
                    continue
                case "dl":
                    result.targetURL = resolveTarget("dl")
                    result.command = .dl
                    continue
                case "desk":
                    result.targetURL = resolveTarget("desk")
                    result.command = .desk
                    continue
                case "docs":
                    result.targetURL = resolveTarget("docs")
                    result.command = .docs
                    continue
                case "here":
                    result.targetURL = resolveTarget("here")
                    result.command = .here
                    result.isCurrentDir = true
                    continue
                default:
                    break
                }
            }

            // Check if it's a directory path
            let expandedPath = (arg as NSString).expandingTildeInPath
            let url = URL(fileURLWithPath: expandedPath).standardizedFileURL
            var isDir: ObjCBool = false

            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                result.targetURL = url
                if url.path == FileManager.default.currentDirectoryPath {
                    result.isCurrentDir = true
                }
            } else if FileManager.default.fileExists(atPath: url.path) {
                // Exists but not a directory
                result.targetURL = url
            } else {
                // Not found or unknown command
                if result.unknownCommand == nil {
                    result.unknownCommand = arg
                }
            }
        }

        return result
    }
}
