import Foundation
import KRAMCore

public final class PathCompleter {

    public static func promptForPath() -> PickerResult {
        let originalTerm = Terminal.enableRawMode()
        Terminal.showCursor()
        defer {
            Terminal.restoreMode(originalTerm)
        }

        Terminal.clearScreen()

        var input = "~/"
        var suggestions: [String] = []

        while true {
            suggestions = getSuggestions(for: input)
            render(input: input, suggestions: suggestions)

            let key = Terminal.readKey()
            if key == .unknown && feof(stdin) != 0 {
                Terminal.clearScreen()
                return .cancelled
            }
            switch key {
            case .enter:
                let expanded = (input as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded).standardizedFileURL
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                    Terminal.clearScreen()
                    return .selected(url)
                } else if !suggestions.isEmpty {
                    // Try the top suggestion if current input is partial
                    let top = (suggestions[0] as NSString).expandingTildeInPath
                    let topURL = URL(fileURLWithPath: top).standardizedFileURL
                    if FileManager.default.fileExists(atPath: topURL.path, isDirectory: &isDir) && isDir.boolValue {
                        Terminal.clearScreen()
                        return .selected(topURL)
                    }
                }
            case .tab:
                if let first = suggestions.first {
                    input = first.hasSuffix("/") ? first : first + "/"
                }
            case .backspace:
                if !input.isEmpty {
                    input.removeLast()
                }
            case .escape:
                Terminal.clearScreen()
                return .back
            case .character(let c):
                input.append(c)
            case .quit:
                // Only treat q as quit if input is empty
                if input.isEmpty {
                    Terminal.clearScreen()
                    return .cancelled
                } else {
                    input.append("q")
                }
            default:
                break
            }
        }
    }

    private static func printLine(_ text: String = "") {
        print(text, terminator: "")
        Terminal.clearToEndOfLine()
        print()
    }

    private static func render(input: String, suggestions: [String]) {
        Terminal.moveTo(row: 1, col: 1)

        printLine("🐭 \(ANSI.bold)KRAM — Enter folder path\(ANSI.reset)")
        printLine(UI.divider)
        printLine()
        printLine("  Path: \(ANSI.cyan)\(input)\(ANSI.reset)█")
        printLine()

        if !suggestions.isEmpty {
            printLine("  \(ANSI.bold)Suggestions:\(ANSI.reset)")
            let count = min(suggestions.count, 4)
            for (idx, suggestion) in suggestions.prefix(4).enumerated() {
                let pointer = idx == 0 ? "❯" : " "
                let color = idx == 0 ? ANSI.cyan : ANSI.gray
                printLine("  \(color)\(pointer) \(suggestion)\(ANSI.reset)")
            }
            if count < 4 {
                for _ in count..<4 {
                    printLine()
                }
            }
            printLine()
        } else {
            for _ in 0..<6 {
                printLine()
            }
        }

        printLine(UI.thinDivider)
        printLine("  \(ANSI.gray)Tab to complete · Enter confirm · Esc back · q cancel\(ANSI.reset)")
        printLine()
        fflush(stdout)
    }

    private static func getSuggestions(for query: String) -> [String] {
        guard !query.isEmpty else { return [] }

        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let expanded = query.hasPrefix("~") ? query.replacingOccurrences(of: "~", with: home) : query

        var searchDir: URL
        var prefix: String

        if expanded.hasSuffix("/") {
            searchDir = URL(fileURLWithPath: expanded)
            prefix = ""
        } else {
            let url = URL(fileURLWithPath: expanded)
            searchDir = url.deletingLastPathComponent()
            prefix = url.lastPathComponent
        }

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: searchDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var matches: [String] = []
        for item in contents {
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) && isDir.boolValue {
                let name = item.lastPathComponent
                if prefix.isEmpty || name.lowercased().hasPrefix(prefix.lowercased()) {
                    var display = item.path
                    if display.hasPrefix(home) {
                        display = display.replacingOccurrences(of: home, with: "~")
                    }
                    matches.append(display)
                }
            }
        }

        return matches.sorted()
    }
}
