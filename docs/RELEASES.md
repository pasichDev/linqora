# 📦 Releases and Versioning

This document describes how release automation works in the Linqora project and how to manage versions using commit messages.

---

## 🚀 How to Create a New Release

Releases are created automatically upon every merge or push to the `main` branch. The process consists of two stages:
1. **Auto-tagging**: The system analyzes your commits and creates a new git tag (e.g., `v0.1.1`).
2. **GoReleaser**: The system builds binary files for Windows, Linux, and macOS and creates a release on GitHub with a description of the changes.

---

## 🏷 How to Manage Version Numbers

By default, every change creates a **Patch** version. To change the version type, add a special tag to your commit message:

| Change Type | Tag in Commit | Example Result |
| :--- | :--- | :--- |
| **Patch** (fix) | (any text) | `v0.1.0` → `v0.1.1` |
| **Minor** (new feature) | `#minor` | `v0.1.1` → `v0.2.0` |
| **Major** (breaking change) | `#major` | `v0.1.1` → `v1.0.0` |

---

## 📝 How to Create Professional Release Notes

We use commit grouping in GoReleaser. To ensure your changes are categorized correctly, use prefixes (Conventional Commits):

- `feat: added monitor management` → will go to **🚀 Features**
- `fix: fixed memory leak` → will go to **🐛 Bug Fixes**
- `docs: updated API.md` → will go to **📝 Documentation**
- `chore(deps): updated dependencies` → will go to **📦 Dependencies**

If you do not use a prefix, the commit will be placed in the **Other** section.

---

## 🛠 Manual Management

If you need to create a specific version manually:
1. Create a tag locally: `git tag v0.2.5`
2. Push the tag: `git push origin v0.2.5`
3. GitHub Actions will automatically detect the tag and trigger the release build for that specific version.
