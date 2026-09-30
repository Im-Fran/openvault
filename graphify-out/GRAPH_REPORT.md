# Graph Report - openvault  (2026-09-30)

## Corpus Check
- 14 files · ~130,647 words
- Verdict: corpus is large enough that graph structure adds value.

## Summary
- 546 nodes · 985 edges · 32 communities (22 shown, 10 thin omitted)
- Extraction: 89% EXTRACTED · 11% INFERRED · 0% AMBIGUOUS · INFERRED: 108 edges (avg confidence: 0.87)
- Token cost: 73,561 input · 0 output

## Community Hubs (Navigation)
- Biometrics, Keychain & Vault Store
- ovault CLI Commands
- Vault Model & DotEnv
- Vault Crypto & Envelope
- README Features & Workflow
- Raster Icon Exports
- App Assets & Lock Flow
- Brand Guide & Palette
- Project Config & Shell Export
- UI Support & Item Kinds
- SVG Icon & Mark Variants
- Vault Errors & Key Derivation
- Item Editor
- Menu Bar Quick Search
- Content View & Item List
- Item Detail View
- App Delegate & Dock Policy
- Sidebar & Selection
- App Source Files
- Build, CI & Package Targets
- Graphify Workflow
- Settings & Change Password
- App Entry & Root View
- DotEnv Parsing Concept
- Package Manifest
- Touch ID Keychain Concept
- DotEnv Serialize Concept
- Vault File Location

## God Nodes (most connected - your core abstractions)
1. `Vault` - 25 edges
2. `VaultStore` - 23 edges
3. `VaultKey` - 22 edges
4. `ItemEditorView` - 19 edges
5. `VaultFile` - 18 edges
6. `unlock()` - 15 edges
7. `App icon 1024px (default: white vault-dial mark on blue-to-purple gradient squircle)` - 14 edges
8. `Item` - 13 edges
9. `Kind` - 13 edges
10. `ItemDetailView` - 12 edges

## Surprising Connections (you probably didn't know these)
- `fastlane available actions (auto-generated README)` --semantically_similar_to--> `fastlane lanes (certificates, test, build, cli, dmg, release)`  [INFERRED] [semantically similar]
  fastlane/README.md → .github/RELEASING.md
- `Auto-lock (inactivity, sleep, screen lock)` --conceptually_related_to--> `Master password`  [INFERRED]
  App/Sources/VaultStore.swift → README.md
- `DMG background generator script` --shares_data_with--> `Brand gradient (#4490FE -> #8443D3, 160 deg)`  [INFERRED]
  packaging/dmg-background.swift → assets/brand/BRAND.md
- `Read version from the tag step` --shares_data_with--> `ovaultVersion`  [INFERRED]
  .github/workflows/release.yml → Sources/ovault/Version.swift
