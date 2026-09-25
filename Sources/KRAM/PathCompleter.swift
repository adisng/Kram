import Foundation
import KRAMCore

public final class PathCompleter {

    public static func promptForPath() -> URL? {
        let originalTerm = Terminal.enableRawMode()
        Terminal.showCursor()
        defer {
            Terminal.restoreMode(originalTerm)
        }

        var input = "~/"
        var suggestions: [String] = []

        while true {
            suggestions = getSuggestions(for: input)
            render(input: input, suggestions: suggestions)

            let key = Terminal.readKey()
            switch key {
            case .enter:
                let expanded = (input as NSString).expandingTildeInPath
                let url = URL(fileURLWithPath: expanded).standardizedFileURL
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                    Terminal.clearScreen()
                    return url
                } else if !suggestions.isEmpty {
                    // Try the top suggestion if current input is partial
                    let top = (suggestions[0] as NSString).expandingTildeInPath
                    let topURL = URL(fileURLWithPath: top).standardizedFileURL
                    if FileManager.default.fileExists(atPath: topURL.path, isDirectory: &isDir) && isDir.boolValue {
                        Terminal.clearScreen()
                        return topURL
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
                return nil
            case .character(let c):
                input.append(c)
            case .quit:
                // Only treat q as quit if input is empty
                if input.isEmpty {
                    Terminal.clearScreen()
                    return nil
                } else {
                    input.append("q")
                }
            default:
                break
            }
        }
    }

    private static func render(input: String, suggestions: [String]) {
        Terminal.clearScreen()
        Terminal.moveTo(row: 1, col: 1)

        print("🐭 \(ANSI.bold)KRAM — Enter folder path\(ANSI.reset)")
        print(UI.divider)
        print()
        print("  Path: \(ANSI.cyan)\(input)\(ANSI.reset)█")
        print()

        if !suggestions.isEmpty {
            print("  \(ANSI.bold)Suggestions:\(ANSI.reset)")
            for (idx, suggestion) in suggestions.prefix(4).enumerated() {
                let pointer = idx == 0 ? "❯" : " "
                let color = idx == 0 ? ANSI.cyan : ANSI.gray
                print("  \(color)\(pointer) \(suggestion)\(ANSI.reset)")
            }
            print()
        } else {
            print("\n\n")
        }

        print(UI.thinDivider)
        print("  \(ANSI.gray)Tab to complete · Enter confirm · Esc cancel\(ANSI.reset)\n")
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
