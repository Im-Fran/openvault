<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/svg/lockup-dark.svg">
  <img src="assets/brand/svg/lockup-light.svg" width="480" alt="OpenVault">
</picture>

**A secrets manager for developers on macOS: `.env` files, API keys, SSH and GPG keys in an encrypted vault, with a CLI to use them in your projects.**

[![License](https://img.shields.io/github/license/Im-Fran/openvault)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/Im-Fran/openvault/ci.yml?branch=dev&label=CI)](https://github.com/Im-Fran/openvault/actions)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6-orange)

</div>

<div align="center">

**English** · [Español](README.es.md)

</div>

---

## 📖 Overview

Development secrets tend to end up scattered across unencrypted `.env` files, notes, and `~/.ssh` folders on several machines. OpenVault keeps them in **a single encrypted vault** protected by a master password (and Touch ID), along with the passphrases you need to use each key.

It has two parts that share the same core (`OpenVaultCore`):

- **OpenVault.app** — a native SwiftUI app to create, view, and organize secrets by type and project.
- **`ovault`** — a CLI you add to any repository to inject the project's secrets as environment variables, without the `.env` ever existing on disk.

Both read the same file directly, so the CLI works even when the app is closed, and the app instantly reflects whatever the CLI writes.

---

## ✨ Features

- **Encrypted vault** — AES-256-GCM with a key derived via PBKDF2-SHA256 (600,000 iterations). Nothing is stored in plain text.
- **Touch ID** — unlock with the key stored in a biometry-protected Keychain item.
- **Item types** — `.env` files, individual secrets, passwords (username, password, URL), SSH keys, GPG keys, arbitrary files (`.p12`, `.p8`, JSON… encrypted byte for byte and exportable back to disk), and others.
- **Projects** — group items by project; the CLI resolves the project from a `.openvault` file in the repo.
- **`ovault run`** — run any command with the project's secrets as environment variables.
- **SSH keys** — generate ed25519 keys, view the public key and fingerprint, and export to `~/.ssh`.
- **GPG keys** — view the fingerprint and identity without importing the key into your keyring.
- **Drag and drop** — drop a `.env`, `id_*`, or `.asc` file onto the window and its type is detected.
- **Hidden values** — revealed with the eye button or by holding ⌥.
- **Secure clipboard** — copied values are marked as concealed for clipboard managers and cleared automatically.
- **Auto-lock** — after inactivity, when the Mac sleeps, and when the screen locks.
- **Languages** — available in English and Spanish (Latin America).

---

## 🛠 Stack

| Layer | Technology |
|------|-----------|
| App | SwiftUI (macOS 26+) |
| CLI | Swift + [swift-argument-parser](https://github.com/apple/swift-argument-parser) |
| Cryptography | CryptoKit (AES-GCM), CommonCrypto (PBKDF2) |
| Biometrics | LocalAuthentication + Keychain |
| Xcode project | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| CI | GitHub Actions (macOS 26) |

---

## 📋 Requirements

- **macOS 26** or later
- **Xcode 26** or later (Swift 6.2+)
- **XcodeGen** — `brew install xcodegen`
- Optional: **gpg** (to view GPG fingerprints); `ssh-keygen` ships with macOS

---

## 🚀 Getting started

### 1. Clone

```bash
git clone https://github.com/Im-Fran/openvault.git
cd openvault
```

### 2. Build and open the app

```bash
make open
```

On first launch it asks you to create a master password. **It cannot be recovered if you forget it.**

> Touch ID requires the app to be signed. Change `DEVELOPMENT_TEAM` in `App/project.yml` to your Team ID if you build with a different account; without signing, the Touch ID button doesn't appear.

### 3. Install the CLI

```bash
make install-cli    # installs ovault into ~/.local/bin
```

Make sure `~/.local/bin` is on your `PATH`, or use `make install-cli PREFIX=/usr/local`.

---

## 💻 CLI usage

```bash
cd my-project
ovault init                        # creates .openvault with the project name (safe to commit)
ovault import .env                 # imports a .env into the project
echo "sk_live_..." | ovault set STRIPE_KEY   # without VALUE it reads stdin (stays out of shell history)
ovault run -- npm run dev          # runs with the secrets as environment variables
ovault load my-project -- npm run dev    # same, naming the project; includes passwords and files
eval "$(ovault load my-project)"   # loads the variables into the current shell
ovault get STRIPE_KEY              # prints a value
ovault get deploy_key --passphrase # prints an item's passphrase
ovault get cert.p12 > cert.p12     # a file item is written raw (binary)
ovault export --format json        # combined environment (env | json)
ovault list                        # project items, without values (-a for all)
```

The project can also be declared by hand in a `.ovault` file (plain text, supports `#` comments; it only names the project and never contains secrets):

```ini
project-name=my-project
```

With it, `ovault load -- npm run dev` and `eval "$(ovault load)"` don't need the name. It is looked up in the current directory and upwards; if a directory contains both `.ovault` and `.openvault`, `.ovault` wins.

#### Automatic loading (optional)

```bash
eval "$(ovault hook zsh)"   # in ~/.zshrc (or `ovault hook bash` in ~/.bashrc)
```

When you enter a directory with a `.ovault` (or one of its subdirectories), the hook loads the project's variables; when you leave, it unsets them and deletes the temporary files. It never prompts for the master password: it only loads if `OPENVAULT_PASSWORD` is set; with the vault locked it warns once, and running `eval "$(ovault load)"` is enough to unlock and load. Note: a third-party repository with a `.ovault` that names one of your projects would receive that environment when you enter it; the hook warns every time it loads.

Every command accepts `--project <name>` so it doesn't depend on `.ovault`/`.openvault`. If an individual secret and a variable from a `.env` share the same name, the individual secret wins.

`ovault load` also exposes **passwords** (`NAME` and `NAME_USERNAME`; a name like "Postgres prod" becomes `POSTGRES_PROD`) and **files**: it writes them to a private temporary directory (`0700`, files `0600`) and exports their path (`AuthKey_AB12.p8` → `AUTHKEY_AB12_P8`). With `-- command` it deletes them when the command exits. SSH/GPG keys and "other" items are not loaded. Details in `ovault load --help`.

### Environment variables

| Variable | Description |
|----------|-------------|
| `OPENVAULT_PASSWORD` | Master password without a prompt (useful in CI). Removed from the environment before `ovault run`. |
| `OPENVAULT_FILE` | Alternative path to the vault file (app and CLI). |

---

## ⚙️ App settings

In **OpenVault → Settings** (⌘,):

| Option | Default | Description |
|--------|-------------|-------------|
| Lock After Inactivity | 5 minutes | 1, 5, 15, 60 minutes, or never |
| Clear Clipboard After | 30 seconds | 15, 30, 60, or 90 seconds |
| Unlock with Touch ID | On | Requires a signed app and available Touch ID |
| Change Master Password | — | Re-encrypts the whole vault with a new salt |

Shortcuts: ⌘N new item, ⌘L lock, ⌫ delete selected item.

---

## 🧪 Development

```bash
make test       # core tests (swift test)
make cli        # builds ovault in release
make project    # generates App/OpenVault.xcodeproj
make app        # builds OpenVault.app into build/
make clean      # removes build artifacts and the generated project
```

Signing, the DMG, and notarization are handled by [fastlane](fastlane/Fastfile) (`make dmg` for a local test DMG). Releases are published by pushing a `v*` tag; see [.github/RELEASING.md](.github/RELEASING.md).

Layout:

```
Sources/OpenVaultCore/   encryption, vault format, .env parser, .openvault
Sources/ovault/          CLI
Tests/                   core tests
App/                     SwiftUI app (project.yml + Sources/)
assets/                  branding: icon, logos, palette (see assets/README.md)
```

### Knowledge graph (graphify)

[graphify](https://github.com/safishamsi/graphify) turns the repo (code, docs, and images) into a knowledge graph: it extracts symbols and relationships, detects communities, and tags each relationship as `EXTRACTED`, `INFERRED`, or `AMBIGUOUS`. We use it to find our way around the code, and so AI agents can query the graph instead of rereading the whole repo.

The output lives in `graphify-out/`, which isn't versioned: everyone generates it locally.

| File | What it is |
|---|---|
| `GRAPH_REPORT.md` | Summary: most connected nodes, communities, surprising connections |
| `graph.html` | Interactive graph, opens in the browser without a server |
| `graph.json` | Raw graph data, for queries |

It is generated and queried from [Claude Code](https://claude.com/claude-code) with the `/graphify` skill:

```bash
/graphify .                              # rebuilds the full graph
/graphify . --update                     # re-extracts only the files that changed
/graphify query "how is the vault encrypted?"
/graphify path "VaultStore" "VaultCrypto"
/graphify explain "VaultKey"
```

Run `/graphify .` the first time; after that, `/graphify . --update` keeps your graph up to date.

---

## 🔒 Security

- The vault lives at `~/Library/Application Support/OpenVault/vault.ovault`, with `0600` permissions (folder `0700`).
- The app and the CLI write under an exclusive lock and reread the latest version before modifying, so they don't overwrite each other.
- When locking, the key is discarded from memory.

Found a vulnerability? Don't open a public issue: read the [security policy](SECURITY.md) and report it privately.

---

## 🤝 Contributing

1. Fork the repo
2. Create a branch from `dev`: `git checkout -b feat/my-change`
3. Commit using [Conventional Commits](https://www.conventionalcommits.org): `git commit -m "feat: add my change"`
4. Make sure `make test` and `make app` pass, and open a PR against `dev`

---

## 📄 License

OpenVault is free software under the **GNU General Public License v3.0** — see [LICENSE](LICENSE).

---

<div align="center">
Made with ☕ by <a href="https://franciscosolis.cl">Fran</a>
</div>
