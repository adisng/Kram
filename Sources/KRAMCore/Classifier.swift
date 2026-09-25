import Foundation

/// Protocol all classifiers must conform to.
/// This allows a future SmartClassifier (Laya/Jev-powered) to be swapped in
/// without touching the filesystem engine.
public protocol FileClassifier {
    func classify(file: ScannedFile) -> FileCategory
}

/// Deterministic extension-based classifier.
/// Maps lowercase file extensions to FileCategory.
/// Unknown or missing extensions return .other.
public final class ExtensionClassifier: FileClassifier {

    public init() {}

    // MARK: - Extension Map

    private let extensionMap: [String: FileCategory] = [
        // Documents
        "pdf": .documents, "doc": .documents, "docx": .documents,
        "txt": .documents, "rtf": .documents, "odt": .documents,
        "pages": .documents, "md": .documents, "tex": .documents,
        "wpd": .documents, "key": .documents,

        // Images
        "jpg": .images, "jpeg": .images, "png": .images,
        "gif": .images, "bmp": .images, "tiff": .images,
        "tif": .images, "webp": .images, "heic": .images,
        "heif": .images, "svg": .images, "ico": .images,
        "raw": .images, "cr2": .images, "nef": .images, "arw": .images,

        // Videos
        "mp4": .videos, "mov": .videos, "avi": .videos,
        "mkv": .videos, "wmv": .videos, "flv": .videos,
        "webm": .videos, "m4v": .videos, "mpg": .videos,
        "mpeg": .videos, "3gp": .videos, "ogv": .videos,

        // Audio
        "mp3": .audio, "wav": .audio, "aac": .audio,
        "flac": .audio, "ogg": .audio, "wma": .audio,
        "m4a": .audio, "aiff": .audio, "opus": .audio,
        "mid": .audio, "midi": .audio,

        // Archives
        "zip": .archives, "rar": .archives, "tar": .archives,
        "gz": .archives, "bz2": .archives, "7z": .archives,
        "xz": .archives, "dmg": .archives, "iso": .archives,
        "pkg": .archives, "deb": .archives, "rpm": .archives,

        // Spreadsheets
        "xls": .spreadsheets, "xlsx": .spreadsheets,
        "csv": .spreadsheets, "tsv": .spreadsheets,
        "ods": .spreadsheets, "numbers": .spreadsheets,

        // Code
        "py": .code, "js": .code, "ts": .code, "swift": .code,
        "kt": .code, "java": .code, "c": .code, "cpp": .code,
        "h": .code, "hpp": .code, "cs": .code, "go": .code,
        "rs": .code, "rb": .code, "php": .code, "html": .code,
        "css": .code, "sh": .code, "bash": .code, "zsh": .code,
        "fish": .code, "ps1": .code, "lua": .code, "r": .code,
        "sql": .code, "json": .code, "yaml": .code, "yml": .code,
        "toml": .code, "xml": .code, "ini": .code, "env": .code,
        "m": .code,

        // Fonts
        "ttf": .fonts, "otf": .fonts, "woff": .fonts,
        "woff2": .fonts, "eot": .fonts,

        // eBooks
        "epub": .ebooks, "mobi": .ebooks, "azw": .ebooks,
        "azw3": .ebooks, "fb2": .ebooks,

        // Executables
        "exe": .executables, "bin": .executables, "run": .executables,
    ]

    // MARK: - Classify

    /// Returns the FileCategory for a given scanned file.
    /// Extension matching is case-insensitive. Missing or unknown → .other
    public func classify(file: ScannedFile) -> FileCategory {
        guard !file.ext.isEmpty else { return .other }
        return extensionMap[file.ext.lowercased()] ?? .other
    }

    // MARK: - FUTURE: SmartClassifier hook
    // When --smart flag is passed, instantiate SmartClassifier instead.
    // SmartClassifier accepts ScannedFile, calls local Laya ONNX model,
    // returns FileCategory with confidence. SafetyGuard is NEVER bypassed.
}
