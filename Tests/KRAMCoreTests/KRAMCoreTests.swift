import Testing
@testable import KRAMCore

@Suite("KRAMCore Tests")
struct KRAMCoreTests {

    @Test("FileCategory allCases non empty")
    func testFileCategoryAllCasesNonEmpty() {
        #expect(!FileCategory.allCases.isEmpty)
    }

    @Test("Extension Classification")
    func testExtensionClassification() {
        let classifier = ExtensionClassifier()

        let pdf = ScannedFile(url: URL(fileURLWithPath: "/dummy/doc.pdf"), name: "doc.pdf", ext: "pdf", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: pdf) == .documents)

        let png = ScannedFile(url: URL(fileURLWithPath: "/dummy/pic.PNG"), name: "pic.PNG", ext: "PNG", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: png) == .images)

        let code = ScannedFile(url: URL(fileURLWithPath: "/dummy/main.swift"), name: "main.swift", ext: "swift", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: code) == .code)

        let zip = ScannedFile(url: URL(fileURLWithPath: "/dummy/archive.zip"), name: "archive.zip", ext: "zip", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: zip) == .archives)

        let dmg = ScannedFile(url: URL(fileURLWithPath: "/dummy/app.dmg"), name: "app.dmg", ext: "dmg", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: dmg) == .installers)

        let app = ScannedFile(url: URL(fileURLWithPath: "/dummy/Tool.app"), name: "Tool.app", ext: "app", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: app) == .installers)

        let json = ScannedFile(url: URL(fileURLWithPath: "/dummy/config.json"), name: "config.json", ext: "json", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: json) == .data)

        let yaml = ScannedFile(url: URL(fileURLWithPath: "/dummy/config.yaml"), name: "config.yaml", ext: "yaml", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: yaml) == .data)

        let unknown = ScannedFile(url: URL(fileURLWithPath: "/dummy/unknown.xyz123"), name: "unknown.xyz123", ext: "xyz123", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: unknown) == .other)
    }

    @Test("SafetyGuard Blocks Outside Boundary")
    func testSafetyGuardBlocksOutsideBoundary() {
        let guard_ = SafetyGuard.shared
        let boundary = URL(fileURLWithPath: "/Users/test/Downloads")
        let source = URL(fileURLWithPath: "/Users/test/Downloads/file.txt")
        let outsideDest = URL(fileURLWithPath: "/Users/test/Desktop/file.txt")

        #expect(throws: SafetyViolation.self) {
            try guard_.validate(source: source, destination: outsideDest, boundary: boundary)
        }
    }

    @Test("SafetyGuard Blocks Path Traversal")
    func testSafetyGuardBlocksPathTraversal() {
        let guard_ = SafetyGuard.shared
        let boundary = URL(fileURLWithPath: "/Users/test/Downloads")
        let traversalSource = URL(fileURLWithPath: "/Users/test/Downloads/../secret.txt")
        let dest = URL(fileURLWithPath: "/Users/test/Downloads/Documents/secret.txt")

        #expect(throws: SafetyViolation.self) {
            try guard_.validate(source: traversalSource, destination: dest, boundary: boundary)
        }
    }

    @Test("SafetyGuard isProtectedPath")
    func testSafetyGuardIsProtectedPath() {
        let guard_ = SafetyGuard.shared
        let home = FileManager.default.homeDirectoryForCurrentUser

        // System paths
        #expect(guard_.isProtectedPath(URL(fileURLWithPath: "/System")))
        #expect(guard_.isProtectedPath(URL(fileURLWithPath: "/System/Library")))
        #expect(guard_.isProtectedPath(URL(fileURLWithPath: "/cores")))
        #expect(guard_.isProtectedPath(URL(fileURLWithPath: "/Network")))
        #expect(guard_.isProtectedPath(URL(fileURLWithPath: "/usr/bin")))

        // User paths
        #expect(guard_.isProtectedPath(home.appendingPathComponent("Library")))
        #expect(guard_.isProtectedPath(home.appendingPathComponent(".ssh")))
        #expect(guard_.isProtectedPath(home.appendingPathComponent(".ssh/id_rsa")))
        #expect(guard_.isProtectedPath(home.appendingPathComponent(".zshrc")))
        #expect(guard_.isProtectedPath(home.appendingPathComponent(".gitconfig")))

        // Unprotected paths
        #expect(!guard_.isProtectedPath(home.appendingPathComponent("Downloads")))
        #expect(!guard_.isProtectedPath(home.appendingPathComponent("Desktop")))
        #expect(!guard_.isProtectedPath(home.appendingPathComponent("Documents")))
        #expect(!guard_.isProtectedPath(home.appendingPathComponent("Projects/TestApp")))
    }

    @Test("Collision Resolution")
    func testCollisionResolution() {
        let planner = OperationPlanner()
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let file1 = tempDir.appendingPathComponent("test.pdf")
        FileManager.default.createFile(atPath: file1.path, contents: Data())

        let resolved = planner.resolveCollision(destination: file1)
        #expect(resolved.lastPathComponent == "test (1).pdf")
    }

    @Test("OperationPlanner Discards Redundant Moves")
    func testPlannerDoesNotProduceRedundantMoves() {
        let planner = OperationPlanner()
        let boundary = URL(fileURLWithPath: "/Users/test/Downloads")
        let docURL = boundary.appendingPathComponent("Documents/report.pdf")

        let scanned = ScannedFile(url: docURL, name: "report.pdf", ext: "pdf", isHidden: false, isSymlink: false, category: .documents)
        let ops = planner.plan(files: [scanned], boundary: boundary)

        #expect(ops.isEmpty)
    }

    @Test("RecentsManager Add and Load")
    func testRecentsManagerAddAndLoad() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let recentsFile = tempDir.appendingPathComponent("recents.json")
        let manager = RecentsManager(storageURL: recentsFile)

        let folder = tempDir.appendingPathComponent("FolderA")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        manager.add(path: folder)
        let loaded = manager.load()
        #expect(loaded.count == 1)
        #expect(loaded.first?.path.contains("FolderA") == true)
    }

    @Test("RecentsManager Deduplication")
    func testRecentsManagerDeduplication() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let recentsFile = tempDir.appendingPathComponent("recents.json")
        let manager = RecentsManager(storageURL: recentsFile)

        let folderA = tempDir.appendingPathComponent("FolderA")
        let folderB = tempDir.appendingPathComponent("FolderB")
        try? FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: folderB, withIntermediateDirectories: true)

        manager.add(path: folderA)
        manager.add(path: folderB)
        manager.add(path: folderA)

        let loaded = manager.load()
        #expect(loaded.count == 2)
        #expect(loaded[0].path.contains("FolderA"))
        #expect(loaded[1].path.contains("FolderB"))
    }

    @Test("RecentsManager Cap at 5")
    func testRecentsManagerCapAt5() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let recentsFile = tempDir.appendingPathComponent("recents.json")
        let manager = RecentsManager(storageURL: recentsFile)

        for i in 1...6 {
            let f = tempDir.appendingPathComponent("Folder\(i)")
            try? FileManager.default.createDirectory(at: f, withIntermediateDirectories: true)
            manager.add(path: f)
        }

        let loaded = manager.load()
        #expect(loaded.count == 5)
        #expect(loaded[0].path.contains("Folder6"))
        #expect(!loaded.contains { $0.path.contains("Folder1") })
    }

    @Test("RecentsManager Missing Path Pruning")
    func testRecentsManagerMissingPathPruning() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let recentsFile = tempDir.appendingPathComponent("recents.json")
        let manager = RecentsManager(storageURL: recentsFile)

        let folderExist = tempDir.appendingPathComponent("FolderExist")
        let folderDelete = tempDir.appendingPathComponent("FolderDelete")
        try? FileManager.default.createDirectory(at: folderExist, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: folderDelete, withIntermediateDirectories: true)

        manager.add(path: folderExist)
        manager.add(path: folderDelete)

        // Delete folderDelete from disk
        try? FileManager.default.removeItem(at: folderDelete)

        // load() should prune missing path
        let loaded = manager.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].path.contains("FolderExist"))

        // Re-load to ensure saved state was pruned
        let reloaded = manager.load()
        #expect(reloaded.count == 1)
        #expect(reloaded[0].path.contains("FolderExist"))
    }

    @Test("RecentsManager Remove")
    func testRecentsManagerRemove() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let recentsFile = tempDir.appendingPathComponent("recents.json")
        let manager = RecentsManager(storageURL: recentsFile)

        let folderA = tempDir.appendingPathComponent("FolderA")
        let folderB = tempDir.appendingPathComponent("FolderB")
        try? FileManager.default.createDirectory(at: folderA, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(at: folderB, withIntermediateDirectories: true)

        manager.add(path: folderA)
        manager.add(path: folderB)
        manager.remove(path: folderA)

        let loaded = manager.load()
        #expect(loaded.count == 1)
        #expect(loaded[0].path.contains("FolderB"))
    }
    // MARK: - DirectoryWatcher Tests

    /// Creates a temp dir, starts a watcher with a short debounce, writes a file,
    /// and asserts the onChange callback fires within a 3-second timeout.
    @Test("DirectoryWatcher fires onChange after file is written")
    func testDirectoryWatcherFiresOnChange() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KRAMWatcherTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let watcher = DirectoryWatcher(directory: tempDir, debounceInterval: 0.1)
        var callbackCount = 0
        let callbackLock = NSLock()

        watcher.start {
            callbackLock.lock()
            callbackCount += 1
            callbackLock.unlock()
        }

        // Give FSEvents a moment to register the stream
        Thread.sleep(forTimeInterval: 0.2)

        // Write a file
        let testFile = tempDir.appendingPathComponent("test_\(UUID().uuidString).txt")
        try "hello".write(to: testFile, atomically: true, encoding: .utf8)

        // Poll up to 3 seconds for the callback to fire
        let deadline = Date().addingTimeInterval(3.0)
        while Date() < deadline {
            callbackLock.lock()
            let count = callbackCount
            callbackLock.unlock()
            if count > 0 { break }
            Thread.sleep(forTimeInterval: 0.05)
        }

        watcher.stop()

        callbackLock.lock()
        let finalCount = callbackCount
        callbackLock.unlock()

        #expect(finalCount >= 1, "onChange should have fired at least once")
    }

    /// Writes 5 files within 50ms, asserts onChange fires exactly once after
    /// the 300ms debounce window (not once per file).
    @Test("DirectoryWatcher debounces rapid writes into one callback")
    func testDirectoryWatcherDebounce() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KRAMWatcherDebounce_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Longer debounce so we can clearly observe coalescing
        let debounce: TimeInterval = 0.3
        let watcher = DirectoryWatcher(directory: tempDir, debounceInterval: debounce)
        var callbackCount = 0
        let callbackLock = NSLock()

        watcher.start {
            callbackLock.lock()
            callbackCount += 1
            callbackLock.unlock()
        }

        // Give FSEvents a moment to register
        Thread.sleep(forTimeInterval: 0.2)

        // Write 5 files within ~50ms
        for i in 1...5 {
            let file = tempDir.appendingPathComponent("burst_\(i)_\(UUID().uuidString).txt")
            try "\(i)".write(to: file, atomically: true, encoding: .utf8)
            Thread.sleep(forTimeInterval: 0.01)  // 10ms apart
        }

        // Wait for debounce to settle: debounce window + generous buffer
        Thread.sleep(forTimeInterval: debounce + 0.5)
        watcher.stop()

        callbackLock.lock()
        let finalCount = callbackCount
        callbackLock.unlock()

        // All 5 writes should coalesce into exactly 1 callback
        #expect(finalCount == 1, "Expected exactly 1 coalesced callback, got \(finalCount)")
    }

    // MARK: - ArgumentParser Tests

    @Test("ArgumentParser: kr dl parses with no yes and no apply")
    func testParserDlNoFlags() {
        let args = ArgumentParser.parse(["dl"])
        #expect(args.yes == false)
        #expect(args.apply == false)
        #expect(args.dryRun == false)
        #expect(args.targetURL != nil)
    }

    @Test("ArgumentParser: --yes flag sets yes=true")
    func testParserYesFlag() {
        let args = ArgumentParser.parse(["dl", "--yes"])
        #expect(args.yes == true)
        #expect(args.apply == false)
    }

    @Test("ArgumentParser: --dry-run sets dryRun=true")
    func testParserDryRunFlag() {
        let args = ArgumentParser.parse(["dl", "--dry-run"])
        #expect(args.dryRun == true)
        #expect(args.yes == false)
    }

    @Test("ArgumentParser: -a still sets apply=true")
    func testParserShortApply() {
        let args = ArgumentParser.parse(["dl", "-a"])
        #expect(args.apply == true)
        #expect(args.yes == false)
    }

    @Test("ArgumentParser: -arv combined short flags still work")
    func testParserCombinedShortFlags() {
        let args = ArgumentParser.parse(["dl", "-arv"])
        #expect(args.apply == true)
        #expect(args.recursive == true)
        #expect(args.verbose == true)
    }

    @Test("ArgumentParser: -n sets dryRun")
    func testParserShortDryRun() {
        let args = ArgumentParser.parse(["dl", "-n"])
        #expect(args.dryRun == true)
    }

    @Test("ArgumentParser: completion command parses")
    func testParserCompletion() {
        let args = ArgumentParser.parse(["completion"])
        #expect(args.showCompletion == true)
        #expect(args.completionShell == nil)
    }

    @Test("ArgumentParser: completion shell options parse")
    func testParserCompletionShells() {
        let zsh = ArgumentParser.parse(["completion", "zsh"])
        #expect(zsh.showCompletion == true)
        #expect(zsh.completionShell == "zsh")

        let bash = ArgumentParser.parse(["completion", "bash"])
        #expect(bash.showCompletion == true)
        #expect(bash.completionShell == "bash")

        let fish = ArgumentParser.parse(["completion", "fish"])
        #expect(fish.showCompletion == true)
        #expect(fish.completionShell == "fish")
    }

    // MARK: - Completion Generation Tests

    @Test("Completion script generation for zsh, bash, fish")
    func testCompletionGeneration() {
        let zshScript = Completion.generate(shell: "zsh")
        #expect(zshScript.contains("compdef"))
        #expect(zshScript.contains("--yes"))

        let bashScript = Completion.generate(shell: "bash")
        #expect(bashScript.contains("complete"))
        #expect(bashScript.contains("--yes"))

        let fishScript = Completion.generate(shell: "fish")
        #expect(fishScript.contains("complete -c kr"))
        #expect(fishScript.contains("--yes"))
    }

    // MARK: - Flow Execution Test (Stubbed Temp Dir)

    @Test("Flow test: organize with stubbed directory moves files without prompt")
    func testAutoOrganizeFlowWithTempDir() throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("KRAMFlowTest_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create sample file
        let pdfFile = tempDir.appendingPathComponent("invoice.pdf")
        try "dummy pdf content".write(to: pdfFile, atomically: true, encoding: .utf8)

        let scanner = FileScanner()
        let planner = OperationPlanner()
        let mover = FileMover()

        let scanned = try scanner.scan(directory: tempDir, recursive: false)
        #expect(scanned.count == 1)

        let ops = planner.plan(files: scanned, boundary: tempDir)
        #expect(ops.count == 1)
        #expect(ops[0].category == "Documents")

        let result = mover.apply(operations: ops, boundary: tempDir, verbose: false)
        #expect(result.succeeded.count == 1)
        #expect(result.skipped.isEmpty)

        // Verify file was moved to Documents/
        let expectedDest = tempDir.appendingPathComponent("Documents/invoice.pdf")
        #expect(FileManager.default.fileExists(atPath: expectedDest.path))
        #expect(!FileManager.default.fileExists(atPath: pdfFile.path))
    }

    @Test("TransactionManager selects scoped and global latest transactions and undoes safely")
    func testTransactionManagerScopedLatestAndUndo() throws {
        let root = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kram-transaction-test-\(UUID().uuidString)")
        let transactionDir = root.appendingPathComponent("transactions")
        let downloads = root.appendingPathComponent("Downloads")
        let desktop = root.appendingPathComponent("Desktop")
        try FileManager.default.createDirectory(at: downloads, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: desktop, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let manager = TransactionManager(transactionsURL: transactionDir)
        let downloadSource = downloads.appendingPathComponent("old.txt")
        let downloadDest = downloads.appendingPathComponent("Documents/old.txt")
        let desktopSource = desktop.appendingPathComponent("new.txt")
        let desktopDest = desktop.appendingPathComponent("Documents/new.txt")
        try "old".write(to: downloadDest, atomically: true, encoding: .utf8)
        try "new".write(to: desktopDest, atomically: true, encoding: .utf8)

        let older = Transaction(rootDirectory: downloads, operations: [
            PlannedOperation(sourceURL: downloadSource, destinationURL: downloadDest, category: "Documents")
        ], appliedAt: Date(timeIntervalSince1970: 100))
        let newer = Transaction(rootDirectory: desktop, operations: [
            PlannedOperation(sourceURL: desktopSource, destinationURL: desktopDest, category: "Documents")
        ], appliedAt: Date(timeIntervalSince1970: 200))
        try manager.save(transaction: older)
        try manager.save(transaction: newer)
        try Data("not json".utf8).write(to: transactionDir.appendingPathComponent("corrupt.json"))

        #expect(try manager.loadLatest(for: downloads)?.id == older.id)
        #expect(try manager.loadLatest()?.id == newer.id)

        #expect(try manager.undo(boundary: downloads) == 1)
        #expect(FileManager.default.fileExists(atPath: downloadSource.path))
        #expect(!FileManager.default.fileExists(atPath: downloadDest.path))
        #expect(!FileManager.default.fileExists(atPath: downloadDest.deletingLastPathComponent().path))
        #expect(FileManager.default.fileExists(atPath: transactionDir.appendingPathComponent("\(newer.id.uuidString).json").path))
    }

    @Test("ClassifierFactory returns a usable classifier")
    func testClassifierFactory() {
        let classifier = ClassifierFactory.makeDefault()
        let file = ScannedFile(url: URL(fileURLWithPath: "/dummy/test.pdf"), name: "test.pdf", ext: "pdf", isHidden: false, isSymlink: false, category: .other)
        #expect(classifier.classify(file: file) == .documents)
    }

    @Test("Configuration custom mappings, disabled categories, and skip patterns")
    func testConfigurationWiring() throws {
        let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".kram-config-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "x".write(to: root.appendingPathComponent("note.custom"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("skip.txt"), atomically: true, encoding: .utf8)
        try "x".write(to: root.appendingPathComponent("image.png"), atomically: true, encoding: .utf8)
        let config = KRAMConfig(customMappings: ["Documents": ["custom"]], disabledCategories: ["Images"], skipPatterns: ["skip.*"])
        let scanner = FileScanner(classifier: ExtensionClassifier(config: config), config: config)
        let files = try scanner.scan(directory: root)
        #expect(files.map(\.name).sorted() == ["note.custom"])
        #expect(files.first?.category == .documents)
    }
}
