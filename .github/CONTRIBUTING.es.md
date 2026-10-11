# Cómo contribuir a OpenVault

[English](CONTRIBUTING.md) · **Español**

Gracias por estar aquí. OpenVault guarda los secretos de la gente, así que la
vara para cambiar el núcleo es alta: estas pautas apuntan sobre todo a mantenerlo seguro.

## Reglas base

- **Los secretos nunca tocan el disco en texto plano.** Ningún camino nuevo puede
  escribir un valor descifrado fuera del vault, salvo los archivos temporales
  privados que ya crea `ovault load` (`0700` / `0600`, borrados al salir).
- **Nada de criptografía propia.** El cifrado sigue en CryptoKit (AES-GCM) y
  CommonCrypto (PBKDF2). Los cambios a `VaultCrypto.swift` o al formato del vault
  necesitan un test y una migración para los vaults existentes.
- **La app y el CLI comparten `OpenVaultCore`.** La lógica que ambos necesitan vive
  ahí, no duplicada en `App/` ni en `Sources/ovault/`.
- **Pocas dependencias.** Pregunta en un issue antes de agregar un paquete Swift.
- **Nunca pegues secretos reales** en issues, PRs, tests ni fixtures.

## Preparar el entorno

Necesitas macOS 26+, Xcode 26+ y [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
brew install xcodegen
git clone https://github.com/Im-Fran/openvault.git
cd openvault
make open
```

El proyecto de Xcode se genera desde `App/project.yml` y **no** se versiona.
Agrega archivos en `App/Sources/` y vuelve a correr `make project` en vez de
editar el proyecto en Xcode.

| Comando | Qué hace |
| --- | --- |
| `make test` | Tests del núcleo (`swift test`) |
| `make cli` | Compila `ovault` en release |
| `make install-cli` | Instala `ovault` en `~/.local/bin` |
| `make project` | Genera `App/OpenVault.xcodeproj` |
| `make app` | Compila `OpenVault.app` en `build/` |
| `make open` | Compila y abre la app |
| `make clean` | Borra los artefactos y el proyecto generado |

El CI corre `swift test`, compila `ovault` y compila la app para macOS y para el
simulador de iOS con `CODE_SIGNING_ALLOWED=NO`. Todo tiene que pasar para que un PR entre.

## Dónde está cada cosa

```
Sources/OpenVaultCore/   cifrado, formato del vault, parser de .env, .ovaultrc
Sources/ovault/          CLI
Tests/                   tests del núcleo
App/                     app SwiftUI para macOS e iOS (project.yml + Sources/)
fastlane/                firma, notarización, DMG, TestFlight
assets/                  identidad visual
```

## Localización

El inglés es el idioma fuente y el español latinoamericano (`es-419`) el
secundario. Los textos nuevos de la interfaz van en inglés en
`App/Sources/Localizable.xcstrings`, con su traducción `es-419`. El CLI `ovault`
está solo en inglés. Los docs tienen gemelos `.es.md`: mantén ambos sincronizados.

## Ramas y commits

`dev` es la rama por defecto y donde entra todo el trabajo. `prd` es la rama de
releases: solo recibe PRs desde `dev`, y los tags de release salen de ella (ver
[RELEASING.es.md](RELEASING.es.md)).

```sh
git switch dev && git pull
git switch -c feat/ssh-agent-support
```

Los commits siguen [Conventional Commits](https://www.conventionalcommits.org),
en inglés y en imperativo:

```
feat(cli): add ovault diff
fix(app): keep the lock screen above the menu bar window
docs: explain .ovaultrc ranges
```

Tipos habituales: `feat`, `fix`, `refactor`, `docs`, `test`, `build`, `ci`, `chore`.
El scope es el área que tocas (`app`, `cli`, `core`, `release`, …).

## Abrir un pull request

1. Verifica que pasen `make test`, `make cli` y `make app`.
2. Sube tu rama y abre un PR contra `dev`.
3. Completa la plantilla del PR y adjunta capturas para todo lo visual, en modo
   claro y oscuro.
4. Mantén el PR acotado. Las limpiezas que no tienen relación van en su propio PR.

Los PRs a `dev` se mergean con squash; `dev` → `prd` usa merge commit. Hay que
resolver los hilos de revisión antes de mergear.

## Reportar bugs y pedir funcionalidades

Usa las [plantillas de issues](https://github.com/Im-Fran/openvault/issues/new/choose).
Las vulnerabilidades de seguridad van por [SECURITY.es.md](../SECURITY.es.md),
nunca en un issue público.

## Código de conducta

Participar en este proyecto implica seguir el
[Código de conducta](CODE_OF_CONDUCT.md).
