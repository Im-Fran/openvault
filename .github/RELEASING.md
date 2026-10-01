# Publishing a release

**English** · [Español](RELEASING.es.md)

Signing, building, notarization and the DMG are handled by **fastlane** (`fastlane/Fastfile`). The [`release.yml`](workflows/release.yml) workflow runs the `release` lane on every tag and publishes to GitHub Releases:

- `OpenVault-<version>.dmg` — the notarized app with its ticket *stapled*, inside a DMG that is also notarized.
- `ovault-<version>-macos-universal.zip` — the CLI (arm64 + x86_64), signed and notarized.
- `checksums.txt` — SHA-256 of both.

```sh
git tag v0.1.0        # or v0.1.0+7 to pin the build number
git push origin v0.1.0
```

The tag version is used as the app's `MARKETING_VERSION` and as `ovault --version`.

## Lanes

| Command | What it does |
|---|---|
| `bundle exec fastlane certificates` | Syncs the Developer ID certificate and profile from the match repo (locally it can create the profile) |
| `bundle exec fastlane test` | `swift test` |
| `bundle exec fastlane build [signed:false]` | Builds `build/OpenVault.app` (Developer ID, or unsigned) |
| `bundle exec fastlane cli [version:x.y.z]` | Signed universal CLI at `build/ovault` |
| `bundle exec fastlane dmg` | Packages the already-built app into `build/dist/OpenVault-<version>.dmg` (not notarized) |
| `bundle exec fastlane release [version:x.y.z build_number:n]` | All of the above, with notarization; output in `build/dist/` |

Shortcuts: `make dmg` (local DMG without app signing) and `make release`.

Local requirements: `bundle install`, `brew install xcodegen uv` (dmgbuild runs via `uvx`).

## Setup (one time)

### 1. App Store Connect API key

App Store Connect → *Users and Access* → *Integrations* → *App Store Connect API* → new key with the **Admin** role (match uses it to create the profile; Developer is enough for notarization only). Save the `.p8` to `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.

### 2. match repo

A **private** git repo where match stores the encrypted certificate and profiles. It can be the same one used by other apps on the Team (e.g. OpenBattery's): there is one Developer ID certificate per Team, and each app adds its own profile.

The Developer ID certificate **cannot be created via the API** (only the Account Holder can, interactively). If the repo doesn't have it yet, import it once from the `.p12` exported from Keychain Access:

```sh
bundle exec fastlane match import --type developer_id --platform macos
```

### 3. `fastlane/.env`

```sh
cp fastlane/.env.example fastlane/.env   # and fill in the values; it's in .gitignore
bundle exec fastlane certificates readonly:false   # creates OpenVault's Developer ID profile
```

`MATCH_PASSWORD` can live in the keychain instead of `.env`: `security add-generic-password -s fastlane-match-openvault -a match -w`.

### 4. Repository secrets (for the workflow)

| Secret | Value |
|---|---|
| `ASC_KEY_ID` | API key's Key ID |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_CONTENT` | The `.p8`, base64-encoded |
| `MATCH_REPOSITORY_URL` | match repo URL (HTTPS) |
| `MATCH_PASSWORD` | match repo passphrase |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `user:token` base64-encoded, with a read-only token for the match repo |

```sh
gh secret set ASC_KEY_ID
gh secret set ASC_ISSUER_ID
gh secret set ASC_KEY_CONTENT < <(base64 -i ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8)
gh secret set MATCH_REPOSITORY_URL
gh secret set MATCH_PASSWORD
gh secret set MATCH_GIT_BASIC_AUTHORIZATION < <(printf 'user:ghp_xxx' | base64)
```

In CI, match runs in read-only mode: the profile must already exist (step 3).

### Why is a provisioning profile needed?

The app stores the Touch ID key in the *data protection* Keychain, which requires the `keychain-access-groups` entitlement (`App/OpenVault.entitlements`), and on macOS that entitlement is only valid with a profile. No extra *capability* is needed on the App ID: the profiles already include the `PX7HA29NR3.*` group. The `release` lane fails if the exported app doesn't contain `embedded.provisionprofile`.

## DMG

`packaging/dmg-settings.py` defines the window (640×400, app and Applications icons) and `packaging/dmg-background.png` the background with the brand palette. To regenerate the background:

```sh
swiftc -O packaging/dmg-background.swift -o /tmp/bggen && /tmp/bggen packaging
```

## Troubleshooting

- **match can't find the certificate**: it hasn't been imported (step 2), or `MATCH_PASSWORD` doesn't match the repo's.
- **`No profile matching` / no profile**: run `bundle exec fastlane certificates readonly:false` locally.
- **Notarization rejected**: the log is printed in the lane output (`print_log: true`).
- To retry a failed release: delete the tag (`git push --delete origin v0.1.0 && git tag -d v0.1.0`) and create it again, or use *Run workflow* with the existing tag.
