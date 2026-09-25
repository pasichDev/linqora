# Linqora

<div align="center">

[![Donate on Ko-fi](https://img.shields.io/badge/Ko--fi-donate-orange?logo=ko-fi)](https://ko-fi.com/pasichdev)
[![Support via Donatello](https://img.shields.io/badge/Donatello-support-blueviolet)](https://donatello.to/pasichDev)
[![GitHub stars](https://img.shields.io/github/stars/pasichDev/linqora?style=social)](https://github.com/pasichDev/linqora/stargazers/)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

<img src="docs/assets/logo_linqora.png" alt="Linqora Logo" width="200"/>

**Linqora — Smart interaction with your computer.**  
**Monitor system resources, control media playback, manage sound and more — directly from your phone.**

[English](README.md) | [Українська](./docs/translated/README_UK.md)

</div>

---

> [!WARNING]
> **Archived. Linqora is an experiment and is no longer maintained.**
> Do not run Linqora Host on a network you do not fully trust. In the default configuration
> (no shared secret) its REST API is not authenticated: any device on the same network can
> shut the computer down, kill processes, type keystrokes and run scripts. Device pairing
> relies on a device id only, and the bundled TLS key is public. The released builds
> (up to v0.1.6) have these issues and will not be fixed.

<a name="english"></a>

## About

Linqora is an open-source tool that enables seamless interaction between your mobile device and computer. Monitor your system resources, control media playback, manage power settings, and more - all from your smartphone.

### Components

The project consists of two main components:

- **[Linqora Host](./LinqoraHost)** - Server application for your computer 
- **[Linqora Remote](./linqoraremote)** - Mobile client application (Android)

### Features

- 📊 Real-time system resource monitoring
- 🔊 Media and volume control
- ⚡ Power management (shutdown, restart, lock)
- 🔐 Device pairing with manual approval on the computer (device id only; optional shared secret)
- 🛡️ Optional AES-256-GCM message encryption (off by default; not supported by the mobile client)
- 🖥️ **Multi-monitor management** (enumeration, primary monitor control)
- 📂 **Remote file browser** (read/write files in the home directory)
- ⌨️ **Powerful CLI** for server management and configuration
- 🌐 Local network discovery
- 🔄 WebSocket-based communication

## Status

The project is archived: no new releases, fixes or answers to issues. The code stays available
for reference under the MIT license.

## License

MIT © [pasichDev](https://github.com/pasichDev), see [LICENSE](./LICENSE).

