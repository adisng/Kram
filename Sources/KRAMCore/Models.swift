@_exported import Foundation

// MARK: - File Category

public enum FileCategory: String, Codable, CaseIterable {
    case documents    = "Documents"
    case images       = "Images"
    case videos       = "Videos"
    case audio        = "Audio"
    case archives     = "Archives"
    case spreadsheets = "Spreadsheets"
    case code         = "Code"
    case fonts        = "Fonts"
    case ebooks       = "eBooks"
    case executables  = "Executables"
    case other        = "Other"

    /// Emoji icon for terminal display
    public var icon: String {
        switch self {
        case .documents:    return "📄"
        case .images:       return "🖼 "
        case .videos:       return "🎬"
        case .audio:        return "🎵"
        case .archives:     return "🗜 "
        case .spreadsheets: return "📊"
        case .code:         return "💻"
        case .fonts:        return "🔤"
        case .ebooks:       return "📚"
        case .executables:  return "⚙️ "
        case .other:        return "📦"
        }
    }
}

// MARK: - Scanned File

public struct ScannedFile {
    public let url: URL
    public let name: String
    public let ext: String
    public let isHidden: Bool
    public let isSymlink: Bool
    public let category: FileCategory

    public init(url: URL, name: String, ext: String,
                isHidden: Bool, isSymlink: Bool, category: FileCategory) {
        self.url = url
        self.name = name
        self.ext = ext
        self.isHidden = isHidden
        self.isSymlink = isSymlink
        self.category = category
    }
}

// MARK: - Planned Operation

public struct PlannedOperation: Codable {
    public let id: UUID
    public let sourceURL: URL
    public let destinationURL: URL
    public let category: String
    public let timestamp: Date

    public init(id: UUID = UUID(), sourceURL: URL,
                destinationURL: URL, category: String,
                timestamp: Date = Date()) {
        self.id = id
        self.sourceURL = sourceURL
        self.destinationURL = destinationURL
        self.category = category
        self.timestamp = timestamp
    }
}

// MARK: - Transaction

public struct Transaction: Codable {
    public let id: UUID
    public let rootDirectory: URL
    public let operations: [PlannedOperation]
    public let appliedAt: Date

    public init(id: UUID = UUID(), rootDirectory: URL,
                operations: [PlannedOperation], appliedAt: Date = Date()) {
        self.id = id
        self.rootDirectory = rootDirectory
        self.operations = operations
        self.appliedAt = appliedAt
    }
}

// MARK: - Safety Violation

public enum SafetyViolation: Error, LocalizedError {
    case outsideBoundary(path: String)
    case protectedSystemPath(path: String)
    case protectedUserPath(path: String)
    case symlinkEscape(path: String)
    case pathTraversal(path: String)

    public var errorDescription: String? {
        switch self {
        case .outsideBoundary(let p):      return "Path is outside the allowed boundary: \(p)"
        case .protectedSystemPath(let p):  return "Protected system path: \(p)"
        case .protectedUserPath(let p):    return "Protected user path: \(p)"
        case .symlinkEscape(let p):        return "Symlink escapes boundary: \(p)"
        case .pathTraversal(let p):        return "Path traversal detected: \(p)"
        }
    }
}

// MARK: - KRAM Error

public enum KRAMError: Error, LocalizedError {
    case directoryNotFound(path: String)
    case notADirectory(path: String)
    case permissionDenied(path: String)
    case noTransactionToUndo
    case operationFailed(source: String, reason: String)

    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let p):      return "Directory not found: \(p)"
        case .notADirectory(let p):          return "Not a directory: \(p)"
        case .permissionDenied(let p):       return "Permission denied: \(p)"
        case .noTransactionToUndo:           return "No transaction found to undo."
        case .operationFailed(let s, let r): return "Operation failed for \(s): \(r)"
        }
    }
}

// MARK: - ANSI Colors

public enum ANSI {
    public static let reset  = "\u{001B}[0m"
    public static let bold   = "\u{001B}[1m"
    public static let green  = "\u{001B}[32m"
    public static let yellow = "\u{001B}[33m"
    public static let red    = "\u{001B}[31m"
    public static let cyan   = "\u{001B}[36m"
    public static let gray   = "\u{001B}[90m"
    public static let white  = "\u{001B}[97m"
}
