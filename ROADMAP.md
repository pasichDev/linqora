# 🗺️ Project Roadmap

Development plan for **Linqora**. Tasks are grouped by milestone. Items within a milestone are roughly priority-ordered.

---

## ✅ Completed

### v0.1.0 — Initial Foundation
- [x] Windows support
- [x] System monitoring (CPU, GPU, RAM)
- [x] Media & volume control, remote power management

### v0.2.0 — Security & Remote Management
- [x] End-to-End Encryption (AES-256-GCM)
- [x] Multi-monitor management (Windows)
- [x] Remote file browser (path-traversal protected)
- [x] Modular CLI (`serve`, `config`, `auth` subcommands)
- [x] HMAC-SHA256 challenge-response authentication
- [x] Native GUI with system tray (Fyne)
- [x] Windows auto-start (registry Run key)
- [x] CI/CD — cross-platform builds, GoReleaser, PR linting
- [x] Comprehensive unit & integration tests
- [x] WebSocket API documentation (`API.md`, `SETUP.md`)

### v0.3.0 — Input & Clipboard
- [x] **Remote keyboard** — special keys and hotkeys via Win32/xdotool/osascript
- [x] **Clipboard sync** — bidirectional with session history panel (newest-first, max 50 entries, per-entry copy): host→phone (clipboard room), phone→host (`clipboard_set`)
- [x] **Improved touchpad** — pinch-to-zoom gesture, double-click, configurable scroll
- [x] **Screen wake / display brightness** — sleep, wake and brightness 0-100 (multi-platform stubs)

### v0.4.0 — System Insights
- [x] **Process manager** — list running processes (PID, CPU%, RSS, status) and kill by PID; also exposed via REST `GET /api/v1/processes` and `POST /api/v1/processes/kill`
- [x] **CPU temperature** — WMI on Windows; stub on others
- [x] **Startup app manager** — list HKCU/HKLM Run entries and toggle via remote (Windows)
- [x] **Battery alerts** — threshold-based push to all clients; drain-cycle aware, configurable via `battery_alert_config`
- [x] **Disk I/O & network stats** — bytes/s read-write and sent-recv via `gopsutil`; broadcast in `metrics` room and displayed in Flutter monitoring view

### v0.4.1 — Input Polish & Platform Caps
- [x] **Keyboard text input** — `TypeText()` via Win32 `SendInput` + `KEYEVENTF_UNICODE` (Windows), `xdotool type` (Linux), `osascript keystroke` (macOS); retired deprecated `keybd_event`
- [x] **QR pairing — local IP** — `getLANIP()` helper; `restQR` now returns LAN IPv4 instead of hostname
- [x] **Platform capability advertisement** — `internal/capabilities` package; server responds to `platform_caps` WS request with a per-platform feature map (`keyboard_type`, `startup_manager`, `monitor_control`, etc.)
- [x] **Flutter: keyboard_type + text input UI** — `typeText()` in `KeyboardController`, text input row in `KeyboardView`, `keyboard_type` WS message wired end-to-end
- [x] **Flutter: PlatformCapsController** — requests caps after auth, stores feature flags; dashboard `MenuOption.requiredCap` filters items the current host platform does not support; backlight WMI detection on Windows hides brightness UI on desktops

### v0.5.0 — Cross-Platform Media & Input (partial)
- [x] **Linux media** — volume via `amixer`, playback/info via `playerctl`; falls back to `xdotool` XF86 keys when playerctl is absent
- [x] **macOS media** — volume and playback via `osascript`; Now Playing from Music/iTunes
- [x] **Linux multi-monitor** — `xrandr`-based monitor list, resolution change, and primary selection
- [ ] **macOS monitor control** — brightness and display management via `osascript`/`ddcctl`
- [ ] **iOS client** — Flutter target already declared in `pubspec.yaml`; needs platform permissions and TestFlight setup
- [ ] **Android notification mirror** — forward host desktop notifications to phone as local notifications

---

## 🚀 v0.6.0 — Discovery & Connectivity

> Goal: let users pair and connect without typing IPs, and work beyond the local Wi-Fi.

- [x] **QR code in host GUI** — display a QR code in the Fyne window that encodes `linqora://ip:port`; scan from app to connect without mDNS
- [x] **Auto-update for LinqoraHost** — check GitHub releases API and prompt for update from GUI and CLI
- [x] **Multi-host support** — save and switch between multiple paired hosts from the app (backend already has mDNS; Flutter needs saved-host list)
- [ ] **Relay / tunnel mode** — optional self-hostable relay server for connections over the internet (WireGuard or custom TURN-like)

---

## 🔧 v0.7.0 — Automation & Extensibility

> Goal: let power users build on top of Linqora.

- [x] **Script CRUD from app** — create, edit, and delete scripts directly from the phone (`script_add`, `script_update`, `script_delete` wired end-to-end; edit/delete actions added to script row)
- [x] **Scripts terminal console** — second tab in ScriptsView with direct shell command input and streamed output; backend `shell_exec` WS type
- [x] **Default scripts** — seed platform-appropriate example scripts (systeminfo, ipconfig, etc.) on first run so the list is never empty
- [x] **Scheduled scripts** — cron-like triggers (time-based) executed server-side; extend `internal/scheduler`
- [x] **Webhook / HTTP REST endpoint** — extend existing REST (`/api/v1/*`) with more resources for home-automation bridges (Home Assistant, etc.)
- [ ] **Plugin system** — third-party Go plugins that expose custom WS message types and Flutter widget cards

---

## 📖 Ongoing

- [ ] **Official website** — project landing page and documentation hub
- [x] **Onboarding wizard** — guided first-run flow; includes "How It Works" page with per-platform setup guide (Windows/Linux/macOS)
- [ ] **i18n expansion** — currently EN / UK / DE; accept community translations

---

## 🏷 Labels

| Label | Meaning |
|---|---|
| `enhancement` | Feature improvements and optimisations |
| `security` | Security-related improvements |
| `documentation` | Documentation tasks |
| `platform-support` | Platform-specific work (Windows, Linux, macOS, iOS) |
| `UI` | CLI or GUI changes |
| `plugin` | Plugin system and extensibility |
