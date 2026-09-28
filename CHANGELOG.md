# Changelog

## [0.1.0] - 2026-09-28

### Added

- Native Swift macOS CLI binaries: `kram` and `kr`.
- Interactive folder picker with quick picks, recent folders, manual path completion, and back/forward navigation.
- Dry-run previews, confirmation before applying, `--yes`, recursive scanning, verbose output, shell completion, watch mode, stats, and transaction history.
- Transactional undo with safety validation and cleanup of empty category folders.
- Strict filesystem safety boundaries, symlink escape protection, path traversal protection, and collision renaming without overwrites.
- Offline CoreML classification with deterministic extension fallback.

### Fixed

- Installers are now categorized as `Installers` (`.dmg`, `.pkg`, `.app`) instead of `Archives`.
- Structured data extensions (`.json`, `.yaml`, `.yml`, `.toml`) are categorized as `Data` instead of `Code`.
- README command examples, undo semantics, installation guidance, paths, and category documentation were aligned with the implementation.
