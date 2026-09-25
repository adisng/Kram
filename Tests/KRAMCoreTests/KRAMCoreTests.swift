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
}
