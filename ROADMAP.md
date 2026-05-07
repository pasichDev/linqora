# 🗺️ Project Roadmap and TODO

This document outlines the development plan and key tasks for the **Linqora** project. Tasks are organized by milestone phases.

---

## ✅ Pre-Release Tasks for v0.1.0

- [x] Review the codebase of `LinqoraHost` (Standardized documentation and audited internal modules)
- [x] Review and optimize collectors for metrics and media data
- [x] Add **Windows** support for `LinqoraHost` (Cross-platform implementation completed)
- [x] Add support for GPU statistics collection
- [x] Investigate and implement mouse emulation capabilities
- [x] Integrate battery/power status into the host information

---

## 🚀 Post-Release Tasks (after v0.1.0)

- [x] Implement a **task and script scheduler**:
  - [x] Register scripts on the host
  - [x] Execute scripts via the client with real-time output streaming
- [/] Create documentation for `LinqoraHost` API (Internal GoDoc completed, external docs pending)
- [ ] Develop an official website for the project
- [ ] Write a detailed usage guide, including:
  - [ ] Setup instructions
  - [ ] Certificate usage and configuration
- [x] Implement a separate CLI command for:
  - [x] Managing configuration
  - [x] Managing the list of authorized devices

---

## 🔮 Future Tasks (Backlog)

- [ ] Develop a GUI version of `LinqoraHost` (System tray integration and settings window)
- [x] Explore further improvements to security (e.g., end-to-end encryption for specific data)
- [x] Add support for multi-monitor management (switching, resolution control)
- [x] Implement remote file browser/transfer capabilities

---

## 🏷 Suggested Labels

You may use labels in the repository to categorize tasks:

- `enhancement` – Feature improvements and optimizations
- `security` – Security-related improvements
- `documentation` – Tasks related to documentation
- `platform-support` – Platform-specific support (Windows, Linux, etc.)
- `UI` – Related to CLI or GUI development
