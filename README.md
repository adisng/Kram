<div align="center">
  <h1> KRAM · क्रम</h1>
  <p><em><strong>Krama</strong> (क्रम) — Sanskrit for order, sequence, and systematic arrangement.</em></p>
  <p><em>Keep. Rearrange. Automate. Manage. — the ultra-fast, zero-dependency, native Swift file organizer for macOS.</em></p>
</div>

<p align="center">
  <a href="https://github.com/adisng/Kram/stargazers"><img src="https://img.shields.io/github/stars/adisng/Kram?style=flat-square" alt="Stars"></a>
  <a href="https://github.com/adisng/Kram/releases"><img src="https://img.shields.io/github/v/tag/adisng/Kram?label=version&style=flat-square" alt="Version"></a>
  <a href="https://apple.com"><img src="https://img.shields.io/badge/macOS-13.0%2B-black?style=flat-square&logo=apple&logoColor=white" alt="macOS"></a>
  <a href="https://swift.org"><img src="https://img.shields.io/badge/Swift-5.9%2B-orange?style=flat-square&logo=swift&logoColor=white" alt="Swift"></a>
  <a href="https://github.com/adisng/Kram"><img src="https://img.shields.io/badge/Dependencies-Zero-brightgreen?style=flat-square" alt="Dependencies"></a>
  <a href="https://github.com/adisng/Kram"><img src="https://img.shields.io/badge/Privacy-100%25%20Local%20%26%20Offline-blue?style=flat-square&logo=shield" alt="Privacy"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-MIT-lightgrey?style=flat-square" alt="License"></a>
  <a href="https://buymeacoffee.com/singh09aada"><img src="https://img.shields.io/badge/Buy%20Me%20a%20Beer-🍺-ffdd00?style=flat-square&logo=buy-me-a-coffee&logoColor=black" alt="Buy Me a Beer"></a>
  <a href="https://twitter.com/intent/tweet?text=KRAM%20%E2%80%94%20Fast%2C%20safe%20local%20file%20organizer%20for%20macOS&url=https%3A%2F%2Fgithub.com%2Fadisng%2FKram"><img src="https://img.shields.io/badge/share-000000?logo=x&logoColor=white&style=flat-square" alt="Share on X"></a>
</p>

<!-- TODO: replace with a real terminal recording or screenshot of `kr` running the picker + dry-run flow -->
<!-- <p align="center"><img src="./docs/img/kram-hero.png" alt="KRAM Terminal UI" width="1000" /></p> -->

> 🕉 **क्रम (Krama)**: Sanskrit for *order, method, and systematic arrangement*.  
> KRAM brings deliberate order to chaotic directories in milliseconds — sorting messy folders into clean, categorized structures with zero dependencies, absolute filesystem safety, and instant 1-click undos.

## Features

- **Interactive folder picker**: Run `kr` with zero arguments for an in-place terminal directory browser with quick picks, recent folders, and Tab path auto-completion
- **Ironclad safety boundary**: Hard-blocks system roots, user-protected dotfiles, symlink escapes, and path traversal with zero override mechanism
- **True transactional undo**: Every sorting run is recorded in an immutable journal, fully reversible in milliseconds with automatic cleanup of empty category directories
- **Safe by default**: Always previews operations in dry-run mode first, requiring an explicit `--apply` (`-a`) confirmation before moving any file
- **Express aliases & combined flags**: Fast shorthand including `kr dl -a`, `kr desk`, `kr here`, and combined flags like `kr dl -arv`
- **Lifetime usage analytics**: Tracks total runs, files organized, top categories, and frequently organized directories with `kr stats` and `kr last`

## Quick Start

KRAM requires macOS 13.0 or newer and Swift 5.9+.

**Install via Homebrew**

```bash
brew install adisng/tap/kram
```

**Or via script**

```bash
curl -fsSL https://raw.githubusercontent.com/adisng/Kram/main/install.sh | bash
```

