import Foundation

public struct RecentFolder: Codable, Equatable {
    public let path: String
    public let lastUsed: Date

    public init(path: String, lastUsed: Date = Date()) {
        self.path = path
        self.lastUsed = lastUsed
    }
}

private struct RecentsContainer: Codable {
    var recents: [RecentFolder]
}

public final class RecentsManager {
    public static let shared = RecentsManager()

    private let fm = FileManager.default

    private var recentsFile: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("KRAM/recents.json")
    }

    public init() {
        let dir = recentsFile.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    /// Returns existing valid paths only. Removes missing ones silently.
    public func load() -> [RecentFolder] {
        guard let data = try? Data(contentsOf: recentsFile) else {
            return []
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let container = try? decoder.decode(RecentsContainer.self, from: data) else {
            return []
        }

        let home = fm.homeDirectoryForCurrentUser.path
        var validRecents: [RecentFolder] = []
        var modified = false

        for item in container.recents {
            let expandedPath = item.path.hasPrefix("~")
                ? item.path.replacingOccurrences(of: "~", with: home)
                : item.path

            var isDir: ObjCBool = false
            if fm.fileExists(atPath: expandedPath, isDirectory: &isDir) && isDir.boolValue {
                validRecents.append(item)
            } else {
                modified = true
            }
        }

        if modified {
            save(validRecents)
        }

        return validRecents
    }

    /// Prepend, deduplicate, cap at 5.
    public func add(path: URL) {
        let home = fm.homeDirectoryForCurrentUser.path
        var pathStr = path.standardizedFileURL.path
        if pathStr.hasPrefix(home) {
            pathStr = pathStr.replacingOccurrences(of: home, with: "~")
        }

        var current = load()
        current.removeAll { $0.path == pathStr }
        current.insert(RecentFolder(path: pathStr, lastUsed: Date()), at: 0)

        if current.count > 5 {
            current = Array(current.prefix(5))
        }

        save(current)
    }

    /// Remove a specific entry.
    public func remove(path: URL) {
        let home = fm.homeDirectoryForCurrentUser.path
        var pathStr = path.standardizedFileURL.path
        if pathStr.hasPrefix(home) {
            pathStr = pathStr.replacingOccurrences(of: home, with: "~")
        }

        var current = load()
        current.removeAll { $0.path == pathStr }
        save(current)
    }

    private func save(_ recents: [RecentFolder]) {
        let container = RecentsContainer(recents: recents)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(container) {
            try? data.write(to: recentsFile)
        }
    }
}
