import Foundation
import KRAMCore

public enum PickerResult {
    case selected(URL)
    case back
    case cancelled
}

public enum PickerRow {
    case quickPick(name: String, icon: String, url: URL, countText: String)
    case recent(path: String, url: URL, countText: String)
    case browse
    case typePath
}

public final class DirectoryPicker {

    public static func pickDirectory() -> URL? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Quick Picks
        let downloadsURL = home.appendingPathComponent("Downloads")
        let desktopURL = home.appendingPathComponent("Desktop")
        let documentsURL = home.appendingPathComponent("Documents")
        let currentURL = URL(fileURLWithPath: fm.currentDirectoryPath)

        let quickPickPaths: Set<String> = [
            downloadsURL.standardizedFileURL.path,
            desktopURL.standardizedFileURL.path,
            documentsURL.standardizedFileURL.path,
            currentURL.standardizedFileURL.path
        ]

        var rows: [PickerRow] = [
            .quickPick(name: "Downloads", icon: "📥", url: downloadsURL,
                       countText: FolderBrowser.countOrganizableFiles(in: downloadsURL)),
            .quickPick(name: "Desktop", icon: "🖥 ", url: desktopURL,
                       countText: FolderBrowser.countOrganizableFiles(in: desktopURL)),
            .quickPick(name: "Documents", icon: "📄", url: documentsURL,
                       countText: FolderBrowser.countOrganizableFiles(in: documentsURL)),
            .quickPick(name: "Current folder", icon: "📁", url: currentURL,
                       countText: FolderBrowser.countOrganizableFiles(in: currentURL))
        ]

        // Recent folders (deduplicated against quick picks)
        let recents = RecentsManager.shared.load()
        var validRecents: [PickerRow] = []

        for recent in recents {
            let expanded = recent.path.hasPrefix("~")
                ? recent.path.replacingOccurrences(of: "~", with: home.path)
                : recent.path
            let url = URL(fileURLWithPath: expanded).standardizedFileURL

            if !quickPickPaths.contains(url.path) {
                let countText = FolderBrowser.countOrganizableFiles(in: url)
                validRecents.append(.recent(path: recent.path, url: url, countText: countText))
            }
        }

        rows.append(contentsOf: validRecents)
        rows.append(.browse)
        rows.append(.typePath)

        var selectedIndex = 0

        let originalTerm = Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.showCursor()
            Terminal.restoreMode(originalTerm)
        }

        Terminal.clearScreen()

        while true {
            render(rows: rows, selectedIndex: selectedIndex, recentsCount: validRecents.count)

            let key = Terminal.readKey()
            if key == .unknown && feof(stdin) != 0 {
                Terminal.clearScreen()
                return nil
            }
            switch key {
            case .up:
                if selectedIndex > 0 { selectedIndex -= 1 }
            case .down:
                if selectedIndex < rows.count - 1 { selectedIndex += 1 }
            case .slash:
                // Jump to type-a-path
                let result = PathCompleter.promptForPath()
                switch result {
                case .selected(let url):
                    Terminal.clearScreen()
                    return url
                case .back:
                    Terminal.clearScreen()
                    Terminal.hideCursor()
                    continue
                case .cancelled:
                    Terminal.clearScreen()
                    return nil
                }
            case .enter:
                let row = rows[selectedIndex]
                switch row {
                case .quickPick(_, _, let url, _):
                    Terminal.clearScreen()
                    return url
                case .recent(_, let url, _):
                    Terminal.clearScreen()
                    return url
                case .browse:
                    let result = FolderBrowser.browse(startingAt: home)
                    switch result {
                    case .selected(let url):
                        Terminal.clearScreen()
                        return url
                    case .back:
                        Terminal.clearScreen()
                        Terminal.hideCursor()
                        continue
                    case .cancelled:
                        Terminal.clearScreen()
                        return nil
                    }
                case .typePath:
                    let result = PathCompleter.promptForPath()
                    switch result {
                    case .selected(let url):
                        Terminal.clearScreen()
                        return url
                    case .back:
                        Terminal.clearScreen()
                        Terminal.hideCursor()
                        continue
                    case .cancelled:
                        Terminal.clearScreen()
                        return nil
                    }
                }
            case .quit, .escape:
                Terminal.clearScreen()
                return nil
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

    private static func render(rows: [PickerRow], selectedIndex: Int, recentsCount: Int) {
        Terminal.moveTo(row: 1, col: 1)

        printLine("🐭 \(ANSI.bold)KRAM — Where do you want to organize?\(ANSI.reset)")
        printLine()
        printLine("  📍 \(ANSI.bold)Quick Picks\(ANSI.reset)")
        printLine("  \(UI.thinDivider)")

        var rowIndex = 0

        // Render Quick Picks (indices 0..<4)
        for _ in 0..<4 {
            let row = rows[rowIndex]
            let isSelected = (rowIndex == selectedIndex)
            let pointer = isSelected ? "❯" : " "
            if case let .quickPick(name, icon, url, countText) = row {
                let nameStr = "\(icon) \(name)".padding(toLength: 18, withPad: " ", startingAt: 0)
                let pathStr = UI.formatDisplayPath(url).padding(toLength: 22, withPad: " ", startingAt: 0)
                if isSelected {
                    printLine("  \(ANSI.bold)\(ANSI.cyan)\(pointer) \(nameStr) \(pathStr)\(ANSI.reset) \(ANSI.gray)\(countText)\(ANSI.reset)")
                } else {
                    printLine("    \(nameStr) \(ANSI.gray)\(pathStr) \(countText)\(ANSI.reset)")
                }
            }
            rowIndex += 1
        }

        printLine()

        // Render Recent Folders if any
        if recentsCount > 0 {
            printLine("  📂 \(ANSI.bold)Recent Folders\(ANSI.reset)")
            printLine("  \(UI.thinDivider)")

            for _ in 0..<recentsCount {
                let row = rows[rowIndex]
                let isSelected = (rowIndex == selectedIndex)
                let pointer = isSelected ? "❯" : " "
                if case let .recent(path, _, countText) = row {
                    let pathStr = "📁  \(path)".padding(toLength: 42, withPad: " ", startingAt: 0)
                    if isSelected {
                        printLine("  \(ANSI.bold)\(ANSI.cyan)\(pointer) \(pathStr)\(ANSI.reset) \(ANSI.gray)\(countText)\(ANSI.reset)")
                    } else {
                        printLine("    \(ANSI.gray)\(pathStr) \(countText)\(ANSI.reset)")
                    }
                }
                rowIndex += 1
            }
            printLine()
        }

        // Render Browse and Type Path
        for _ in 0..<2 {
            let row = rows[rowIndex]
            let isSelected = (rowIndex == selectedIndex)
            let pointer = isSelected ? "❯" : " "

            switch row {
            case .browse:
                let line = "🔍 Browse...             (open folder picker)"
                if isSelected {
                    printLine("  \(ANSI.bold)\(ANSI.cyan)\(pointer) \(line)\(ANSI.reset)")
                } else {
                    printLine("    \(line)")
                }
            case .typePath:
                let line = "✏️   Type a path...       (enter manually)"
                if isSelected {
                    printLine("  \(ANSI.bold)\(ANSI.cyan)\(pointer) \(line)\(ANSI.reset)")
                } else {
                    printLine("    \(line)")
                }
            default:
                break
            }
            rowIndex += 1
        }

        printLine()
        printLine(UI.thinDivider)
        printLine("  \(ANSI.gray)↑↓ navigate · Enter select · / search · q quit\(ANSI.reset)")
        printLine()
        fflush(stdout)
    }
}
