import Foundation

public struct CLIOption {
    public let name: String
    public let short: Character?
    public let description: String
    public let takesValue: Bool
}

public enum CLIOptions {
    public static let commands: [(String, String)] = [
        ("dl", "Organize ~/Downloads"), ("desk", "Organize ~/Desktop"),
        ("docs", "Organize ~/Documents"), ("here", "Organize current directory"),
        ("undo", "Undo a transaction"), ("history", "Show transaction history"),
        ("last", "Show the last transaction"), ("stats", "Show lifetime stats"),
        ("help", "Show help"), ("version", "Show version"),
        ("watch", "Watch a directory"), ("completion", "Generate completions")
    ]
    public static let options: [CLIOption] = [
        CLIOption(name: "--apply", short: "a", description: "Apply changes", takesValue: false),
        CLIOption(name: "--recursive", short: "r", description: "Include subdirectories", takesValue: false),
        CLIOption(name: "--undo", short: "u", description: "Undo a transaction", takesValue: false),
        CLIOption(name: "--verbose", short: "v", description: "Show skipped files", takesValue: false),
        CLIOption(name: "--dry-run", short: "n", description: "Preview only", takesValue: false),
        CLIOption(name: "--yes", short: nil, description: "Skip confirmation", takesValue: false),
        CLIOption(name: "--help", short: "h", description: "Show help", takesValue: false),
        CLIOption(name: "--version", short: nil, description: "Show version", takesValue: false),
        CLIOption(name: "--json", short: nil, description: "Output JSON", takesValue: false)
    ]
    public static var longNames: Set<String> { Set(options.map(\.name)) }
}
