import Foundation

/// Scans a directory and returns a list of ScannedFile objects.
/// Skips hidden files, directories (in non-recursive mode),
/// and files already inside KRAM-created category folders.
public final class FileScanner {

    private let classifier: FileClassifier
    private let fm = FileManager.default

    public init(classifier: FileClassifier = ExtensionClassifier()) {
        self.classifier = classifier
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
            includingPropertiesForKeys: [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey],
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
            includingPropertiesForKeys: [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw KRAMError.permissionDenied(path: directory.path)
        }

        var results: [ScannedFile] = []
        for case let url as URL in enumerator {
            if let file = try? makeScannedFile(url: url, rootDirectory: directory, skipDirectories: true) {
                results.append(file)
            }
        }
        return results
    }

    // MARK: - File Builder

    private func makeScannedFile(url: URL, rootDirectory: URL? = nil, skipDirectories: Bool) throws -> ScannedFile? {
        let resourceValues = try url.resourceValues(
            forKeys: [.isHiddenKey, .isSymbolicLinkKey, .isDirectoryKey]
        )

        let isHidden    = resourceValues.isHidden ?? false
        let isSymlink   = resourceValues.isSymbolicLink ?? false
        let isDirectory = resourceValues.isDirectory ?? false

        // Skip hidden files
        if isHidden || url.lastPathComponent.hasPrefix(".") { return nil }

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

        let name = url.lastPathComponent
        let ext  = url.pathExtension.lowercased()

        // Build a temporary ScannedFile with .other to classify
        let temp = ScannedFile(url: url, name: name, ext: ext,
                               isHidden: isHidden, isSymlink: isSymlink,
                               category: .other)
        let category = classifier.classify(file: temp)

        return ScannedFile(url: url, name: name, ext: ext,
                           isHidden: isHidden, isSymlink: isSymlink,
                           category: category)
    }
}
