import Foundation

/// Plans file move operations from scanned files.
/// Handles filename collisions — never overwrites existing files.
public final class OperationPlanner {

    private let fm = FileManager.default

    public init() {}

    // MARK: - Plan

    /// Returns a list of PlannedOperation for all given files.
    public func plan(files: [ScannedFile], boundary: URL) -> [PlannedOperation] {
        var operations: [PlannedOperation] = []

        for file in files {
            let categoryDir = boundary.appendingPathComponent(file.category.rawValue)
            let rawDest     = categoryDir.appendingPathComponent(file.name)
            let finalDest   = resolveCollision(destination: rawDest)

            if file.url.standardizedFileURL.path == finalDest.standardizedFileURL.path {
                continue
            }

            let op = PlannedOperation(
                sourceURL: file.url,
                destinationURL: finalDest,
                category: file.category.rawValue
            )
            operations.append(op)
        }

        return operations
    }

    // MARK: - Collision Handling

    /// Returns a destination URL that does not conflict with an existing file.
    /// Appends (1), (2), ... up to (999) before giving up.
    public func resolveCollision(destination: URL) -> URL {
        guard fm.fileExists(atPath: destination.path) else {
            return destination
        }

        let dir       = destination.deletingLastPathComponent()
        let ext       = destination.pathExtension
        let base      = destination.deletingPathExtension().lastPathComponent

        for i in 1...999 {
            let newName: String
            if ext.isEmpty {
                newName = "\(base) (\(i))"
            } else {
                newName = "\(base) (\(i)).\(ext)"
            }
            let candidate = dir.appendingPathComponent(newName)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        // Fallback: use UUID suffix (should never happen in practice)
        let fallback = "\(base)_\(UUID().uuidString.prefix(8))"
        return dir.appendingPathComponent(ext.isEmpty ? fallback : "\(fallback).\(ext)")
    }
}
