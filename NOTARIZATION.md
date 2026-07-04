# Apple Notarization

This project can be distributed in two ways:

- Unsigned/ad-hoc signed local builds for testing.
- Developer ID signed and notarized builds for public distribution outside the Mac App Store.

For GitHub Releases, notarizing the DMG is the recommended path.

## What you need

1. An active Apple Developer Program membership.
2. A **Developer ID Application** certificate installed in Keychain Access.
3. An App Store Connect API key with access to notarization.
4. Xcode Command Line Tools.

Apple describes Developer ID certificates as the certificate type for Mac software distributed outside the Mac App Store. Signing with Developer ID and including a notarization ticket lets Gatekeeper verify the software is not known malware and has not been tampered with.

## One-time credential setup

Create an App Store Connect API key, then save it to your local keychain:

```bash
xcrun notarytool store-credentials "MacEverythingNotary" \
  --key /path/to/AuthKey_XXXXXXXXXX.p8 \
  --key-id XXXXXXXXXX \
  --issuer xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

The profile name `MacEverythingNotary` is used by the notarization script.

## Build, sign, package, notarize

Set your Developer ID identity name first:

```bash
export DEVELOPER_ID_APPLICATION='Developer ID Application: Your Name (TEAMID)'
```

Then run:

```bash
zsh scripts/notarize-release.sh 0.1.0
```

The script does this:

1. Builds the app bundle.
2. Signs `MacEverything.app` with Developer ID and hardened runtime.
3. Creates ZIP and DMG artifacts.
4. Submits the DMG to Apple notarization with `notarytool`.
5. Staples the notarization ticket to the DMG.
6. Verifies the final DMG with Gatekeeper.

## Manual command outline

```bash
zsh build-app.sh

codesign --force --deep --timestamp --options runtime \
  --sign "$DEVELOPER_ID_APPLICATION" \
  dist/MacEverything.app

zsh scripts/package-release.sh 0.1.0

xcrun notarytool submit dist/MacEverything-v0.1.0.dmg \
  --keychain-profile MacEverythingNotary \
  --wait

xcrun stapler staple dist/MacEverything-v0.1.0.dmg
spctl -a -vvv -t open dist/MacEverything-v0.1.0.dmg
```

## Notes

- Keep the `.p8` API key private. Do not commit it.
- Notarization is not the same as Mac App Store review.
- This project is still not sandboxed for Mac App Store distribution.
- If notarization fails, inspect the log with `xcrun notarytool log <submission-id> --keychain-profile MacEverythingNotary`.