- `graphify workflow for agents (CLAUDE.md)` --semantically_similar_to--> `Knowledge graph (graphify) in graphify-out/`  [INFERRED] [semantically similar]
  CLAUDE.md → README.md

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Vault unlock flow (password or Touch ID)** — lockview_submit, vaultstore_unlock, vaultstore_unlockwithbiometrics, biometrics_load, vaultstore_didunlock, vaultstore_watchfile [EXTRACTED 1.00]
- **Brand surfaces for distribution (README header, social preview, DMG background)** — assets_brand_png_readme_header_1200x300, assets_brand_png_social_preview_1280x640, packaging_dmg_background [INFERRED 0.75]
- **Time-limited secret exposure (auto-lock, clipboard clearing, masking)** — vaultstore_auto_lock, vaultstore_lock, app_sources_itemdetailview_secretrow [INFERRED 0.75]
- **App Icon Appearance Set (light / dark / tinted)** — assets_brand_png_icon_1024, assets_brand_png_icon_512, assets_brand_png_icon_dark_1024, assets_brand_png_icon_dark_512, assets_brand_png_icon_tinted_1024, assets_brand_png_icon_tinted_512 [INFERRED 0.85]
- **App icon appearance set (default, dark, tinted)** — assets_brand_png_icon_1024, assets_brand_png_icon_dark_1024, assets_brand_png_icon_tinted_1024, assets_brand_png_icon_dark_512, assets_brand_png_icon_tinted_512 [INFERRED 0.85]
- **Brand identity (gradient, mark, icon)** — app_appicon_icon_icon_appicon, app_assets_xcassets_brandstart_colorset_contents_brandstart, app_assets_xcassets_brandend_colorset_contents_brandend, app_assets_xcassets_brandmark_imageset_contents_brandmark, app_sources_support_brand [INFERRED 0.85]
- **OpenVault Brand Identity Assets sharing the vault-dial mark** — assets_brand_png_icon_1024, assets_brand_png_icon_512, assets_brand_png_icon_dark_1024, assets_brand_png_icon_dark_512, assets_brand_png_icon_tinted_1024, assets_brand_png_icon_tinted_512, assets_brand_png_mark_ink_512, assets_brand_png_mark_white_512, assets_brand_png_readme_header_1200x300, assets_brand_png_social_preview_1280x640, brand_vault_dial_mark [INFERRED 0.85]
- **Signed and notarized release pipeline (tag -> fastlane -> match -> DMG -> GitHub Release)** — release_release_workflow, release_read_version_from_tag, releasing_fastlane_lanes, releasing_match_repo, releasing_notarization, releasing_dmg_packaging, dmg_settings_dmg_settings, dmg_background_dmg_background, release_publish_github_release [INFERRED 0.85]
- **App icon appearance variants (light, dark, tinted, clear)** — assets_brand_svg_icon_light, assets_brand_svg_icon_dark, assets_brand_svg_icon_tinted, assets_brand_svg_icon_clear [INFERRED 0.95]
- **App icon layer stack (background + ring + handle composite into the light icon)** — assets_brand_svg_layers_01_background, assets_brand_svg_layers_02_ring, assets_brand_svg_layers_03_handle, appicon_02_ring, appicon_03_handle, assets_brand_svg_icon_light [INFERRED 0.95]
- **Default app icon size ladder (16 to 1024px)** — assets_brand_png_icon_16, assets_brand_png_icon_32, assets_brand_png_icon_64, assets_brand_png_icon_128, assets_brand_png_icon_256, assets_brand_png_icon_512, assets_brand_png_icon_1024 [INFERRED 0.95]
- **CLI project env injection flow (.openvault -> unlock -> mergedEnv -> exec)** — sources_ovault_ovault_unlock, dotenv_parse, sources_ovault_ovault_run [INFERRED 0.95]
- **Standalone mark color variants (blue, ink, white, currentColor, app BrandMark)** — assets_brand_svg_mark_blue, assets_brand_svg_mark_ink, assets_brand_svg_mark_white, assets_brand_svg_mark_current, app_assets_xcassets_brandmark_imageset_mark_brandmark [INFERRED 0.95]
- **Vault encryption pipeline (password -> PBKDF2 key -> AES-GCM envelope -> locked atomic file)** — vaultcrypto_derive, sources_openvaultcore_vaultcrypto_vaultkey, vaultcrypto_seal, vaultcrypto_open, vaultcrypto_envelope, vaultfile_write, vaultfile_withlock [INFERRED 0.95]
- **App and CLI share OpenVaultCore and one vault file** — readme_openvault_app, readme_ovault_cli, readme_openvaultcore, readme_shared_vault_file, readme_exclusive_lock_writes [EXTRACTED 1.00]
- **Project resolution and environment injection flow** — readme_ovault_project_file, readme_openvault_project_file, readme_projects, readme_ovault_run, readme_ovault_load, readme_ovault_hook, readme_openvault_password_env [INFERRED 0.85]
- **Vault protection model (encryption, unlock, lock)** — readme_vault_encryption, readme_master_password, readme_touch_id_unlock, vaultstore_auto_lock, readme_secure_clipboard [INFERRED 0.85]

