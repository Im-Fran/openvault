# Graph Report - openvault  (2026-09-30)

## Corpus Check
- 85 files · ~126,033 words
- Verdict: corpus is large enough that graph structure adds value.
- Unclassified: 10 file(s) not represented in the graph (top: (none) 7, .entitlements 1, .resolved 1)

## Summary
- 471 nodes · 910 edges · 21 communities (13 shown, 8 thin omitted)
- Extraction: 85% EXTRACTED · 15% INFERRED · 0% AMBIGUOUS · INFERRED: 139 edges (avg confidence: 0.87)
- Token cost: 414,843 input · 0 output

## Community Hubs (Navigation)
- Item Detail & App Shell
- Content View & Item List
- Vault Model & DotEnv
- Core Tests & Parsing
- Vault Crypto & Envelope
- Build, CI & Release
- Raster Icon Exports
- Biometrics & Keychain
- ovault CLI Commands
- UI Support & Brand Helpers
- App Assets & Lock Flow
- SVG Icon & Mark Variants
- Brand Guide & Palette
- Package Manifest
- Project Config Resolution
- Vault File Location
- Touch ID Keychain Concept
- External Tool Runner
- Vault Projects

## God Nodes (most connected - your core abstractions)
1. `Item` - 33 edges
2. `VaultStore` - 24 edges
3. `Vault` - 23 edges
4. `VaultKey` - 23 edges
5. `VaultFile` - 22 edges
6. `ItemEditorView` - 21 edges
7. `ItemDetailView` - 19 edges
8. `EditorDraft` - 18 edges
9. `App icon 1024px (default: white vault-dial mark on blue-to-purple gradient squircle)` - 14 edges
10. `SettingsView` - 12 edges

## Surprising Connections (you probably didn't know these)
- `Encrypted vault (AES-256-GCM + PBKDF2-SHA256, 600k iterations)` --references--> `VaultCrypto`  [INFERRED]
  README.md → Sources/OpenVaultCore/VaultCrypto.swift
- `Encrypted vault (AES-256-GCM + PBKDF2-SHA256, 600k iterations)` --references--> `VaultKey.derive (PBKDF2-HMAC-SHA256)`  [INFERRED]
  README.md → Sources/OpenVaultCore/VaultCrypto.swift
- `Exclusive-lock writes and 0600 permissions` --references--> `VaultFile.write (atomic, 0600)`  [INFERRED]
  README.md → Sources/OpenVaultCore/VaultFile.swift
- `fastlane available actions (auto-generated README)` --semantically_similar_to--> `fastlane lanes (certificates, test, build, cli, dmg, release)`  [INFERRED] [semantically similar]
  fastlane/README.md → .github/RELEASING.md
- `.nameError` --references--> `Item`  [INFERRED]
  App/Sources/ItemEditorView.swift → Sources/OpenVaultCore/Vault.swift

## Import Cycles
- None detected.

