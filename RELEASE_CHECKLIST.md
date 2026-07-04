# Release Checklist

Before publishing a public release:

- Add a real app icon.
- Add screenshots or a short demo GIF to the README.
- Run `swift build -c release`.
- Run the search self-test:

  ```bash
  swiftc Sources/MacEverything/SearchTypes.swift Tests/SearchEngineSelfTest.swift -o /tmp/MacEverythingSearchSelfTest
  /tmp/MacEverythingSearchSelfTest
  ```

- Build ZIP and DMG artifacts:

  ```bash
  zsh scripts/package-release.sh 0.1.0
  ```

- For public distribution, sign and submit the DMG to Apple using `scripts/notarize-release.sh`.
- Create or update the GitHub release with the built artifacts.
