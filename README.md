# Henga 🪝

<div align="center">

**Native macOS Menu Bar App for robust, zero-hassle NAS mounting.**  
*Auto-mount SMB shares without duplicate `/Volumes/share-1` ghost mounts, keychain prompts, or cluttered system views.*

[![macOS 14+](https://img.shields.io/badge/macOS-14.0%2B-blue?logo=apple)](https://apple.com)
[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange?logo=swift)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Build & Tests](https://img.shields.io/badge/Tests-13%2F13%20passed-brightgreen)](#tests)

</div>

---

## Features

- 🚀 **Zero Ghost Mounts:** Uses kernel `-o nobrowse` mounting to keep your macOS "Computer" view completely clean.
- 🪝 **Central Finder Hub:** Mounts all your active shares neatly into your customizable hub (e.g. `~/DiskStation` or `~/Henga`).
- 🔐 **Secure 2FA Support:** Synology DSM 7 WebAPI integration with trusted device token support (`did`).
- 🔄 **Auto-Mount & Reconnect:** Automatically reconnects shares when network returns or Mac wakes from sleep.
- ⚡ **Launch at Login:** Seamless autostart integration via Apple's modern `SMAppService`.

## Quick Start

1. Clone and open in Xcode:
   ```bash
   git clone https://github.com/hehljo/Henga.git
   cd Henga
   open Henga.xcworkspace
   ```
2. Select target **HengaMac** and press **Cmd + R**.
3. Add your NAS in Settings (`Host`, `User`, `Password`, optional `2FA`).

---

## License

MIT License. See [LICENSE](LICENSE) for details.
