# SynologyMount 🖧

[![Platform: macOS 14+](https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg?style=flat-square)](https://apple.com/macos)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg?style=flat-square)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg?style=flat-square)](LICENSE)
[![Status: Production Ready](https://img.shields.io/badge/status-active-success.svg?style=flat-square)](#)

> **Lightweight, bulletproof native macOS Menu Bar app for seamless, rock-solid Synology DiskStation network share mounting (SMB).**

Stop fighting with hanging Finder connections, missing network drives after sleep/reboot, terminal script hacks, or duplicate phantom mount points (`/Volumes/share-1`, `/Volumes/share-2`).

---

## Key Features

- 🍏 **Pure Menu Bar Extra:** Runs discreetly in your macOS menu bar without cluttering the Dock.
- 🔄 **Smart Auto-Mount & Auto-Reconnect:** Automatically detects network topology changes, sleep/wake cycles, and Wi-Fi switches to restore your shares instantly.
- 🛡️ **Ghost Mount Prevention:** Actively detects and cleans up orphaned mount directories before mounting, preventing confusing `/Volumes/share-1` duplicates.
- 🔍 **Synology Auto-Discovery:** Integrated with Synology DSM FileStation WebAPI to list and configure all shared folders in a single click.
- 🔐 **Full 2-Factor Authentication (2FA / OTP):** Supports Synology DSM 2FA with **"Remember this device"** (`did` device token) — you only enter your 6-digit authenticator code once!
- 🔑 **Apple Keychain Security:** Credentials are encrypted and stored safely within the native macOS Keychain.
- 🌐 **100% Localized (i18n):** Native support for German and English via `Localizable.xcstrings`.

---

## Architecture

- `Sources/SynologyMountCore`: Core domain models, `MountManager`, `MountPointSanitizer`, `NetworkReachability`, `SynologyClient`, `ProfileManager`, and Keychain encryption.
- `Sources/SynologyMountMac`: Modern SwiftUI & AppKit Menu Bar UI (`MenuBarContentView`, `SettingsView`).
- `Sources/SynologyMountCLI`: Fast diagnostics and headless command-line tool.
- `Tests/SynologyMountTests`: Unit and mutation tests covering adversarial inputs, path traversals, injection protection, and 2FA authentication state machines.
- `SynologyMount.xcodeproj`: Native Xcode project.

---

## Quick Start & Installation

### Requirements
- macOS 14.0 (Sonoma) or newer
- Synology DiskStation running DSM 6.x or DSM 7.x (SMB Service enabled)

### Build from Source

```bash
# Clone the repository
git clone https://github.com/hehljo/SynologyMount.git
cd SynologyMount

# Build the Core library and CLI tool
swift build

# Run unit and sabotage tests
swift test

# Launch diagnostics CLI
swift run syno-mount-cli
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
