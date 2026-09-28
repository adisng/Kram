import Foundation

/// Scans a directory and returns a list of ScannedFile objects.
/// Skips hidden files, directories (in non-recursive mode),
/// and files already inside KRAM-created category folders.
public final class FileScanner {

    private let classifier: FileClassifier
    private let config: KRAMConfig
    private let recentFileThreshold: TimeInterval
    private let requireStableFiles: Bool
    private let fm = FileManager.default

    public init(classifier: FileClassifier = ClassifierFactory.makeDefault(), config: KRAMConfig = ConfigurationManager().load(), recentFileThreshold: TimeInterval = 5, requireStableFiles: Bool = [...]
        self.classifier = classifier
        self.config = config
        self.recentFileThreshold = recentFileThreshold
        self.requireStableFiles = requireStableFiles
    }

    // MARK: - Known Category Folder Names

    private let categoryFolderNames: Set<String> =
        Set(FileCategory.allCases.map { $0.rawValue })

    // MARK: - Public Scan

    /// Scans the given directory. If recursive is true, walks all subdirectories.
    public func scan(directory: URL, recursive: Bool = false) throws -> [ScannedFile] {
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDir) else {
            throw KRAMError.directoryNotFound(path: directory.path)
        }
        guard isDir.boolValue else {
            throw KRAMError.notADirectory(path: directory.path)
        }

        if recursive {
            return try scanRecursive(directory: directory)
        } else {
            return try scanFlat(directory: directory)
        }
    }

    // MARK: - Flat Scan

    private func scanFlat(directory: URL) throws -> [ScannedFile] {
        let contents = try fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: []
        )

        var results: [ScannedFile] = []
        for url in contents {
            if let file = try? makeScannedFile(url: url, rootDirectory: directory, skipDirectories: true) {
                results.append(file)
            }
        }
        return results
    }

    // MARK: - Recursive Scan

    private func scanRecursive(directory: URL) throws -> [ScannedFile] {
        guard let enumerator = fm.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw KRAMError.permissionDenied(path: directory.path)
        }

        var results: [ScannedFile] = []
        for case let url as URL in enumerator {
            if categoryFolderNames.contains(url.lastPathComponent),
               (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                enumerator.skipDescendants()
                continue
            }
            if let file = try? makeScannedFile(url: url, rootDirectory: directory, skipDirectories: true) {
                results.append(file)
            }
        }
        return results
    }

    // MARK: - File Builder

    private func makeScannedFile(url: URL, rootDirectory: URL? = nil, skipDirectories: Bool) throws -> ScannedFile? {
        let resourceValues = try url.resourceValues(
            forKeys: [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey, .fileSizeKey, .contentModificationDateKey]
        )

        let isHidden    = resourceValues.isHidden ?? false
        let isSymlink   = resourceValues.isSymbolicLink ?? false
        let isDirectory = resourceValues.isDirectory ?? false

        // Skip hidden files
        if isHidden || url.lastPathComponent.hasPrefix(".") { return nil }

        let ext = url.pathExtension.lowercased()
        let partialExtensions: Set<String> = ["crdownload", "part", "download", "partial", "tmp", "opdownload"]
        if partialExtensions.contains(ext) { return nil }
        if isDirectory && url.lastPathComponent.lowercased().hasSuffix(".download") { return nil }

        // Skip directories in flat mode
        if skipDirectories && isDirectory { return nil }

        // Skip files already inside a KRAM category subfolder
        let parentURL = url.deletingLastPathComponent().standardizedFileURL
        if let rootURL = rootDirectory?.standardizedFileURL {
            if parentURL.path != rootURL.path {
                if parentURL.deletingLastPathComponent().path == rootURL.path && categoryFolderNames.contains(parentURL.lastPathComponent) {
                    return nil
                }
            }
        } else {
            let parentFolderName = parentURL.lastPathComponent
            if categoryFolderNames.contains(parentFolderName) { return nil }
        }

        if let modified = resourceValues.contentModificationDate,
           Date().timeIntervalSince(modified) < recentFileThreshold { return nil }
        if requireStableFiles && !isStable(url: url, initial: resourceValues) { return nil }

        let name = url.lastPathComponent
        if config.skipPatterns.contains(where: { Self.globMatches($0, name: name) }) { return nil }

        // Build a temporary ScannedFile with .other to classify
        let temp = ScannedFile(url: url, name: name, ext: ext,
                               isHidden: isHidden, isSymlink: isSymlink,
                               category: .other)
        let category = classifier.classify(file: temp)
        if config.disabledCategories.contains(category.rawValue) { return nil }

        return ScannedFile(url: url, name: name, ext: ext,
                           isHidden: isHidden, isSymlink: isSymlink,
                           category: category)
    }

    private func isStable(url: URL, initial: URLResourceValues) -> Bool {
        Thread.sleep(forTimeInterval: 0.05)
        guard let current = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) else { return false }
        return current.fileSize == initial.fileSize && current.contentModificationDate == initial.contentModificationDate
    }

    private static func globMatches(_ pattern: String, name: String) -> Bool {
        var regex = "^"
        for scalar in pattern.unicodeScalars {
            switch scalar {
            case "*": regex += ".*"
            case "?": regex += "."
            default: regex += NSRegularExpression.escapedPattern(for: String(scalar))
            }
        }
        regex += "$"
        return name.range(of: regex, options: .regularExpression) != nil
    }
}