The installer builds the release binary, places `kram` and `kr` into `~/.local/bin`, and adds the directory to your shell configuration if needed.

**Run**

```bash
kr                           # Interactive directory picker
kr dl                        # Dry-run preview on ~/Downloads
kr dl -a                     # Organize ~/Downloads
kr dl -ar                    # Apply + scan subdirectories recursively
kr desk -a                   # Organize ~/Desktop
kr docs -a                   # Organize ~/Documents
kr here -a                   # Organize current working directory (pwd)
kr <directory> -a            # Organize any specific folder path
kr undo                      # Undo last transaction (or kr dl -u)
kr last                      # Show details of the last transaction
kr stats                     # Show lifetime statistics
kr help                      # Show help and usage reference
kr --version                 # Show installed version
```

**Preview safely**

```bash
kr dl                        # Preview ~/Downloads (safe dry-run by default)
kr desk                      # Preview ~/Desktop
kr docs                      # Preview ~/Documents
kr here                      # Preview current working directory
kr ~/Projects/Assets         # Preview any folder path
kr dl -v                     # Verbose preview (shows skipped files & reasons)
kr dl -r                     # Recursive dry-run preview
kr dl -n                     # Explicit dry-run flag
```

<details>
<summary><strong>Other install options</strong></summary>

**Build from source**

```bash
# 1. Clone the repository
git clone https://github.com/adisng/Kram.git
cd Kram

# 2. Build optimized release binary
swift build -c release

# 3. Install globally to your local bin
mkdir -p ~/.local/bin
cp .build/release/kram ~/.local/bin/kram
ln -sf ~/.local/bin/kram ~/.local/bin/kr

# 4. Ensure ~/.local/bin is in your PATH
export PATH="$HOME/.local/bin:$PATH"

# 5. Verify installation
kr --version
```

Add `export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc` or `~/.bash_profile` if not already present.

</details>

## Safety

KRAM is architected around strict safety boundaries to eliminate accidental file loss or unexpected mutations:

- **Single Source of Truth Protection**: Handled by [`SafetyGuard.swift`](Sources/KRAMCore/SafetyGuard.swift). All filesystem operations validate paths against system directories (`/System`, `/Library`, `/usr`, `/bin`, `/sbin`, `/private`, `/Applications`, `/Volumes`, `/dev`, `/var`, `/etc`, `/opt`, `/cores`, `/Network`) and user-protected configurations (`~/.ssh`, `~/.config`, `~/.gnupg`, `~/.aws`, `~/.kube`, `.zshrc`, `.bashrc`, `.bash_profile`, `.profile`, `.zprofile`, `.gitconfig`).
- **Symlink Escape & Path Traversal Prevention**: Symlinks that resolve outside the selected boundary directory are blocked (`SafetyViolation.symlinkEscape`). Traversal patterns such as `..` are validated and rejected prior to path resolution.
- **Zero Overwrites**: File collisions are resolved non-destructively by [`OperationPlanner`](Sources/KRAMCore/OperationPlanner.swift), appending incremental suffixes (`name (1).ext`, `name (2).ext`). Files are never overwritten or deleted during organization.
- **Transaction Journaling**: Every completed operation is serialized as an immutable JSON transaction under `~/Library/Application Support/KRAM/transactions/`. Running `kr undo` reverses operations in exact reverse order and removes empty category directories left behind.
- **Read-Only vs Mutating**: Organization runs with `--apply` (`-a`) are the only operations that move files. Dry-run previews, `kr stats`, `kr last`, and `kr help` are strictly read-only and never modify the filesystem.

## Features in Detail

### Dry-Run Preview

Running `kr` against any target defaults to a safe dry-run preview without moving any files. Add `-v` to inspect skipped files (such as hidden files or files already placed in category folders):

```bash
kr dl
```

