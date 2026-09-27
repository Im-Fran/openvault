# OpenVault

Gestor de secretos para desarrolladores en macOS: `.env`, secretos individuales, claves SSH y GPG (con sus passphrases), en un vault cifrado. Incluye el CLI `ovault` para usarlos en tus proyectos.

## Requisitos
macOS 26+, Xcode 27, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

## Build
```sh
make test          # tests del core
make open          # genera el proyecto, compila y abre OpenVault.app
make install-cli   # instala ovault en ~/.local/bin
```
Touch ID necesita que la app esté firmada con un Team: define `DEVELOPMENT_TEAM` en `App/project.yml`.

## CLI
```sh
cd mi-proyecto
ovault init                    # crea .openvault (sólo el nombre del proyecto; se puede commitear)
ovault import .env             # importa un .env al proyecto
echo "sk_live_..." | ovault set STRIPE_KEY
ovault run -- npm run dev      # ejecuta con los secretos como variables de entorno
ovault get STRIPE_KEY
ovault export --format json
ovault list
```
Pide la contraseña maestra por TTY; en CI usa `OPENVAULT_PASSWORD`. Los secretos individuales pisan a las variables del `.env` con el mismo nombre.

## Seguridad
- Vault en `~/Library/Application Support/OpenVault/vault.ovault` (`0600`), AES-256-GCM con clave PBKDF2-SHA256 (600k iteraciones).
- La app y el CLI escriben con lock + lectura previa, así no se pisan.
- Auto-bloqueo por inactividad, al dormir y al bloquear pantalla. El portapapeles se limpia solo y se marca como oculto para gestores de portapapeles.

## Licencia
OpenVault es software libre bajo la [GNU GPL v3](LICENSE).
