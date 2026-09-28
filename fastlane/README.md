fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac certificates

```sh
[bundle exec] fastlane mac certificates
```

Sync the Developer ID certificate and profile from the match repo

### mac test

```sh
[bundle exec] fastlane mac test
```

Run the core tests

### mac build

```sh
[bundle exec] fastlane mac build
```

Build OpenVault.app into build/

### mac cli

```sh
[bundle exec] fastlane mac cli
```

Build the universal ovault CLI into build/, signed with Developer ID

### mac dmg

```sh
[bundle exec] fastlane mac dmg
```

Package the already-built app into a DMG, without notarizing

### mac release

```sh
[bundle exec] fastlane mac release
```

Build, sign and notarize the DMG and the CLI that ship on GitHub

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
