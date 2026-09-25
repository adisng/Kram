import Foundation

/// Records and replays KRAM transactions.
/// Stores JSON logs at ~/Library/Application Support/KRAM/transactions/
public final class TransactionManager {

    private let fm = FileManager.default
    private let safetyGuard = SafetyGuard.shared

    // MARK: - Storage Path

    private var transactionsDir: URL {
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("KRAM/transactions")
    }

    public init() {
        try? fm.createDirectory(at: transactionsDir, withIntermediateDirectories: true)
    }

    // MARK: - Save

    /// Saves a completed transaction to disk as JSON.
    public func save(transaction: Transaction) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(transaction)
        let file = transactionsDir.appendingPathComponent("\(transaction.id.uuidString).json")
        try data.write(to: file)
    }

    // MARK: - Load Latest

    /// Returns the most recent transaction, or nil if none exist.
    public func loadLatest() throws -> Transaction? {
        let files = try fm.contentsOfDirectory(
            at: transactionsDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        )

        guard !files.isEmpty else { return nil }

        let sorted = try files.sorted {
            let d1 = try $0.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            let d2 = try $1.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            return d1 > d2
        }

        guard let latest = sorted.first else { return nil }
        let data = try Data(contentsOf: latest)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Transaction.self, from: data)
    }

    // MARK: - Undo

    /// Reverses the latest transaction. Returns count of files restored.
    public func undo(boundary: URL, verbose: Bool = false) throws -> Int {
        guard let transaction = try loadLatest() else {
            throw KRAMError.noTransactionToUndo
        }

        var restoredCount = 0
        var emptyDirs: Set<URL> = []

        // Reverse the operations in reverse order
        for op in transaction.operations.reversed() {
            do {
                // Check destination file still exists
                guard fm.fileExists(atPath: op.destinationURL.path) else {
                    if verbose {
                        print("\(ANSI.yellow)  ⚠\(ANSI.reset)  Skipping undo for \(op.destinationURL.lastPathComponent) — file not found at destination")
                    }
                    continue
                }

                // Check source does not already exist (no overwrite)
                guard !fm.fileExists(atPath: op.sourceURL.path) else {
                    if verbose {
                        print("\(ANSI.yellow)  ⚠\(ANSI.reset)  Skipping undo for \(op.sourceURL.lastPathComponent) — file already exists at source")
                    }
                    continue
                }

                // Safety check on the reverse move
                try safetyGuard.validate(
                    source: op.destinationURL,
                    destination: op.sourceURL,
                    boundary: boundary
                )

                // Move back
                try fm.moveItem(at: op.destinationURL, to: op.sourceURL)
                restoredCount += 1

                // Mark category dir for possible cleanup
                emptyDirs.insert(op.destinationURL.deletingLastPathComponent())

                if verbose {
                    print("\(ANSI.green)  ✓\(ANSI.reset)  \(op.destinationURL.lastPathComponent) ← \(op.category)/")
                }

            } catch {
                if verbose {
                    print("\(ANSI.red)  ✗\(ANSI.reset)  \(op.destinationURL.lastPathComponent): \(error.localizedDescription)")
                }
            }
        }

        // Remove empty category directories
        for dir in emptyDirs {
            let contents = try? fm.contentsOfDirectory(atPath: dir.path)
            if contents?.isEmpty == true {
                try? fm.removeItem(at: dir)
            }
        }

        // Remove the transaction file after successful undo
        if let latest = try? loadLatest(), latest.id == transaction.id {
            let file = transactionsDir.appendingPathComponent("\(transaction.id.uuidString).json")
            try? fm.removeItem(at: file)
        }

        return restoredCount
    }
}
