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

- Build the app bundle:

  ```bash
  zsh build-app.sh
  ```

- Consider notarizing a DMG for non-App-Store distribution.
- Create a GitHub release with the built artifact.
