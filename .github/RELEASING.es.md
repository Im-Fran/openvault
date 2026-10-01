# Publicar una release

[English](RELEASING.md) · **Español**

La firma, compilación, notarización y el DMG los hace **fastlane** (`fastlane/Fastfile`). El workflow [`release.yml`](workflows/release.yml) corre el lane `release` en cada tag y publica en GitHub Releases:

- `OpenVault-<versión>.dmg` — la app notarizada y con el ticket *stapled*, en un DMG también notarizado.
- `ovault-<versión>-macos-universal.zip` — el CLI (arm64 + x86_64), firmado y notarizado.
- `checksums.txt` — SHA-256 de ambos.

```sh
git tag v0.1.0        # o v0.1.0+7 para fijar el build number
git push origin v0.1.0
```

La versión del tag se usa como `MARKETING_VERSION` de la app y como `ovault --version`.

## Lanes

| Comando | Qué hace |
|---|---|
| `bundle exec fastlane certificates` | Sincroniza el certificado y el perfil Developer ID desde el repo de match (en local puede crear el perfil) |
| `bundle exec fastlane test` | `swift test` |
| `bundle exec fastlane build [signed:false]` | Compila `build/OpenVault.app` (Developer ID, o sin firma) |
| `bundle exec fastlane cli [version:x.y.z]` | CLI universal firmado en `build/ovault` |
| `bundle exec fastlane dmg` | Empaqueta la app ya compilada en `build/dist/OpenVault-<versión>.dmg` (sin notarizar) |
| `bundle exec fastlane release [version:x.y.z build_number:n]` | Todo lo anterior, con notarización; resultado en `build/dist/` |

Atajos: `make dmg` (DMG local sin firma de app) y `make release`.

Requisitos locales: `bundle install`, `brew install xcodegen uv` (dmgbuild corre con `uvx`).

## Configuración (una sola vez)

### 1. API key de App Store Connect

App Store Connect → *Users and Access* → *Integrations* → *App Store Connect API* → nueva key con rol **Admin** (match la usa para crear el perfil; para solo notarizar basta Developer). Guarda el `.p8` en `~/.appstoreconnect/private_keys/AuthKey_<KEY_ID>.p8`.

### 2. Repo de match

Un repo git **privado** donde match guarda cifrados el certificado y los perfiles. Puede ser el mismo que usan otras apps del Team (p. ej. el de OpenBattery): el certificado Developer ID es uno por Team y cada app agrega su perfil.

El certificado Developer ID **no se puede crear por API** (solo el Account Holder, de forma interactiva). Si el repo aún no lo tiene, impórtalo una vez desde el `.p12` exportado de Acceso a Llaveros:

```sh
bundle exec fastlane match import --type developer_id --platform macos
```

### 3. `fastlane/.env`

```sh
cp fastlane/.env.example fastlane/.env   # y completa los valores; está en .gitignore
bundle exec fastlane certificates readonly:false   # crea el perfil Developer ID de OpenVault
```

`MATCH_PASSWORD` puede ir en el llavero en vez del `.env`: `security add-generic-password -s fastlane-match-openvault -a match -w`.

### 4. Secrets del repositorio (para el workflow)

| Secret | Valor |
|---|---|
| `ASC_KEY_ID` | Key ID de la API key |
| `ASC_ISSUER_ID` | Issuer ID |
| `ASC_KEY_CONTENT` | El `.p8` en base64 |
| `MATCH_REPOSITORY_URL` | URL del repo de match (HTTPS) |
| `MATCH_PASSWORD` | Passphrase del repo de match |
| `MATCH_GIT_BASIC_AUTHORIZATION` | `usuario:token` en base64, con un token de solo lectura al repo de match |

```sh
gh secret set ASC_KEY_ID
gh secret set ASC_ISSUER_ID
gh secret set ASC_KEY_CONTENT < <(base64 -i ~/.appstoreconnect/private_keys/AuthKey_XXXXXXXXXX.p8)
gh secret set MATCH_REPOSITORY_URL
gh secret set MATCH_PASSWORD
gh secret set MATCH_GIT_BASIC_AUTHORIZATION < <(printf 'usuario:ghp_xxx' | base64)
```

En CI match corre en modo solo lectura: el perfil tiene que existir antes (paso 3).

### ¿Por qué hace falta un perfil de aprovisionamiento?

La app guarda la clave de Touch ID en el Keychain de *data protection*, que requiere el entitlement `keychain-access-groups` (`App/OpenVault.entitlements`), y en macOS ese entitlement solo es válido con un perfil. No hace falta ninguna *capability* extra en el App ID: los perfiles ya incluyen el grupo `PX7HA29NR3.*`. El lane `release` falla si la app exportada no trae `embedded.provisionprofile`.

## DMG

`packaging/dmg-settings.py` define la ventana (640×400, íconos de la app y de Aplicaciones) y `packaging/dmg-background.png` el fondo con la paleta de marca. Para regenerar el fondo:

```sh
swiftc -O packaging/dmg-background.swift -o /tmp/bggen && /tmp/bggen packaging
```

## Si algo falla

- **match no encuentra el certificado**: falta importarlo (paso 2) o `MATCH_PASSWORD` no es el del repo.
- **`No profile matching` / no hay perfil**: corre `bundle exec fastlane certificates readonly:false` en local.
- **Notarización rechazada**: el log sale en la salida del lane (`print_log: true`).
- Para reintentar una release fallida: borra el tag (`git push --delete origin v0.1.0 && git tag -d v0.1.0`) y vuelve a crearlo, o usa *Run workflow* con el tag existente.
