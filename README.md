<div align="center">

# 🐭 KRAM
### **Keep. Rearrange. Automate. Manage.**

*The ultra-fast, zero-dependency, native Swift file organizer for macOS.*  
*Built for terminal lovers with a clean Mole (`mo`)-inspired aesthetic.*

[![macOS](https://img.shields.io/badge/macOS-13.0%2B-black?style=for-the-badge&logo=apple&logoColor=white)](https://apple.com)
[![Swift](https://img.shields.io/badge/Swift-5.9%2B-orange?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org)
[![Dependencies](https://img.shields.io/badge/Dependencies-Zero-brightgreen?style=for-the-badge)](https://github.com/adisng/Kram)
[![Privacy](https://img.shields.io/badge/Privacy-100%25%20Local%20%26%20Offline-blue?style=for-the-badge&logo=shield)](https://github.com/adisng/Kram)
[![License](https://img.shields.io/badge/License-MIT-lightgrey?style=for-the-badge)](LICENSE)

<br/>

```
      __   ___  __        __   ___ 
     |  \ |__  /__` |__/ |  | |__  
     |__/ |___ .__/ |  \ |__| |___ 
                                   
      kram · Keep Rearrange Automate Manage
```

<br/>

[Overview](#-overview) •
[Features](#-key-features) •
[Interactive UI](#-interactive-terminal-ui) •
[CLI Quick Shortcuts](#-short-aliases--command-shorthand) •
[Installation](#-installation) •
[Safety Engine](#-safety-first-architecture) •
[License](#-license)

---

</div>

<br/>

## ✨ Overview

Your `Downloads` and `Desktop` folders shouldn't look like a landfill. 

**KRAM** is a lightning-fast macOS command-line file organizer written in native Swift. It declutters messy directories in milliseconds by categorizing files into clean folders (`Documents/`, `Images/`, `Spreadsheets/`, `Code/`, `Archives/`, `Videos/`, `Audio/`, etc.) — featuring dry-run previews, non-destructive collision avoidance, live terminal progress, an interactive folder navigator, and **instant 1-click transaction undos**.

No Python runtime. No Node.js. No dependencies. No cloud telemetry. 100% offline & local.

---

## 🚀 Key Features

- **🐭 Mole-Inspired Terminal UI**: Minimalist box-drawing borders (`━`), clean emoji category badges, 30-column aligned directional arrows (`→` and `←`), live file progress, and disk space calculation.
- **🛡️ Ironclad Safety Boundary**: `SafetyGuard` enforces strict boundaries. It refuses to touch system paths (`/System`, `/Library`, `/usr`), user protected paths (`~/.ssh`, `~/.config`), symlink escapes, or path traversal exploits (`..`).
- **↩️ True Transactional Undo**: Every move operation is logged as an immutable JSON transaction. Reverse any sorting run completely with `kr undo`.
- **⌨️ Interactive Directory Picker**: Run `kr` with no arguments to get an interactive folder browser with quick picks, recent folders, and Tab path auto-completion.
- **⚡️ Express Aliases & Combined Flags**: Use `kr dl -a`, `kr desk`, `kr here`, or combined flags like `kr dl -arv` for effortless power-user flows.
- **📊 Lifetime Usage Stats**: Track total runs, files organized, top categories, and frequently used folders with `kr stats` and `kr last`.

---

## 🖥 Terminal Experience

### 1. Interactive Directory Picker (`kr` with no arguments)
Run `kr` anywhere with zero arguments to launch the visual folder browser:

```text
🐭 KRAM — Where do you want to organize?

  📍 Quick Picks
  ──────────────────────────────────────────
  ❯ 📥 Downloads       ~/Downloads            (48 files)
    🖥  Desktop         ~/Desktop              (12 files)
    📄 Documents       ~/Documents            (187 files)
    📁 Current folder  /Users/aditya/Projects (7 files)

  📂 Recent Folders
  ──────────────────────────────────────────
    📁 ~/Desktop/client-assets                (19 files)
    📁 ~/Projects/webapp                      (31 files)

  🔍 Browse...             (open folder picker)
  ✏️  Type a path...       (enter manually)

  ↑↓ navigate · Enter select · / search · q quit
```

---

### 2. Dry-Run Preview (Safe by default)
`kram` always defaults to a dry-run preview before touching anything:

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

➤ 📄 Documents                              2 files
    resume.pdf                    ← resume.pdf
    notes.docx                    ← notes.docx

➤ 🖼  Images                                 1 file
    photo.jpg                     ← photo.jpg

➤ 🗜  Archives                              1 file
    project.zip                   ← project.zip

➤ 🎵 Audio                                 1 file
    song.mp3                      ← song.mp3

➤ 🎬 Videos                                1 file
    video.mp4                     ← video.mp4

➤ 📊 Spreadsheets                          1 file
    data.csv                      ← data.csv

➤ 💻 Code                                  1 file
    script.py                     ← script.py

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Run  kram ~/Downloads --apply  to execute.
```

---

### 3. Apply with Confirmation & Live Move Progress

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

---

### 4. Instant 1-Click Undo

Made a mistake? Reversed in a fraction of a second:

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

---

## ⚡️ Short Aliases & Command Shorthand

KRAM installs both `kram` and `kr`. Power users can leverage quick target aliases and combined flags:

### Quick Targets
| Target | Expands To | Example |
|---|---|---|
| `dl` | `~/Downloads` | `kr dl -a` |
| `desk` | `~/Desktop` | `kr desk -a` |
| `docs` | `~/Documents` | `kr docs -a` |
| `here` | Current Directory (`pwd`) | `kr here -a` |

### Combined Flags
- `kr dl -a` $\rightarrow$ Apply organization
- `kr dl -r` $\rightarrow$ Recursive organization (scans subdirectories)
- `kr dl -ar` $\rightarrow$ Apply + recursive combined
- `kr dl -v` $\rightarrow$ Verbose preview (shows skipped hidden files & reasons)
- `kr dl -n` $\rightarrow$ Explicit dry-run
- `kr dl -u` $\rightarrow$ Undo last operation on Downloads

### Commands
- `kr undo` $\rightarrow$ Reverses the last transaction regardless of directory
- `kr last` $\rightarrow$ Displays full breakdown of the last transaction log
- `kr stats` $\rightarrow$ Shows lifetime statistics and top categories
- `kr help` $\rightarrow$ Quick reference cheat-sheet

---

## 📦 Installation

### ⚡️ 1-Line Install (Recommended)

Paste this into your macOS Terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/adisng/Kram/main/install.sh | bash
```

This automatically fetches the latest source, compiles the release binary, places `kram` and `kr` into `~/.local/bin`, and adds it to your `$PATH`.

---

### Homebrew (Coming Soon)

```bash
brew tap adisng/tap
brew install kram
```

---

### Install from Source

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

# 4. Verify installation
kr --version
```

---

## 🛡 Safety-First Architecture

KRAM is designed around a zero-data-loss guarantee:

1. **No Overwrite Policy**: Destination filename collisions are automatically resolved by appending `(1)`, `(2)`, etc. Files are **never** overwritten or deleted.
2. **Strict Boundary Enforcement (`SafetyGuard`)**: All filesystem operations are inspected before execution:
   - System directories (`/System`, `/Library`, `/usr`, `/private`, etc.) are hard-blocked.
   - User critical directories (`~/.ssh`, `~/.config`, shell dotfiles) are shielded.
   - Symlinks resolving outside the target directory are rejected immediately.
3. **Transaction Journaling**: Transactions are serialized as formatted JSON under:
   `~/Library/Application Support/KRAM/transactions/`
   Undo reads from this journal, reversing files in reverse order and deleting empty category folders.

---

## 📊 File Category Support

KRAM organizes over 60+ common file extensions out of the box:

| Category | Extensions |
|---|---|
| **📄 Documents** | `.pdf`, `.doc`, `.docx`, `.txt`, `.rtf`, `.odt`, `.pages`, `.md`, `.tex`, `.key` |
| **🖼 Images** | `.jpg`, `.jpeg`, `.png`, `.gif`, `.bmp`, `.tiff`, `.webp`, `.heic`, `.heif`, `.svg`, `.raw` |
| **🎬 Videos** | `.mp4`, `.mov`, `.avi`, `.mkv`, `.wmv`, `.flv`, `.webm`, `.m4v`, `.mpg` |
| **🎵 Audio** | `.mp3`, `.wav`, `.aac`, `.flac`, `.ogg`, `.wma`, `.m4a`, `.opus` |
| **🗜 Archives** | `.zip`, `.rar`, `.tar`, `.gz`, `.7z`, `.dmg`, `.iso`, `.pkg` |
| **📊 Spreadsheets** | `.xls`, `.xlsx`, `.csv`, `.tsv`, `.numbers`, `.ods` |
| **💻 Code** | `.py`, `.js`, `.ts`, `.swift`, `.java`, `.cpp`, `.c`, `.go`, `.rs`, `.html`, `.css`, `.sh`, `.json`, `.yaml` |
| **🔤 Fonts** | `.ttf`, `.otf`, `.woff`, `.woff2` |
| **📚 eBooks** | `.epub`, `.mobi`, `.azw`, `.azw3` |
| **⚙️ Executables** | `.exe`, `.bin`, `.run` |

---

## 🤝 Contributing

Contributions, feature requests, and suggestions are welcome!
Feel free to open an issue or submit a pull request.

```bash
git checkout -b feature/awesome-feature
git commit -m "feat: add awesome feature"
git push origin feature/awesome-feature
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

<div align="center">

Made with 🐭 for macOS by [Aditya Singh](https://github.com/adisng)

</div>