## Hyperedges (group relationships)
- **Vault unlock flow (password or Touch ID)** — lockview_submit, vaultstore_unlock, vaultstore_unlockwithbiometrics, biometrics_load, vaultstore_didunlock, vaultstore_watchfile [EXTRACTED 1.00]
- **Time-limited secret exposure (auto-lock, clipboard clearing, masking)** — vaultstore_auto_lock, vaultstore_lock, support_copy, itemdetailview_secretrow, support_revealall [INFERRED 0.75]
- **Brand identity (gradient, mark, icon)** — app_appicon_icon_icon_appicon, app_assets_xcassets_brandstart_colorset_contents_brandstart, app_assets_xcassets_brandend_colorset_contents_brandend, app_assets_xcassets_brandmark_imageset_contents_brandmark, support_brand [INFERRED 0.85]
- **Vault encryption pipeline (password -> PBKDF2 key -> AES-GCM envelope -> locked atomic file)** — vaultcrypto_derive, sources_openvaultcore_vaultcrypto_vaultkey, vaultcrypto_seal, vaultcrypto_open, vaultcrypto_envelope, vaultfile_write, vaultfile_withlock [INFERRED 0.95]
- **CLI project env injection flow (.openvault -> unlock -> mergedEnv -> exec)** — projectconfig_find, ovault_resolve, ovault_unlock, vault_mergedenv, dotenv_parse, ovault_run [INFERRED 0.95]
- **Signed and notarized release pipeline (tag -> fastlane -> match -> DMG -> GitHub Release)** — release_release_workflow, release_read_version_from_tag, releasing_fastlane_lanes, releasing_match_repo, releasing_notarization, releasing_dmg_packaging, dmg_settings_dmg_settings, dmg_background_dmg_background, release_publish_github_release [INFERRED 0.85]
- **App icon layer stack (background + ring + handle composite into the light icon)** — assets_brand_svg_layers_01_background, assets_brand_svg_layers_02_ring, assets_brand_svg_layers_03_handle, appicon_02_ring, appicon_03_handle, assets_brand_svg_icon_light [INFERRED 0.95]
- **App icon appearance variants (light, dark, tinted, clear)** — assets_brand_svg_icon_light, assets_brand_svg_icon_dark, assets_brand_svg_icon_tinted, assets_brand_svg_icon_clear [INFERRED 0.95]
- **Standalone mark color variants (blue, ink, white, currentColor, app BrandMark)** — assets_brand_svg_mark_blue, assets_brand_svg_mark_ink, assets_brand_svg_mark_white, assets_brand_svg_mark_current, app_assets_xcassets_brandmark_imageset_mark_brandmark [INFERRED 0.95]
- **App icon appearance set (default, dark, tinted)** — assets_brand_png_icon_1024, assets_brand_png_icon_dark_1024, assets_brand_png_icon_tinted_1024, assets_brand_png_icon_dark_512, assets_brand_png_icon_tinted_512 [INFERRED 0.85]
- **Default app icon size ladder (16 to 1024px)** — assets_brand_png_icon_16, assets_brand_png_icon_32, assets_brand_png_icon_64, assets_brand_png_icon_128, assets_brand_png_icon_256, assets_brand_png_icon_512, assets_brand_png_icon_1024 [INFERRED 0.95]
- **Brand surfaces for distribution (README header, social preview, DMG background)** — assets_brand_png_readme_header_1200x300, assets_brand_png_social_preview_1280x640, packaging_dmg_background [INFERRED 0.75]
- **App Icon Appearance Set (light / dark / tinted)** — assets_brand_png_icon_1024, assets_brand_png_icon_512, assets_brand_png_icon_dark_1024, assets_brand_png_icon_dark_512, assets_brand_png_icon_tinted_1024, assets_brand_png_icon_tinted_512 [INFERRED 0.85]
- **OpenVault Brand Identity Assets sharing the vault-dial mark** — assets_brand_png_icon_1024, assets_brand_png_icon_512, assets_brand_png_icon_dark_1024, assets_brand_png_icon_dark_512, assets_brand_png_icon_tinted_1024, assets_brand_png_icon_tinted_512, assets_brand_png_mark_ink_512, assets_brand_png_mark_white_512, assets_brand_png_readme_header_1200x300, assets_brand_png_social_preview_1280x640, brand_vault_dial_mark [INFERRED 0.85]

## Communities (21 total, 8 thin omitted)

### Community 0 - "Item Detail & App Shell"
Cohesion: 0.05
Nodes (39): CopyButton, ItemDetailView, .body, .envSection, .header, .passphraseRow, SecretRow, .body (+31 more)

### Community 1 - "Content View & Item List"
Cohesion: 0.06
Nodes (38): ContentView, .body, .filtered, .title, ItemList, .body, Sidebar, .body (+30 more)

### Community 2 - "Vault Model & DotEnv"
Cohesion: 0.08
Nodes (18): Foundation, DotEnv, ProjectConfig, Item, Kind, env, gpgKey, other (+10 more)

### Community 3 - "Core Tests & Parsing"
Cohesion: 0.08
Nodes (40): changePasswordInvalidatesOldKey test, dotEnvParsing test, encryptionRoundTripAndWrongPassword test, mergedEnvSecretsWin test, projectConfigWalksUp test, DotEnv.parse, DotEnv.serialize, DotEnv.unescape (+32 more)

### Community 4 - "Vault Crypto & Envelope"
Cohesion: 0.11
Nodes (15): CommonCrypto, CryptoKit, Envelope, JSONDecoder, .vault, JSONEncoder, .vault, VaultCrypto (+7 more)

### Community 5 - "Build, CI & Release"
Cohesion: 0.08
Nodes (26): CI job: App (unsigned xcodebuild), CI workflow, CI job: Core + CLI, OVault (CLI root command), OpenVault Swift Package, OpenVaultCore library target, OpenVaultCoreTests test target, ovault executable target (+18 more)

### Community 6 - "Raster Icon Exports"
Cohesion: 0.10
Nodes (23): App icon 1024px (default: white vault-dial mark on blue-to-purple gradient squircle), App icon 128px (default), App icon 16px (default), App icon 256px (default), App icon 32px (default), App icon 512px (default), App icon 64px (default), App icon 1024px (dark appearance: blue-to-violet gradient mark on near-black squircle) (+15 more)

