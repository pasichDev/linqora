# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0] 

- Initial pre-release

## [0.2.0] - 2026-05-07

### Added
- **Security**: Application-layer End-to-End Encryption (E2EE) using AES-256-GCM.
- **Display**: Multi-monitor support with Windows API integration.
- **Files**: Secure remote file browser with path-traversal protection.
- **CLI**: Modular command-line interface with `cobra` (serve, config, auth subcommands).
- **Automation**: GitHub Actions workflow for cross-platform releases and auto-tagging.
- **CI/CD**: Added Pull Request (MR) validation workflow with linting and testing.
- **Linters**: Integrated `golangci-lint` for Go and standard analysis for Flutter.
- **Media**: Comprehensive Windows Media overhaul (SMTC support for "Now Playing").
- **Audio**: Real Master Volume control for Windows using COM/EndpointVolume.
- **Testing**: Comprehensive unit and integration test suite.

### Changed
- Refactored all internal comments and documentation to English.
- Modularized CLI structure for better extensibility.
- Improved WebSocket routing and message handling.