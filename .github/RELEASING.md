# Publicar una release

El workflow [`release.yml`](workflows/release.yml) se ejecuta al subir un tag `v*`. Compila, firma con **Developer ID**, notariza y publica en GitHub Releases:

- `OpenVault-<versión>.zip` — la app, notarizada y con el ticket *stapled*.
- `ovault-<versión>-macos-universal.zip` — el CLI (arm64 + x86_64), firmado y notarizado.
- `checksums.txt` — SHA-256 de ambos.

```sh
git tag v0.1.0
git push origin v0.1.0
```

La versión del tag se usa como `MARKETING_VERSION` de la app y como `ovault --version`.

## Secrets del repositorio (una sola vez)

*Settings → Secrets and variables → Actions → New repository secret*

| Secret | Qué es | Cómo obtenerlo |
|---|---|---|
| `DEVELOPER_ID_CERT_P12` | Certificado *Developer ID Application* + clave privada, en base64 | Acceso a Llaveros → *Developer ID Application: Francisco Solis (PX7HA29NR3)* → Exportar como `.p12`. Luego `base64 -i cert.p12 \| pbcopy` |
| `DEVELOPER_ID_CERT_PASSWORD` | Contraseña con la que exportaste el `.p12` | — |
| `DEVELOPER_ID_PROFILE` | Perfil de aprovisionamiento *Developer ID* de la app, en base64 | developer.apple.com → *Profiles* → **+** → *Developer ID* → App ID `cl.franciscosolis.openvault` → certificado Developer ID. Descárgalo y `base64 -i OpenVault.provisionprofile \| pbcopy` |
| `ASC_API_KEY_P8` | Contenido del archivo `.p8` de la API key (texto tal cual) | App Store Connect → *Users and Access* → *Integrations* → *App Store Connect API* → nueva key con rol **Developer** |
| `ASC_API_KEY_ID` | Key ID de esa API key | Misma pantalla |
| `ASC_API_ISSUER_ID` | Issuer ID | Misma pantalla, arriba de la lista |

Con `gh`:

```sh
gh secret set DEVELOPER_ID_CERT_P12 < <(base64 -i cert.p12)
gh secret set DEVELOPER_ID_CERT_PASSWORD
gh secret set DEVELOPER_ID_PROFILE < <(base64 -i OpenVault.provisionprofile)
gh secret set ASC_API_KEY_P8 < AuthKey_XXXXXXXXXX.p8
gh secret set ASC_API_KEY_ID
gh secret set ASC_API_ISSUER_ID
```

### ¿Por qué hace falta un perfil de aprovisionamiento?

La app usa el Keychain de *data protection* para guardar la clave de Touch ID, y eso requiere el entitlement `keychain-access-groups` (`App/OpenVault.entitlements`). En macOS ese entitlement solo es válido con un perfil. No necesita ninguna *capability* extra en el App ID: los perfiles ya incluyen el grupo `PX7HA29NR3.*`.

## Si algo falla

- **`notarytool` rechaza el envío**: `xcrun notarytool log <submission-id> --key … --key-id … --issuer …` muestra el motivo.
- **`No profile matching`**: el perfil expiró o no incluye el certificado actual; genera uno nuevo y actualiza `DEVELOPER_ID_PROFILE`.
- **Cambió el certificado Developer ID**: vuelve a exportar el `.p12` y regenera el perfil (va ligado al certificado).
- Para reintentar una release fallida: borra el tag (`git push --delete origin v0.1.0 && git tag -d v0.1.0`) y vuelve a crearlo.
