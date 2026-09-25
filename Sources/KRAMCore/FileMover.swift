import Foundation

/// Executes planned file move operations.
/// Calls SafetyGuard before every single move.
/// Never deletes files. Never overwrites files.
/// Returns only the operations that actually succeeded.
public final class FileMover {

    private let fm = FileManager.default
    private let safetyGuard = SafetyGuard.shared

    public init() {}

    // MARK: - Apply

    /// Applies all planned operations within the given boundary.
    /// Skips any operation that fails SafetyGuard. Never crashes on failure.
    public func apply(
        operations: [PlannedOperation],
        boundary: URL,
        verbose: Bool = false
    ) -> (succeeded: [PlannedOperation], skipped: [(PlannedOperation, Error)]) {

        var succeeded: [PlannedOperation] = []
        var skipped:   [(PlannedOperation, Error)] = []

        for op in operations {
            do {
                // Safety check — throws on any violation
                try safetyGuard.validate(
                    source: op.sourceURL,
                    destination: op.destinationURL,
                    boundary: boundary
                )

                // Create destination directory if needed
                let destDir = op.destinationURL.deletingLastPathComponent()
                if !fm.fileExists(atPath: destDir.path) {
                    try fm.createDirectory(at: destDir,
                                          withIntermediateDirectories: true)
                }

                // Final guard: never overwrite
                guard !fm.fileExists(atPath: op.destinationURL.path) else {
                    throw KRAMError.operationFailed(
                        source: op.sourceURL.lastPathComponent,
                        reason: "Destination already exists"
                    )
                }

                // Move
                try fm.moveItem(at: op.sourceURL, to: op.destinationURL)
                succeeded.append(op)

                if verbose {
                    print("\(ANSI.green)  ✓\(ANSI.reset)  \(op.sourceURL.lastPathComponent)")
                }

            } catch {
                skipped.append((op, error))
                if verbose {
                    print("\(ANSI.yellow)  ⚠\(ANSI.reset)  Skipped \(op.sourceURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        return (succeeded, skipped)
    }
}