```text
🐭 KRAM — Dry Run Preview
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Directory:   ~/Downloads
Scanned:     8 files
To move:     8 files
Skipped:     0 files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

➤ 📄 Documents                       2 files
    resume.pdf                    ← resume.pdf
    notes.docx                    ← notes.docx

➤ 🖼  Images                          1 file
    photo.jpg                     ← photo.jpg

➤ 🗜  Archives                       1 file
    project.zip                   ← project.zip

➤ 🎵 Audio                           1 file
    song.mp3                      ← song.mp3

➤ 🎬 Videos                          1 file
    video.mp4                     ← video.mp4

➤ 📊 Spreadsheets                   1 file
    data.csv                      ← data.csv

➤ 💻 Code                            1 file
    script.py                     ← script.py

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run  kram ~/Downloads --apply  to execute.
```

### Apply + Live Move

Pass `-a` (or `--apply`) to execute. KRAM displays a confirmation prompt, then moves files category-by-category with live progress and reports free disk space:

```bash
kr dl -a
```

```text
🐭 KRAM — Ready to Apply
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  8 files will be moved inside ~/Downloads
  Undo anytime:  kram ~/Downloads --undo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Proceed? [y/N]: y

➤ Moving files

  ✓  resume.pdf                    →  Documents/
  ✓  notes.docx                    →  Documents/
  ✓  photo.jpg                     →  Images/
  ✓  project.zip                   →  Archives/
  ✓  song.mp3                      →  Audio/
  ✓  video.mp4                     →  Videos/
  ✓  data.csv                      →  Spreadsheets/
  ✓  script.py                     →  Code/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Done   8 moved · 0 skipped · 0 failed
  Free space: 142.8 GB
  Undo:  kram ~/Downloads --undo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Undo

Run `kr undo` (or `kr dl -u`) to roll back the most recent transaction. Files are restored to their original locations and empty category directories are automatically removed:

```bash
kr undo
```

```text
🐭 KRAM — Undo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Transaction:   26 Sep 2026 · 12:33 AM
Files:         8 to restore
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ✓  resume.pdf                    ←  Documents/
  ✓  notes.docx                    ←  Documents/
  ✓  photo.jpg                     ←  Images/
  ✓  project.zip                   ←  Archives/
  ✓  song.mp3                      ←  Audio/
  ✓  video.mp4                     ←  Videos/
  ✓  data.csv                      ←  Spreadsheets/
  ✓  script.py                     ←  Code/

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Undo complete   8 files restored
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Interactive Directory Picker

Running `kr` without arguments opens the full-screen terminal picker with quick picks, recent directories, folder browsing, and manual path completion:

```bash
kr
```

```text
🐭 KRAM — Where do you want to organize?

  📍 Quick Picks
  ──────────────────────────────────────────
  ❯ 📥 Downloads       ~/Downloads            (48 files)
    🖥  Desktop        ~/Desktop              (12 files)
    📄 Documents       ~/Documents            (187 files)
    📁 Current folder  /Users/aditya/Projects (7 files)

  📂 Recent Folders
  ──────────────────────────────────────────
    📁  ~/Desktop/client-assets               (19 files)
    📁  ~/Projects/webapp                     (31 files)

    🔍 Browse...             (open folder picker)
    ✏️   Type a path...       (enter manually)

──────────────────────────────────────────
  ↑↓ navigate · Enter select · / search · q quit
```

Selecting **Browse...** opens an in-place folder browser scoped to your home directory:

```text
🐭 KRAM — Browse Folders
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  📍 ~/Downloads
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

  ❯ 📁 client-assets                  (19 files)
    📁 invoice-scans                  (4 files)
    🔒 Library                        (protected)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ↑↓ navigate · → enter folder · ← go back
  Enter select highlighted · Esc back · q cancel
```

### Lifetime Stats

`kr stats` displays aggregate counts across all sorting sessions, including files organized, most frequently used directories, and top categories:

