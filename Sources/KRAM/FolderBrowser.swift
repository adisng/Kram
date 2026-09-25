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
    private static let protectedNames: Set<String> = [
        "Library", ".ssh", ".config", "Applications", ".gnupg", ".aws", ".kube"
    ]
    private static let systemProtectedRoots: Set<String> = [
        "/System", "/Library", "/usr", "/bin", "/sbin", "/private", "/Applications", "/Volumes", "/dev", "/var", "/etc", "/opt"
    ]

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

    public static func browse(startingAt initialURL: URL) -> URL? {
        var currentURL = initialURL.standardizedFileURL
        var selectedIndex = 0

        let originalTerm = Terminal.enableRawMode()
        Terminal.hideCursor()
        defer {
            Terminal.showCursor()
            Terminal.restoreMode(originalTerm)
        }

        while true {
            let items = loadSubfolders(of: currentURL)
            if selectedIndex >= items.count {
                selectedIndex = max(0, items.count - 1)
            }

            render(currentURL: currentURL, items: items, selectedIndex: selectedIndex)

            let key = Terminal.readKey()
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
                if parent.path != currentURL.path && !systemProtectedRoots.contains(currentURL.path) {
                    currentURL = parent
                    selectedIndex = 0
                }
            case .enter:
                if items.isEmpty {
                    return currentURL
                } else if selectedIndex < items.count {
                    let item = items[selectedIndex]
                    if item.isProtected {
                        // Protected item cannot be selected
                        continue
                    }
                    return item.url
                }
            case .escape, .quit:
                return nil
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
                let isProtected = protectedNames.contains(name) || systemProtectedRoots.contains(url.path)
                let countText = isProtected ? "(protected)" : countOrganizableFiles(in: url)
                results.append(FolderItem(name: name, url: url, isProtected: isProtected, fileCountText: countText))
            }
        }

        return results.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private static func render(currentURL: URL, items: [FolderItem], selectedIndex: Int) {
        Terminal.clearScreen()
        Terminal.moveTo(row: 1, col: 1)

        print("🐭 \(ANSI.bold)KRAM — Browse Folders\(ANSI.reset)")
        print(UI.divider)
        print("  📍 \(ANSI.cyan)\(UI.formatDisplayPath(currentURL))\(ANSI.reset)")
        print(UI.divider)
        print()

        if items.isEmpty {
            print("  \(ANSI.gray)(No accessible subfolders)\(ANSI.reset)")
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
                    print("  \(pointer) \(icon) \(ANSI.gray)\(namePadded) (protected)\(ANSI.reset)")
                } else if isSelected {
                    print("  \(ANSI.bold)\(ANSI.cyan)\(pointer) \(icon) \(namePadded)\(ANSI.reset) \(ANSI.gray)\(item.fileCountText)\(ANSI.reset)")
                } else {
                    print("    \(icon) \(namePadded) \(ANSI.gray)\(item.fileCountText)\(ANSI.reset)")
                }
            }
        }

        print()
        print(UI.divider)
        print("  \(ANSI.gray)↑↓ navigate · → enter folder · ← go back\(ANSI.reset)")
        print("  \(ANSI.gray)Enter select highlighted · q cancel\(ANSI.reset)\n")
        fflush(stdout)
    }
}
