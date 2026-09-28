import Foundation

/// Records and replays KRAM transactions.
/// Stores JSON logs at ~/Library/Application Support/KRAM/transactions/
public final class TransactionManager {

    private let fm = FileManager.default
    private let safetyGuard = SafetyGuard.shared
    private let customTransactionsDir: URL?

    // MARK: - Storage Path

    private var transactionsDir: URL {
        if let customTransactionsDir { return customTransactionsDir }
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("KRAM/transactions")
    }

    public init(transactionsURL: URL? = nil) {
        self.customTransactionsDir = transactionsURL
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
        let temp = transactionsDir.appendingPathComponent(".\(transaction.id.uuidString).tmp")
        try data.write(to: temp, options: .atomic)
        if fm.fileExists(atPath: file.path) {
            try fm.replaceItemAt(file, withItemAt: temp, backupItemName: nil, options: .usingNewMetadataOnly)
        } else {
            try fm.moveItem(at: temp, to: file)
        }

        // Update stats and recents after successful transaction
        StatsManager.shared.record(transaction: transaction)
        RecentsManager.shared.add(path: transaction.rootDirectory)
        try pruneTransactions()
    }

    public func listTransactions() throws -> [Transaction] {
        let files = try fm.contentsOfDirectory(at: transactionsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        return files.filter { $0.pathExtension == "json" }.compactMap { file in
            do { return try decoder.decode(Transaction.self, from: Data(contentsOf: file)) }
            catch { fputs("\(ANSI.yellow)⚠ Skipping unreadable transaction \(file.lastPathComponent)\(ANSI.reset)\n", stderr); return nil }
        }.sorted { $0.appliedAt > $1.appliedAt }
    }

    private func pruneTransactions() throws {
        let transactions = try listTransactions()
        for transaction in transactions.dropFirst(50) {
            try? fm.removeItem(at: transactionsDir.appendingPathComponent("\(transaction.id.uuidString).json"))
        }
    }

    // MARK: - Load Latest

    /// Returns the newest readable transaction, optionally constrained to a boundary.
    public func loadLatest(for boundary: URL? = nil) throws -> Transaction? {
        let files = try fm.contentsOfDirectory(at: transactionsDir, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let boundaryPath = boundary?.standardizedFileURL.path
        var transactions: [Transaction] = []

        for file in files where file.pathExtension == "json" {
            do {
                let transaction = try decoder.decode(Transaction.self, from: Data(contentsOf: file))
                if let boundaryPath {
                    let root = transaction.rootDirectory.standardizedFileURL.path
                    guard root == boundaryPath || root.hasPrefix(boundaryPath + "/") else { continue }
                }
                transactions.append(transaction)
            } catch {
                fputs("\(ANSI.yellow)⚠ Skipping unreadable transaction \(file.lastPathComponent): \(error.localizedDescription)\(ANSI.reset)\n", stderr)
            }
        }

        return transactions.max { $0.appliedAt < $1.appliedAt }
    }

    // MARK: - Undo

    /// Reverses the latest transaction. Returns count of files restored.
    public func undo(boundary: URL, id: UUID? = nil, verbose: Bool = false) throws -> Int {
        let transaction: Transaction?
        if let id {
            transaction = try listTransactions().first { $0.id == id }
        } else {
            transaction = try loadLatest(for: boundary)
        }
        guard let transaction else {
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
                    let padded = op.destinationURL.lastPathComponent.padding(toLength: 30, withPad: " ", startingAt: 0)
                    print("  \(ANSI.green)✓\(ANSI.reset)  \(padded)←  \(op.category)/")
                }

            } catch {
                if verbose {
                    let padded = op.destinationURL.lastPathComponent.padding(toLength: 30, withPad: " ", startingAt: 0)
                    print("  \(ANSI.red)✗\(ANSI.reset)  \(padded)←  \(error.localizedDescription)")
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
        let file = transactionsDir.appendingPathComponent("\(transaction.id.uuidString).json")
        try? fm.removeItem(at: file)

        return restoredCount
    }
}
