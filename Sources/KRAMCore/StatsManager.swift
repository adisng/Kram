import Foundation

public struct KRAMStats: Codable {
    public var totalRuns: Int = 0
    public var totalFilesMoved: Int = 0
    public var lastRunAt: Date?
    public var mostUsedDirectory: String = ""
    public var directoryCounts: [String: Int] = [:]
    public var categoryTotals: [String: Int] = [:]

    public init(
        totalRuns: Int = 0,
        totalFilesMoved: Int = 0,
        lastRunAt: Date? = nil,
        mostUsedDirectory: String = "",
        directoryCounts: [String: Int] = [:],
        categoryTotals: [String: Int] = [:]
    ) {
        self.totalRuns = totalRuns
        self.totalFilesMoved = totalFilesMoved
        self.lastRunAt = lastRunAt
        self.mostUsedDirectory = mostUsedDirectory
        self.directoryCounts = directoryCounts
        self.categoryTotals = categoryTotals
    }
}

public final class StatsManager {
    public static let shared = StatsManager()

    private let fm = FileManager.default
    private var statsFile: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("KRAM/stats.json")
    }

    public init() {
        let dir = statsFile.deletingLastPathComponent()
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    public func load() -> KRAMStats {
        guard let data = try? Data(contentsOf: statsFile) else {
            return KRAMStats()
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode(KRAMStats.self, from: data)) ?? KRAMStats()
    }

    public func save(_ stats: KRAMStats) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(stats)
        try data.write(to: statsFile)
    }

    public func record(transaction: Transaction) {
        var stats = load()
        stats.totalRuns += 1
        stats.totalFilesMoved += transaction.operations.count
        stats.lastRunAt = transaction.appliedAt

        let home = fm.homeDirectoryForCurrentUser.path
        var dirStr = transaction.rootDirectory.path
        if dirStr.hasPrefix(home) {
            dirStr = dirStr.replacingOccurrences(of: home, with: "~")
        }

        stats.directoryCounts[dirStr, default: 0] += 1
        if let topDir = stats.directoryCounts.max(by: { $0.value < $1.value })?.key {
            stats.mostUsedDirectory = topDir
        }

        for op in transaction.operations {
            stats.categoryTotals[op.category, default: 0] += 1
        }

        try? save(stats)
    }
}
