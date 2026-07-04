# MacEverything

[中文说明](README.zh-CN.md) · [中文安装说明](INSTALL.zh-CN.md) · [Installation](INSTALL.md) · English

<p align="center">
  <img src="assets/preview.svg" alt="MacEverything preview" width="900">
</p>

A native macOS file-name search utility inspired by Windows Everything.

MacEverything builds a local index first, then searches from memory for near-instant results. It uses macOS FSEvents to keep the index fresh when files are added, moved, renamed, or deleted.

> This is an early prototype. It is designed for direct distribution/self-hosted use first, not the Mac App Store sandbox model yet.

## Download

Download the latest build from GitHub Releases:

```text
https://github.com/crimson-gzx/mac-everything/releases
```

Recommended: download `MacEverything-v0.1.0.dmg`, open it, then drag `MacEverything.app` to `Applications`.

If macOS blocks the app because it was downloaded from the internet, right-click the app and choose **Open**.

## Features

- Fast file and folder search from an in-memory index
- Native SwiftUI macOS interface
- Menu bar app
- Global shortcut with fallback registration, preferring `⌘⇧F`
- Double-click or Enter to open
- Command + Enter to reveal in Finder
- Context menu actions: open, reveal, open parent folder, copy path
- Incremental file-system updates via FSEvents
- Search filters:
  - `report final` — match multiple keywords
  - `ext:pdf` — filter by extension
  - `ext:jpg,png` — filter by multiple extensions
  - `type:file` — files only
  - `type:folder` — folders only

## Requirements

- macOS 14 or later
- Apple Silicon Mac for the included local build script output
- Swift toolchain / Xcode command line tools

## Build and run

```bash
swift run
```

Build a release binary:

```bash
swift build -c release
```

Build a local `.app` bundle:

```bash
zsh build-app.sh
```

Build ZIP and DMG release artifacts:

```bash
zsh scripts/package-release.sh 0.1.0
```

## Notarization

See [NOTARIZATION.md](NOTARIZATION.md).

## Permissions

For best results, grant Full Disk Access:

```text
System Settings → Privacy & Security → Full Disk Access → MacEverything
```

Then reopen the app and rebuild the index from the menu.

Without Full Disk Access, macOS may block some protected locations such as Desktop, Documents, Downloads, or application data folders.

## Index storage

The local index is saved at:

```text
~/Library/Application Support/MacEverything/file-index.plist
```

## Mac App Store note

The current prototype scans the user's home directory and recommends Full Disk Access. That is useful for direct distribution, but not ideal for Mac App Store review.

A future App Store-friendly version should use explicit folder selection and security-scoped bookmarks instead of default home-folder scanning.

## How it differs from Windows Everything

Windows Everything can read NTFS metadata such as the MFT/USN journal. macOS/APFS does not expose an identical public interface for third-party apps.

MacEverything therefore uses a practical native approach:

1. Initial directory scan
2. Binary plist cache
3. In-memory ranked search
4. FSEvents incremental updates

Daily search should feel instant after the first index build, but the initial scan still needs to walk directories.

## Roadmap

- Folder selection UI
- Better keyboard shortcut preferences
- Search result preview
- DMG notarization
- Real `.icns` app icon
- App Store-friendly sandbox mode
- Better ranking and fuzzy matching

## License

MIT