## Communities (32 total, 10 thin omitted)

### Community 0 - "Biometrics, Keychain & Vault Store"
Cohesion: 0.06
Nodes (22): Biometrics, .base, .isAvailable, .isEnrolled, LockView, .body, .canSubmit, .isSetup (+14 more)

### Community 1 - "ovault CLI Commands"
Cohesion: 0.10
Nodes (24): ArgumentParser, CLIError, Export, Format, env, json, Get, Hook (+16 more)

### Community 2 - "Vault Model & DotEnv"
Cohesion: 0.09
Nodes (16): Foundation, DotEnv, Shell, Item, Kind, env, file, gpgKey (+8 more)

### Community 3 - "Vault Crypto & Envelope"
Cohesion: 0.11
Nodes (13): CommonCrypto, CryptoKit, Envelope, JSONDecoder, .vault, JSONEncoder, .vault, VaultCrypto (+5 more)

### Community 4 - "README Features & Workflow"
Cohesion: 0.08
Nodes (33): DEVELOPMENT_TEAM PX7HA29NR3, Contributing flow (branch from dev, Conventional Commits, PR to dev), CryptoKit (AES-GCM) + CommonCrypto (PBKDF2), Drag and drop with type detection, fastlane signing, DMG, notarization and v* tag releases, GitHub Actions CI (macOS 26), GPG keys (fingerprint and identity without keyring import), GNU GPL v3.0 license (+25 more)

### Community 5 - "Raster Icon Exports"
Cohesion: 0.10
Nodes (23): App icon 1024px (default: white vault-dial mark on blue-to-purple gradient squircle), App icon 128px (default), App icon 16px (default), App icon 256px (default), App icon 32px (default), App icon 512px (default), App icon 64px (default), App icon 1024px (dark appearance: blue-to-violet gradient mark on near-black squircle) (+15 more)

### Community 6 - "App Assets & Lock Flow"
Cohesion: 0.08
Nodes (25): App Icon (Liquid Glass handle + ring on brand gradient), AccentColor color set, BrandEnd color set (gradient end, purple), BrandMark image set (template vector mark.svg), BrandStart color set (gradient start, blue), Brand, Motion, Biometrics.delete() (+17 more)

### Community 7 - "Brand Guide & Palette"
Cohesion: 0.11
Nodes (18): Brand colors (colors.json), OpenVault brand guide, DMG background generator script, dmgbuild settings, icon_locations (app 170,190 / Applications 470,190), Brand asset usage map (assets/README), fastlane available actions (auto-generated README), Updating the branding procedure (+10 more)

### Community 8 - "Project Config & Shell Export"
Cohesion: 0.13
Nodes (12): ProjectConfig, ProjectConfigError, .errorDescription, missingProjectName, Testing, changePasswordInvalidatesOldKey(), dotOvaultFileNamesTheProject(), encryptionRoundTripAndWrongPassword() (+4 more)

### Community 9 - "UI Support & Item Kinds"
Cohesion: 0.12
Nodes (11): .body, Clipboard, EnvironmentValues, Item, Item.Kind, .singular, .symbol, .tint (+3 more)

