import Foundation

/// KRAM user configuration.
public struct KRAMConfig: Codable {
    public var version: String = "1"
    public var customMappings: [String: [String]] = [:]
    public var disabledCategories: [String] = []
    public var skipPatterns: [String] = [".DS_Store", "Thumbs.db", "desktop.ini"]

    public init() {}
}

/// Reads and writes KRAM config from ~/.config/kram/config.json
public final class ConfigurationManager {

    private let fm = FileManager.default

    private var configDir: URL {
        fm.homeDirectoryForCurrentUser.appendingPathComponent(".config/kram")
    }

    private var configFile: URL {
        configDir.appendingPathComponent("config.json")
    }

    public init() {}

    // MARK: - Load

    /// Returns the current config, or default config if none exists.
    public func load() -> KRAMConfig {
        guard let data = try? Data(contentsOf: configFile),
              let config = try? JSONDecoder().decode(KRAMConfig.self, from: data) else {
            return KRAMConfig()
        }
        return config
    }

    // MARK: - Save

    /// Saves config to disk. Creates the config directory if needed.
    public func save(_ config: KRAMConfig) throws {
        try fm.createDirectory(at: configDir, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: configFile)
    }
}
