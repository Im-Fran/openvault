# assets/

Branding de OpenVault. **Fuente de verdad:** todo lo de `brand/` viene tal cual de `App icon design briefing.zip` (generado con Claude Design, 27-09-2026). La guía completa —geometría del ícono, paleta, tipografía y qué no hacer— está en [`brand/BRAND.md`](brand/BRAND.md); los hex, en [`brand/colors.json`](brand/colors.json).

```
brand/
├─ BRAND.md, colors.json
├─ svg/      íconos (claro/oscuro/tintado/transparente), capas para Icon Composer,
│            isotipos, wordmarks, lockups y "ov"
├─ png/      ícono en 16–1024 px, isotipos, header del README y social preview
└─ webp/     versiones livianas de lo anterior para web
```

## Dónde se usa cada archivo

| Uso | Archivo del proyecto | Cómo | Origen |
|---|---|---|---|
| Ícono de la app (Liquid Glass) | `App/AppIcon.icon/Assets/02-ring.svg`, `03-handle.svg` | **copia** | `brand/svg/layers/` |
| Degradado de fondo del ícono (claro y oscuro) | `App/AppIcon.icon/icon.json` → `fill-specializations` | valores | `BRAND.md` §1 (`#4490FE → #8443D3`, oscuro `#1A1F2E → #0C0C18`) |
| Isotipo de la pantalla de bloqueo | `App/Assets.xcassets/BrandMark.imageset/mark.svg` | **symlink** | `brand/svg/mark-ink.svg` (renderizado como template) |
| Color de acento de la app | `App/Assets.xcassets/AccentColor.colorset` | valores | Azul 500 `#3A81F6` / Azul 400 `#75ABFF` |
| Degradado de marca en SwiftUI (`Brand.gradient`) | `App/Assets.xcassets/BrandStart`, `BrandEnd` | valores | claro `#4490FE → #8443D3`, oscuro `#82B9FF → #B58BF9` |
| Encabezado del README | `README.md` | referencia directa | `brand/svg/lockup-light.svg`, `lockup-dark.svg` |
| Social preview de GitHub | *Settings → Social preview* (subida manual, GitHub no tiene API) | subida | `brand/png/social-preview-1280x640.png` |

### ¿Por qué las capas del ícono son copias y no symlinks?

El exportador de Icon Composer que usa `actool` falla con symlinks dentro de un `.icon` (`Icon export exited with status 255`). Los asset catalogs (`.xcassets`) sí los siguen, por eso `BrandMark` es un symlink.

## Actualizar el branding

1. Reemplaza los archivos en `brand/` (mismos nombres).
2. Vuelve a copiar las capas del ícono:
   ```sh
   cp assets/brand/svg/layers/0{2-ring,3-handle}.svg App/AppIcon.icon/Assets/
   ```
3. Si cambian colores, actualiza `App/AppIcon.icon/icon.json` y los `.colorset` de `App/Assets.xcassets` con los valores de `colors.json`.
4. `make app` y revisa el ícono en el Dock (claro, oscuro y tintado).
5. Si cambió `social-preview-1280x640.png`, súbelo de nuevo en GitHub → *Settings → Social preview*.

`brand/svg/layers/01-background.svg` no se usa en el `.icon`: el fondo lo define `fill-specializations` para que el sistema aplique su propia máscara y el modo oscuro. Para retocar el ícono con más detalle, abre `App/AppIcon.icon` en Icon Composer.
