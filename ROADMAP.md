# 🗺️ Project Roadmap and TODO

This document outlines the development plan and key tasks for the **Linqora** project. Tasks are organized by milestone phases.

---

## ✅ Completed Milestones

### 🛡️ Security & Reliability (v0.2.0)
- [x] **End-to-End Encryption (E2EE)**: Implemented AES-256-GCM for all WebSocket communication.
- [x] **Comprehensive Testing**: Added unit and integration tests for all core modules.
- [x] **CI/CD Pipeline**: Automated cross-platform builds and releases via GitHub Actions and GoReleaser.
- [x] **Documentation Standard**: All internal code and comments refactored to professional English.

### 🖥️ Remote Management Tools
- [x] **Multi-monitor Management**: Switching, primary monitor control, and enumeration.
- [x] **Remote File Browser**: Secure browsing, reading, and writing files remotely.
- [x] **Modular CLI**: New command-line tool with subcommands for serve, config, and auth management.

### 🚀 Initial Foundation (v0.1.0)
- [x] **Windows Support**: Full cross-platform implementation.
- [x] **System Monitoring**: GPU, CPU, and RAM metrics collection.
- [x] **Media & Power**: Volume control and remote power management (shutdown/restart).

---

## 🚀 Current Focus & TODO

### 📖 Documentation & UX
- [/] **Host API Documentation**: Internal GoDoc complete. Need to export to external wiki/site.
- [ ] **Usage Guide**: Detailed instructions for setup, certificates, and E2EE configuration.
- [ ] **Official Website**: Project landing page and documentation hub.

---

## 🔮 Future Tasks (Backlog)

- [ ] **GUI for Linqora Host**: System tray integration and settings window.
- [ ] **Linux/macOS Advanced Features**: Extend monitor/file logic to other platforms.
- [ ] **Plugin System**: Allow third-party extensions for custom metrics/commands.

---

## 🏷 Suggested Labels

- `enhancement` – Feature improvements and optimizations
- `security` – Security-related improvements
- `documentation` – Tasks related to documentation
- `platform-support` – Platform-specific support (Windows, Linux, etc.)
- `UI` – Related to CLI or GUI development
