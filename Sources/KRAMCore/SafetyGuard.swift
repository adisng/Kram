import Foundation

/// SafetyGuard is the security boundary for all KRAM filesystem operations.
/// It MUST be called before every filesystem mutation. It never returns a Bool —
/// it either succeeds silently or throws a typed SafetyViolation.
/// There is no override, bypass, or admin mode.
public final class SafetyGuard {

    public static let shared = SafetyGuard()
    private init() {}

    // MARK: - Protected System Paths

    private let systemProtectedPaths: [String] = [
        "/System", "/Library", "/usr", "/bin", "/sbin",
        "/private", "/Applications", "/Volumes", "/dev",
        "/var", "/etc", "/opt", "/cores", "/Network"
    ]

    // MARK: - Protected User Paths

    private func userProtectedPaths() -> [String] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(home)/Library",
            "\(home)/.ssh",
            "\(home)/.config",
            "\(home)/Applications",
            "\(home)/.gnupg",
            "\(home)/.aws",
            "\(home)/.kube",
            "\(home)/.gitconfig",
            "\(home)/.zshrc",
            "\(home)/.bashrc",
            "\(home)/.bash_profile",
            "\(home)/.profile",
            "\(home)/.zprofile"
        ]
    }

    // MARK: - Path Protection Query

    public func isProtectedPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return systemProtectedPaths.contains(where: { path == $0 || path.hasPrefix($0 + "/") })
            || userProtectedPaths().contains(where: { path == $0 || path.hasPrefix($0 + "/") })
    }

    // MARK: - Public Validation Entry Point

    /// Validates that a source → destination move is safe within the given boundary.
    /// Throws SafetyViolation if any check fails.
    public func validate(source: URL, destination: URL, boundary: URL) throws {
        let boundaryPath = boundary.standardizedFileURL.path

        // Check for path traversal in raw strings before resolution
        try checkPathTraversal(url: source)
        try checkPathTraversal(url: destination)

        // Standardize
        let sourcePath = source.standardizedFileURL.path
        let destPath   = destination.standardizedFileURL.path

        // Check system protected paths
        try checkSystemPaths(path: sourcePath)
        try checkSystemPaths(path: destPath)

        // Check user protected paths
        try checkUserPaths(path: sourcePath)
        try checkUserPaths(path: destPath)

        // Check both are inside boundary
        try checkInsideBoundary(path: sourcePath, boundary: boundaryPath)
        try checkInsideBoundary(path: destPath, boundary: boundaryPath)

        // Resolve symlinks on source and re-validate
        let resolvedSource = source.resolvingSymlinksInPath().standardizedFileURL.path
        if resolvedSource != sourcePath {
            // It's a symlink — check resolved target is still inside boundary
            guard resolvedSource.hasPrefix(boundaryPath + "/") || resolvedSource == boundaryPath else {
                throw SafetyViolation.symlinkEscape(path: resolvedSource)
            }
            try checkSystemPaths(path: resolvedSource)
            try checkUserPaths(path: resolvedSource)
        }
    }

    // MARK: - Private Checks

    private func checkPathTraversal(url: URL) throws {
        let raw = url.path
        if raw.contains("/../") || raw.hasSuffix("/..") || raw == ".." {
            throw SafetyViolation.pathTraversal(path: raw)
        }
        // Check each component
        for component in url.pathComponents {
            if component == ".." {
                throw SafetyViolation.pathTraversal(path: raw)
            }
        }
    }

    private func checkSystemPaths(path: String) throws {
        for protected in systemProtectedPaths {
            if path == protected || path.hasPrefix(protected + "/") {
                throw SafetyViolation.protectedSystemPath(path: path)
            }
        }
    }

    private func checkUserPaths(path: String) throws {
        for protected in userProtectedPaths() {
            if path == protected || path.hasPrefix(protected + "/") {
                throw SafetyViolation.protectedUserPath(path: path)
            }
        }
    }

    private func checkInsideBoundary(path: String, boundary: String) throws {
        let insideBoundary = path == boundary || path.hasPrefix(boundary + "/")
        if !insideBoundary {
            throw SafetyViolation.outsideBoundary(path: path)
        }
    }
}
