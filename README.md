<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="assets/brand/svg/lockup-dark.svg">
  <img src="assets/brand/svg/lockup-light.svg" width="480" alt="OpenVault">
</picture>

**Gestor de secretos para desarrolladores en macOS: `.env`, API keys, claves SSH y GPG en un vault cifrado, con un CLI para usarlos en tus proyectos.**

[![License](https://img.shields.io/github/license/Im-Fran/openvault)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/Im-Fran/openvault/ci.yml?branch=dev&label=CI)](https://github.com/Im-Fran/openvault/actions)
![Platform](https://img.shields.io/badge/platform-macOS%2026%2B-lightgrey)
![Swift](https://img.shields.io/badge/Swift-6-orange)

</div>

---

## 📖 Descripción

Los secretos de desarrollo suelen terminar repartidos en archivos `.env` sin cifrar, notas y carpetas `~/.ssh` de varias máquinas. OpenVault los guarda en **un solo vault cifrado** protegido por una contraseña maestra (y Touch ID), junto con las passphrases que necesitas para usar cada clave.

Tiene dos piezas que comparten el mismo núcleo (`OpenVaultCore`):

- **OpenVault.app** — app nativa en SwiftUI para crear, ver y organizar secretos por tipo y proyecto.
- **`ovault`** — CLI que se agrega a cualquier repositorio para inyectar los secretos del proyecto como variables de entorno, sin que el `.env` exista en disco.

Ambos leen el mismo archivo directamente, así que el CLI funciona aunque la app esté cerrada, y la app refleja al instante lo que escribe el CLI.

---

## ✨ Funcionalidades

- **Vault cifrado** — AES-256-GCM con clave derivada por PBKDF2-SHA256 (600.000 iteraciones). Nada se guarda en texto plano.
- **Touch ID** — desbloqueo con la clave guardada en el Keychain protegido por biometría.
- **Tipos de item** — archivos `.env`, secretos individuales, claves SSH, claves GPG y otros, cada uno con su passphrase opcional.
- **Proyectos** — agrupa items por proyecto; el CLI resuelve el proyecto desde un archivo `.openvault` en el repo.
- **`ovault run`** — ejecuta cualquier comando con los secretos del proyecto como variables de entorno.
- **Claves SSH** — genera claves ed25519, muestra clave pública y fingerprint, y exporta a `~/.ssh`.
- **Claves GPG** — muestra fingerprint e identidad sin importar la clave a tu keyring.
- **Arrastrar y soltar** — suelta un `.env`, `id_*` o `.asc` en la ventana y detecta el tipo.
- **Valores ocultos** — se revelan con el botón del ojo o manteniendo ⌥.
- **Portapapeles seguro** — lo copiado se marca como oculto para gestores de portapapeles y se borra solo.
- **Auto-bloqueo** — por inactividad, al dormir el Mac y al bloquear la pantalla.

---

## 🛠 Stack

| Capa | Tecnología |
|------|-----------|
| App | SwiftUI (macOS 26+) |
| CLI | Swift + [swift-argument-parser](https://github.com/apple/swift-argument-parser) |
| Criptografía | CryptoKit (AES-GCM), CommonCrypto (PBKDF2) |
| Biometría | LocalAuthentication + Keychain |
| Proyecto Xcode | [XcodeGen](https://github.com/yonaskolb/XcodeGen) |
| CI | GitHub Actions (macOS 26) |

---

## 📋 Requisitos

- **macOS 26** o superior
- **Xcode 26** o superior (Swift 6.2+)
- **XcodeGen** — `brew install xcodegen`
- Opcional: **gpg** (para ver fingerprints GPG), `ssh-keygen` viene con macOS

---

## 🚀 Primeros pasos

### 1. Clonar

```bash
git clone https://github.com/Im-Fran/openvault.git
cd openvault
```

### 2. Compilar y abrir la app

```bash
make open
```

La primera vez te pide crear la contraseña maestra. **No se puede recuperar si la olvidas.**

> Touch ID requiere que la app esté firmada. Cambia `DEVELOPMENT_TEAM` en `App/project.yml` por tu Team ID si compilas con otra cuenta; sin firma, el botón de Touch ID no aparece.

### 3. Instalar el CLI

```bash
make install-cli    # instala ovault en ~/.local/bin
```

Asegúrate de tener `~/.local/bin` en tu `PATH`, o usa `make install-cli PREFIX=/usr/local`.

---

## 💻 Uso del CLI

```bash
cd mi-proyecto
ovault init                        # crea .openvault con el nombre del proyecto (se puede commitear)
ovault import .env                 # importa un .env al proyecto
echo "sk_live_..." | ovault set STRIPE_KEY   # sin VALUE lo lee de stdin (no queda en el historial)
ovault run -- npm run dev          # ejecuta con los secretos como variables de entorno
ovault get STRIPE_KEY              # imprime un valor
ovault get deploy_key --passphrase # imprime la passphrase de un item
ovault export --format json        # entorno combinado (env | json)
ovault list                        # items del proyecto, sin valores (-a para todos)
```

Todos los comandos aceptan `--project <nombre>` para no depender del `.openvault`. Si un secreto individual y una variable de un `.env` tienen el mismo nombre, gana el secreto individual.

### Variables de entorno

| Variable | Descripción |
|----------|-------------|
| `OPENVAULT_PASSWORD` | Contraseña maestra sin prompt (útil en CI). Se elimina del entorno antes de `ovault run`. |
| `OPENVAULT_FILE` | Ruta alternativa al archivo del vault (app y CLI). |

---

## ⚙️ Configuración de la app

En **OpenVault → Ajustes** (⌘,):

| Opción | Por defecto | Descripción |
|--------|-------------|-------------|
| Bloquear tras inactividad | 5 minutos | 1, 5, 15, 60 minutos o nunca |
| Limpiar portapapeles tras | 30 segundos | 15, 30, 60 o 90 segundos |
| Desbloquear con Touch ID | Activado | Requiere app firmada y Touch ID disponible |
| Cambiar contraseña maestra | — | Re-cifra todo el vault con un salt nuevo |

Atajos: ⌘N nuevo item, ⌘L bloquear, ⌫ eliminar item seleccionado.

---

## 🧪 Desarrollo

```bash
make test       # tests del núcleo (swift test)
make cli        # compila ovault en release
make project    # genera App/OpenVault.xcodeproj
make app        # compila OpenVault.app en build/
make clean      # borra artefactos de build y el proyecto generado
```

Las releases (app y CLI firmados con Developer ID y notarizados) se publican al subir un tag `v*`; ver [.github/RELEASING.md](.github/RELEASING.md).

Estructura:

```
Sources/OpenVaultCore/   cifrado, formato del vault, parser .env, .openvault
Sources/ovault/          CLI
Tests/                   tests del núcleo
App/                     app SwiftUI (project.yml + Sources/)
assets/                  branding: ícono, logotipos, paleta (ver assets/README.md)
```

---

## 🔒 Seguridad

- Vault en `~/Library/Application Support/OpenVault/vault.ovault`, con permisos `0600` (carpeta `0700`).
- La app y el CLI escriben con un lock exclusivo y releen la última versión antes de modificar, así no se pisan.
- Al bloquear, la clave se descarta de memoria.

¿Encontraste una vulnerabilidad? No abras un issue público: lee la [política de seguridad](SECURITY.md) y repórtala en privado.

---

## 🤝 Contribuir

1. Haz un fork del repo
2. Crea una rama desde `dev`: `git checkout -b feat/mi-cambio`
3. Commit con [Conventional Commits](https://www.conventionalcommits.org): `git commit -m "feat: agrega mi cambio"`
4. Asegúrate de que `make test` y `make app` pasen, y abre un PR hacia `dev`

---

## 📄 Licencia

OpenVault es software libre bajo la **GNU General Public License v3.0** — ver [LICENSE](LICENSE).

---

<div align="center">
Hecho con ☕ por <a href="https://franciscosolis.cl">Fran</a>
</div>
