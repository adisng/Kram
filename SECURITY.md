# Security policy

## Reporting issues

Please report suspected vulnerabilities privately through GitHub’s security advisory flow for this repository. Include the affected command, macOS version, reproduction steps, and whether files were changed. Do not publish exploit details until a fix is available.

## SafetyGuard boundaries

SafetyGuard blocks protected system paths including `/System`, `/Library`, `/usr`, `/bin`, `/sbin`, `/private`, `/Applications`, `/Volumes`, `/dev`, `/var`, `/etc`, `/opt`, `/cores`, and `/Network`.

It also blocks user-sensitive paths including `~/Library`, `~/.ssh`, `~/.config`, `~/Applications`, `~/.gnupg`, `~/.aws`, `~/.kube`, shell profiles, and `.gitconfig`.

Source and destination paths must remain inside the selected directory. Raw `..` traversal is rejected. Symlinks resolving outside the selected boundary are rejected. Cross-volume moves are skipped rather than implemented as copy/delete operations.

SafetyGuard does not provide OS-level sandboxing, protect files changed by other processes after validation, or replace macOS privacy permissions. Users must grant Terminal or the invoking application access to protected user folders when appropriate.
