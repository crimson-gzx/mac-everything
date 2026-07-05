# MacEverything Installation

Recommended download: `MacEverything-v0.10.0.dmg`.

## Quick install

1. Open the DMG.
2. Drag `MacEverything.app` to `Applications`.
3. Open MacEverything from the Applications folder.
4. If macOS blocks it, right-click `MacEverything.app` and choose **Open**.

## Why can the first launch feel slow?

This is expected for the current build. The first launch can be slower than later launches because:

1. macOS verifies apps downloaded from the internet.
2. MacEverything initializes its local SQLite / FTS index files.
3. If you click **Rebuild Index**, it needs to scan your selected index folders. Larger folders take longer.

After the first index is built, normal searches should be much faster. The bottom status bar shows search time, FTS/memory mode, candidate count, and index duration.

## Why does macOS say the app is unsafe?

The current GitHub Release build is not yet signed with an Apple Developer ID certificate and is not notarized by Apple. Gatekeeper may warn that the developer cannot be verified or that the app may be unsafe. This does not automatically mean the app is malware; it means macOS cannot yet verify it as a trusted Developer ID notarized app.

Temporary workaround:

1. Open `Applications`.
2. Find `MacEverything.app`.
3. Right-click the app.
4. Choose **Open**.
5. Confirm **Open** again in the dialog.

Proper fix for public distribution:

- Enroll in the Apple Developer Program.
- Sign the app with a Developer ID Application certificate.
- Submit the DMG to Apple notarization.
- Publish the notarized DMG.

The project already includes notarization notes and a helper script. See [NOTARIZATION.md](NOTARIZATION.md).

## Recommended permission

For complete search results across Desktop, Documents, Downloads, and other protected folders, grant Full Disk Access:

```text
System Settings → Privacy & Security → Full Disk Access → Add MacEverything
```

After granting permission, open MacEverything and click **Rebuild Index** from the menu.

## Shortcut

MacEverything first tries to register `⌘⇧F`.

If that shortcut is unavailable, it automatically tries fallback shortcuts and shows the active one at the bottom of the window.