### Community 7 - "Biometrics & Keychain"
Cohesion: 0.11
Nodes (8): Biometrics, .base, .isAvailable, .isEnrolled, VaultStore, .touchIDEnabled, LocalAuthentication, Security

### Community 8 - "ovault CLI Commands"
Cohesion: 0.16
Nodes (15): ArgumentParser, Export, Format, env, json, Get, Import, Init (+7 more)

### Community 9 - "UI Support & Brand Helpers"
Cohesion: 0.12
Nodes (12): .body, Brand, Clipboard, EnvironmentValues, Item.Kind, .singular, .symbol, .tint (+4 more)

### Community 10 - "App Assets & Lock Flow"
Cohesion: 0.12
Nodes (22): App Icon (Liquid Glass handle + ring on brand gradient), AccentColor color set, BrandEnd color set (gradient end, purple), BrandMark image set (template vector mark.svg), BrandStart color set (gradient start, blue), Biometrics.delete(), Biometrics.isAvailable, Biometrics.isEnrolled (+14 more)

### Community 11 - "SVG Icon & Mark Variants"
Cohesion: 0.16
Nodes (19): BrandMark imageset mark (ink #14161C vault-dial mark used in app), App Icon Layer 02: Ring (white open ring, Icon Composer asset), App Icon Layer 03: Handle (white diagonal stroke + center dot, Icon Composer asset), App Icon - Clear variant (translucent white tile and mark), App Icon - Dark variant (navy tile, light blue-to-lilac gradient mark), App Icon - Light variant (blue-to-violet gradient tile, white mark), App Icon - Tinted variant (grey gradient tile, light grey mark), Icon Layer 01: Background (rounded square, #4490FE to #8443D3 gradient) (+11 more)

### Community 12 - "Brand Guide & Palette"
Cohesion: 0.21
Nodes (8): Brand colors (colors.json), OpenVault brand guide, DMG background generator script, dmgbuild settings, icon_locations (app 170,190 / Applications 470,190), Brand asset usage map (assets/README), Updating the branding procedure, DMG packaging

## Knowledge Gaps
- **82 isolated node(s):** `LocalAuthentication`, `Security`, `.base`, `.isAvailable`, `.isEnrolled` (+77 more)
  These have ≤1 connection - possible missing edges or undocumented components. (Counts symbols only; 125 node(s) total have ≤1 connection when file, concept and rationale nodes are included.)
- **8 thin communities (<3 nodes) omitted from report** — run `graphify query` to explore isolated nodes.

## Suggested Questions
_Questions this graph is uniquely positioned to answer:_

- **Why does `Item` connect `Vault Model & DotEnv` to `Item Detail & App Shell`, `Content View & Item List`, `Core Tests & Parsing`, `Vault Crypto & Envelope`, `Biometrics & Keychain`, `ovault CLI Commands`, `UI Support & Brand Helpers`?**
  _High betweenness centrality (0.225) - this node is a cross-community bridge._
- **Why does `VaultStore` connect `Biometrics & Keychain` to `Item Detail & App Shell`, `Content View & Item List`, `Vault Model & DotEnv`, `Vault Crypto & Envelope`?**
  _High betweenness centrality (0.147) - this node is a cross-community bridge._
- **Why does `DMG installer window background (soft blue/violet glow with drag-to-Applications arrow)` connect `Raster Icon Exports` to `Item Detail & App Shell`?**
  _High betweenness centrality (0.147) - this node is a cross-community bridge._
- **Are the 10 inferred relationships involving `Item` (e.g. with `.body` and `.body`) actually correct?**
  _`Item` has 10 INFERRED edges - model-reasoned connections that need verification._
- **Are the 2 inferred relationships involving `VaultStore` (e.g. with `OpenVaultApp` and `VaultFile`) actually correct?**
  _`VaultStore` has 2 INFERRED edges - model-reasoned connections that need verification._
- **Are the 3 inferred relationships involving `Vault` (e.g. with `.save()` and `encryptionRoundTripAndWrongPassword()`) actually correct?**
  _`Vault` has 3 INFERRED edges - model-reasoned connections that need verification._
- **Are the 5 inferred relationships involving `VaultFile` (e.g. with `VaultStore` and `.watchFile()`) actually correct?**
  _`VaultFile` has 5 INFERRED edges - model-reasoned connections that need verification._