```bash
kr stats
```

```text
🐭 KRAM — Stats
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total runs:       12
Files organized:  1912
Last run:         26 Sep 2026 · 1:37 AM
Most used dir:    ~/Downloads

Top categories:
  📄 Documents        896 files
  🖼  Images          617 files
  🗜  Archives        105 files
  📦 Other            88 files
  🎬 Videos           65 files
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Last Transaction

`kr last` prints a summary of the most recently executed transaction:

```bash
kr last
```

```text
🐭 KRAM — Last Transaction
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Directory:   ~/Downloads
Applied:     26 Sep 2026 · 12:33 AM
Files moved: 8

  📄 Documents        2 files
  🖼  Images          1 file
  🗜  Archives        1 file
  🎵 Audio            1 file
  🎬 Videos           1 file
  📊 Spreadsheets     1 file
  💻 Code             1 file

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Undo:  kr dl -u   or   kram ~/Downloads --undo
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## File Category Support

KRAM categorizes files based on their extensions using deterministic mapping in [`ExtensionClassifier`](Sources/KRAMCore/Classifier.swift):

| Category | Extensions |
|---|---|
| **📄 Documents** | `.pdf`, `.doc`, `.docx`, `.txt`, `.rtf`, `.odt`, `.pages`, `.md`, `.tex`, `.wpd`, `.key` |
| **🖼 Images** | `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.tiff`, `.tif`, `.webp`, `.heic`, `.heif`, `.svg`, `.ico`, `.raw`, `.cr2`, `.nef`, `.arw` |
| **🎬 Videos** | `.mp4`, `.mov`, `.avi`, `.mkv`, `.wmv`, `.flv`, `.webm`, `.m4v`, `.mpg`, `.mpeg`, `.3gp`, `.ogv` |
| **🎵 Audio** | `.mp3`, `.wav`, `.aac`, `.flac`, `.ogg`, `.wma`, `.m4a`, `.aiff`, `.opus`, `.mid`, `.midi` |
| **🗜 Archives** | `.zip`, `.rar`, `.tar`, `.gz`, `.bz2`, `.7z`, `.xz`, `.dmg`, `.iso`, `.pkg`, `.deb`, `.rpm` |
| **📊 Spreadsheets** | `.xls`, `.xlsx`, `.csv`, `.tsv`, `.ods`, `.numbers` |
| **💻 Code** | `.py`, `.js`, `.ts`, `.swift`, `.kt`, `.java`, `.c`, `.cpp`, `.h`, `.hpp`, `.cs`, `.go`, `.rs`, `.rb`, `.php`, `.html`, `.css`, `.sh`, `.bash`, `.zsh`, `.fish`, `.ps1`, `.lua`, `.r`, `.sql`, `.json`, `.yaml`, `.yml`, `.toml`, `.xml`, `.ini`, `.env`, `.m` |
| **🔤 Fonts** | `.ttf`, `.otf`, `.woff`, `.woff2`, `.eot` |
| **📚 eBooks** | `.epub`, `.mobi`, `.azw`, `.azw3`, `.fb2` |
| **⚙️ Executables** | `.exe`, `.bin`, `.run` |
| **📦 Other** | Any unrecognized extension or extensionless file (fallback) |

## Support

If KRAM helped bring order to your Mac, give it a star on GitHub, share it with others, or buy me a cold beer 🍺:

<p align="left">
  <a href="https://buymeacoffee.com/singh09aada" target="_blank"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a beer&emoji=🍺&slug=singh09aada&button_colour=FFDD00&font_colour=000000&font_family=Lato&outline_colour=000000&coffee_colour=ffffff" alt="Buy Me a Beer" height="42" /></a>
</p>

## Contributing

Contributions, bug reports, and suggestions are welcome!

```bash
git checkout -b feature/awesome-feature
git commit -m "feat: add awesome feature"
git push origin feature/awesome-feature
```

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
