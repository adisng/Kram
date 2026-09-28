# Changelog

## [2.0.0] - 2026-09-28

### Added

- Watch mode with debounced filesystem monitoring.
- Bundled offline CoreML classification with deterministic fallback and classifier consistency across CLI and watch mode.
- User configuration for custom mappings, disabled categories, and filename skip globs.
- Lifetime stats, recent folders, shell completions, and improved interactive folder navigation.
- `Installers` and `Data` categories.

### Fixed

- Undo now selects transactions by applied timestamp and directory scope, while skipping corrupt journal entries.

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