### Community 10 - "SVG Icon & Mark Variants"
Cohesion: 0.16
Nodes (19): BrandMark imageset mark (ink #14161C vault-dial mark used in app), App Icon Layer 02: Ring (white open ring, Icon Composer asset), App Icon Layer 03: Handle (white diagonal stroke + center dot, Icon Composer asset), App Icon - Clear variant (translucent white tile and mark), App Icon - Dark variant (navy tile, light blue-to-lilac gradient mark), App Icon - Light variant (blue-to-violet gradient tile, white mark), App Icon - Tinted variant (grey gradient tile, light grey mark), Icon Layer 01: Background (rounded square, #4490FE to #8443D3 gradient) (+11 more)

### Community 11 - "Vault Errors & Key Derivation"
Cohesion: 0.14
Nodes (19): VaultError, corrupted, .errorDescription, keyDerivationFailed, notFound, wrongPassword, VaultKey.derive (PBKDF2-HMAC-SHA256), Envelope (on-disk format) (+11 more)

### Community 12 - "Item Editor"
Cohesion: 0.16
Nodes (7): ItemEditorView, .body, .canSave, .contentTitle, .isDirty, .nameError, .namePrompt

### Community 13 - "Menu Bar Quick Search"
Cohesion: 0.16
Nodes (8): MainWindow, MenuBarLockView, .body, MenuBarView, .body, .footer, .list, .results

### Community 14 - "Content View & Item List"
Cohesion: 0.21
Nodes (8): ContentView, .body, .filtered, .title, ItemList, .body, ItemRow, .body

### Community 15 - "Item Detail View"
Cohesion: 0.22
Nodes (9): CopyButton, ItemDetailView, .body, .envSection, .header, .passphraseRow, SecretRow, .body (+1 more)

### Community 17 - "Sidebar & Selection"
Cohesion: 0.25
Nodes (6): Sidebar, .body, SidebarSelection, all, kind, project

### Community 18 - "App Source Files"
Cohesion: 0.33
Nodes (4): EditorDraft, AppKit, OpenVaultCore, SwiftUI

### Community 19 - "Build, CI & Package Targets"
Cohesion: 0.31
Nodes (9): CI job: App (unsigned xcodebuild), CI workflow, CI job: Core + CLI, OpenVault Swift Package, OpenVaultCore library target, OpenVaultCoreTests test target, ovault executable target, swift-argument-parser dependency (+1 more)

### Community 20 - "Graphify Workflow"
Cohesion: 0.43
Nodes (5): graphify-out/GRAPH_REPORT.md (god nodes and communities), /graphify query, path, explain commands, /graphify . --update (incremental re-extraction), graphify workflow for agents (CLAUDE.md), Knowledge graph (graphify) in graphify-out/

### Community 21 - "Settings & Change Password"
Cohesion: 0.38
Nodes (4): ChangePasswordView, .body, SettingsView, .body

### Community 22 - "App Entry & Root View"
Cohesion: 0.33
Nodes (4): OpenVaultApp, .body, RootView, .body

## Knowledge Gaps
- **98 isolated node(s):** `.canSubmit`, `.isSetup`, `.setupHint`, `.body`, `.color` (+93 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 160 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **10 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `OpenVaultCore` connect `App Source Files` to `Project Config & Shell Export`, `UI Support & Item Kinds`, `Content View & Item List`, `ovault CLI Commands`?**
  _High betweenness centrality (0.228) - this node is a cross-community bridge._
- **Why does `AppKit` connect `App Source Files` to `UI Support & Item Kinds`, `Raster Icon Exports`?**
  _High betweenness centrality (0.219) - this node is a cross-community bridge._
- **Why does `DMG installer window background (soft blue/violet glow with drag-to-Applications arrow)` connect `Raster Icon Exports` to `App Source Files`?**
  _High betweenness centrality (0.192) - this node is a cross-community bridge._
- **Are the 4 inferred relationships involving `Vault` (e.g. with `.save()` and `encryptionRoundTripAndWrongPassword()`) actually correct?**
  _`Vault` has 4 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `VaultFile` (e.g. with `VaultStore` and `.watchFile()`) actually correct?**
  _`VaultFile` has 3 INFERRED edges - model-reasoned connections that need verification._
- **What connects `.canSubmit`, `.isSetup`, `.setupHint` to the rest of the system?**
  _98 weakly-connected nodes found - possible documentation gaps or missing edges._
- **Should `Biometrics, Keychain & Vault Store` be split into smaller, more focused modules?**
  _Cohesion score 0.05725490196078432 - nodes in this community are weakly interconnected._