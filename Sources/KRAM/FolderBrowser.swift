import Foundation
import KRAMCore

public final class FolderBrowser {

    public struct FolderItem {
        public let name: String
        public let url: URL
        public let isProtected: Bool
        public let fileCountText: String
    }

    private static let categoryFolderNames: Set<String> = Set(FileCategory.allCases.map { $0.rawValue })

    public static func iconForFolder(_ name: String) -> String {
        switch name.lowercased() {
        case "downloads":  return "📥"
        case "desktop":    return "🖥 "
        case "documents":  return "📄"
        case "music":      return "🎵"
        case "movies":     return "🎬"
        case "pictures":   return "🖼 "
        case "developer":  return "💻"
        case "projects":   return "🛠 "
        case "work":       return "💼"
        case "github":     return "🐙"
        case "library":    return "🔒"
        default:           return "📁"
        }
    }

    public static func countOrganizableFiles(in dir: URL) -> String {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isHiddenKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return "(0 files)"
        }

        var count = 0
        for item in contents {
            if let vals = try? item.resourceValues(forKeys: [.isHiddenKey, .isDirectoryKey]),
               vals.isDirectory != true && vals.isHidden != true {
                count += 1
                if count > 100 {
                    return "(100+ files)"
                }
            }
        }

        if count == 0 {
            return "(nothing to organize)"
        } else if count == 1 {
            return "(1 file)"
        } else {
            return "(\(count) files)"
        }
    }

    public static func browse(startingAt initialURL: URL) -> PickerResult {
        let home = FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL.path
        var currentURL = initialURL.standardizedFileURL
        var selectedIndex = 0

        let originalTerm = Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.showCursor()
            Terminal.restoreMode(originalTerm)
        }

        Terminal.clearScreen()

        while true {
            let items = loadSubfolders(of: currentURL)
            if selectedIndex >= items.count {
                selectedIndex = max(0, items.count - 1)
            }

            render(currentURL: currentURL, items: items, selectedIndex: selectedIndex)

            let key = Terminal.readKey()
            if key == .unknown && feof(stdin) != 0 {
                Terminal.clearScreen()
                return .cancelled
            }
            switch key {
            case .up:
                if selectedIndex > 0 { selectedIndex -= 1 }
            case .down:
                if selectedIndex < items.count - 1 { selectedIndex += 1 }
            case .right:
                if !items.isEmpty && selectedIndex < items.count {
                    let item = items[selectedIndex]
                    if !item.isProtected {
                        currentURL = item.url
                        selectedIndex = 0
                    }
                }
            case .left:
                let parent = currentURL.deletingLastPathComponent()
                let currentPath = currentURL.standardizedFileURL.path
                let parentPath = parent.standardizedFileURL.path
                if parentPath != currentPath
                    && currentPath != home
                    && (parentPath == home || parentPath.hasPrefix(home + "/"))
                    && !SafetyGuard.shared.isProtectedPath(currentURL) {
                    currentURL = parent
                    selectedIndex = 0
                }
            case .enter:
                if items.isEmpty {
                    Terminal.clearScreen()
                    return .selected(currentURL)
                } else if selectedIndex < items.count {
                    let item = items[selectedIndex]
                    if item.isProtected {
                        // Protected item cannot be selected
                        continue
                    }
                    Terminal.clearScreen()
                    return .selected(item.url)
                }
            case .escape:
                Terminal.clearScreen()
                return .back
            case .quit:
                Terminal.clearScreen()
                return .cancelled
            default:
                break
            }
        }
    }

    private static func loadSubfolders(of dir: URL) -> [FolderItem] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: dir,
            includingPropertiesForKeys: [.isDirectoryKey, .isHiddenKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        var results: [FolderItem] = []
        for url in contents {
            let name = url.lastPathComponent
            if name.hasPrefix(".") { continue }
            if categoryFolderNames.contains(name) { continue }

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: url.path, isDirectory: &isDir) && isDir.boolValue {
                let isProtected = SafetyGuard.shared.isProtectedPath(url)
                let countText = isProtected ? "(protected)" : countOrganizableFiles(in: url)
                results.append(FolderItem(name: name, url: url, isProtected: isProtected, fileCountText: countText))
            }
        }

        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func printLine(_ text: String = "") {
        print(text, terminator: "")
        Terminal.clearToEndOfLine()
        print()
    }

    private static func render(currentURL: URL, items: [FolderItem], selectedIndex: Int) {
        Terminal.moveTo(row: 1, col: 1)

        printLine("🐭 \(ANSI.bold)KRAM — Browse Folders\(ANSI.reset)")
        printLine(UI.divider)
        printLine("  📍 \(ANSI.cyan)\(UI.formatDisplayPath(currentURL))\(ANSI.reset)")
        printLine(UI.divider)
        printLine()

        if items.isEmpty {
            printLine("  \(ANSI.gray)(No accessible subfolders)\(ANSI.reset)")
            for _ in 0..<11 {
                printLine()
            }
        } else {
            let maxVisible = 12
            let startIndex = max(0, min(selectedIndex - maxVisible / 2, items.count - maxVisible))
            let endIndex = min(items.count, startIndex + maxVisible)

            for i in startIndex..<endIndex {
                let item = items[i]
                let isSelected = (i == selectedIndex)
                let pointer = isSelected ? "❯" : " "
                let icon = iconForFolder(item.name)
                let namePadded = item.name.padding(toLength: 30, withPad: " ", startingAt: 0)

                if item.isProtected {
                    printLine("  \(pointer) \(icon) \(ANSI.gray)\(namePadded) (protected)\(ANSI.reset)")
                } else if isSelected {
                    printLine("  \(ANSI.bold)\(ANSI.cyan)\(pointer) \(icon) \(namePadded)\(ANSI.reset) \(ANSI.gray)\(item.fileCountText)\(ANSI.reset)")
                } else {
                    printLine("    \(icon) \(namePadded) \(ANSI.gray)\(item.fileCountText)\(ANSI.reset)")
                }
            }

            let renderedCount = endIndex - startIndex
            if renderedCount < maxVisible {
                for _ in renderedCount..<maxVisible {
                    printLine()
                }
            }
        }

        printLine()
        printLine(UI.divider)
        printLine("  \(ANSI.gray)↑↓ navigate · → enter folder · ← go back\(ANSI.reset)")
        printLine("  \(ANSI.gray)Enter select highlighted · Esc back · q cancel\(ANSI.reset)")
        printLine()
        fflush(stdout)
    }
}
