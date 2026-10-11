# Contributing to OpenVault

**English** · [Español](CONTRIBUTING.es.md)

Thanks for being here. OpenVault holds people's secrets, so the bar for changes
to the core is high — the guidelines below are mostly about keeping it safe.

## Ground rules

- **Secrets never touch the disk in plain text.** No new path may write a
  decrypted value outside the vault, except the private temporary files that
  `ovault load` already creates (`0700` / `0600`, deleted on exit).
- **No custom cryptography.** Encryption stays on CryptoKit (AES-GCM) and
  CommonCrypto (PBKDF2). Changes to `VaultCrypto.swift` or the vault format need
  a test and a migration for existing vaults.
- **The app and the CLI share `OpenVaultCore`.** Logic both need lives there,
  not duplicated in `App/` or `Sources/ovault/`.
- **Few dependencies.** Ask in an issue before adding a Swift package.
- **Never paste real secrets** into issues, PRs, tests or fixtures.

## Getting set up

You need macOS 26+, Xcode 26+ and [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
git clone https://github.com/Im-Fran/openvault.git
cd openvault
make open
```

The Xcode project is generated from `App/project.yml` and is **not** committed.
Add files under `App/Sources/` and run `make project` again rather than editing
the project in Xcode.

| Command | What it does |
| --- | --- |
| `make test` | Core tests (`swift test`) |
| `make cli` | Build `ovault` in release |
| `make install-cli` | Install `ovault` into `~/.local/bin` |
| `make project` | Generate `App/OpenVault.xcodeproj` |
| `make app` | Build `OpenVault.app` into `build/` |
| `make open` | Build and open the app |
| `make clean` | Remove build artifacts and the generated project |

CI runs `swift test`, builds `ovault`, and builds the app for macOS and the iOS
Simulator with `CODE_SIGNING_ALLOWED=NO`. All of it must pass before a PR can land.

## Where things live

```
Sources/OpenVaultCore/   encryption, vault format, .env parser, .ovaultrc
Sources/ovault/          CLI
Tests/                   core tests
App/                     SwiftUI app for macOS and iOS (project.yml + Sources/)
fastlane/                signing, notarization, DMG, TestFlight
assets/                  branding
```

## Localization

English is the source language; Latin American Spanish (`es-419`) is the
secondary one. New user-facing strings go in English into
`App/Sources/Localizable.xcstrings` with their `es-419` translation. The `ovault`
CLI is English-only. Docs have `.es.md` twins: keep both in sync.

## Branches and commits

`dev` is the default branch and where all work lands. `prd` is the release
branch: it only receives PRs from `dev`, and release tags are cut from it (see
[RELEASING.md](RELEASING.md)).

```sh
git switch dev && git pull
git switch -c feat/ssh-agent-support
```

Commits follow [Conventional Commits](https://www.conventionalcommits.org),
in English and in the imperative:

```
feat(cli): add ovault diff
fix(app): keep the lock screen above the menu bar window
docs: explain .ovaultrc ranges
```

Common types: `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`.
Scopes follow the area touched (`app`, `cli`, `core`, `release`, …).

## Opening a pull request

1. Make sure `make test`, `make cli` and `make app` pass.
2. Push your branch and open a PR against `dev`.
3. Fill in the PR template, and attach screenshots for anything visual —
   light and dark mode.
4. Keep the PR focused. Unrelated cleanups belong in their own PR.

PRs into `dev` are squash-merged; `dev` → `prd` uses a merge commit. Review
threads must be resolved before merging.

## Reporting bugs and requesting features

Use the [issue templates](https://github.com/Im-Fran/openvault/issues/new/choose).
Security vulnerabilities go through [SECURITY.md](../SECURITY.md) instead —
never a public issue.

## Code of Conduct

Taking part in this project means following the
[Code of Conduct](CODE_OF_CONDUCT.md).
