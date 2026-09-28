# OpenVault — Guía de marca

Gestor de secretos para desarrolladores, nativo de macOS, open source (GPL v3).
Nombre: **OpenVault** · CLI: **ovault** · Repo: github.com/Im-Fran/openvault · Autor: Fran (franciscosolis.cl)

Personalidad: confiable y sereno, preciso, nativo de Apple, abierto, pensado para desarrolladores. Emociones: tranquilidad, control, confianza.

---

## 1. Ícono de app (dirección 1a — Puerta de bóveda)

La "O" es la puerta circular de la bóveda. Una abertura en el aro y el asa que la cruza: la bóveda está abierta, pero solo un poco y solo para su dueño. El punto central ancla el dial. Sin candados, sin escudos, sin llave literal.

### Geometría (lienzo 1024 × 1024, glifo dentro del 72 % central)

| Elemento | Valor |
|---|---|
| Contenedor | squircle 1024, radio 22,37 % (`rx=229` en SVG; en Icon Composer usa la máscara del sistema) |
| Área segura del glifo | inset 14 % → `translate(143.36 143.36) scale(0.72)` |
| Aro | centro (512, 512), radio 300, trazo 72, remates redondos |
| Abertura | 43° de arco, centrada a −45° (arriba-derecha). En SVG: `stroke-dasharray="1660 225"` + `rotate(-24 512 512)` |
| Asa | línea de (660, 364) a (800, 224), trazo 72, remates redondos |
| Punto | círculo centro (512, 512), radio 66 |
| Fondo | degradado lineal 160°: `#4490FE` → `#8443D3` (oklch 0.66 0.18 258 → 0.54 0.21 300) |

### Apariencias macOS 26

| Modo | Fondo | Glifo | Archivo |
|---|---|---|---|
| Claro (default) | degradado azul→púrpura | blanco `#FFFFFF` | `svg/icon-light.svg` |
| Oscuro | `#1A1F2E` → `#0C0C18` | degradado `#82B9FF` → `#B58BF9` | `svg/icon-dark.svg` |
| Transparente | vidrio del sistema | blanco 92 % | `svg/icon-clear.svg` (referencia; el vidrio lo aporta el sistema) |
| Tintado | grafito `#393D48` → `#20242E` (el sistema aplica el tinte) | `#DBDEE5` | `svg/icon-tinted.svg` |

### Capas para Icon Composer (Liquid Glass)

Importa en este orden (`svg/layers/`):

1. `01-background.svg` — degradado. Sin vidrio, sin sombra.
2. `02-ring.svg` — aro blanco. Vidrio activado, especular bajo, sombra suave.
3. `03-handle.svg` — asa + punto. Vidrio activado, especular medio; es la capa que más "brilla".

Para el modo oscuro, cambia el fondo por el degradado grafito y aplica el degradado azul→lila a las capas 2 y 3. Para tintado y transparente, deja las capas 2 y 3 en monocromo y que el sistema aplique el material.

### Escalas verificadas

`png/icon-{16,32,64,128,256,512,1024}.png`. A 16 px se lee un anillo con una marca arriba-derecha y un punto; no añadir detalle (ticks, texto, brillos internos).

---

## 2. Isotipo monocromo

Mismo glifo sin contenedor: `svg/mark-ink.svg` (tinta), `svg/mark-white.svg`, `svg/mark-blue.svg` (Azul 600), `svg/mark-current.svg` (`currentColor`, para inline en web/README).

Usos: favicon (`png/mark-ink-32.png` o `svg/mark-current.svg`), ayuda del CLI, README, menú de barra (template image). Tamaño mínimo 16 px. Área de respeto: la mitad del radio del aro alrededor.

---

## 3. Logotipo

- **Wordmark**: "OpenVault" en SF Pro Display Semibold, tracking −2,5 %. Un solo peso; "Open" en Azul 600 (claro) / Azul 400 (oscuro), "Vault" en Tinta / blanco. `svg/wordmark-light.svg`, `svg/wordmark-dark.svg`.
- **Lockup**: ícono + wordmark, separación = 50 % del alto del ícono, alineados al centro óptico. `svg/lockup-light.svg`, `svg/lockup-dark.svg`.
- **Versión corta "ov"**: SF Pro Semibold, tracking −3 %, "o" azul, "v" tinta. Para avatares y espacios cuadrados. `svg/short-ov.svg`.
- **`ovault`** solo en SF Mono y solo en terminal / documentación de comandos. Nunca como logotipo.

Los SVG de texto usan la fuente del sistema (SF Pro en Apple, Helvetica Neue / Arial fuera). Para distribución fuera de Apple, convierte a contornos desde macOS.

---

## 4. Paleta

Azul y púrpura comparten luminosidad y croma; los neutros llevan ~1 % de frío (hue 270) para convivir con los materiales de macOS. Los colores por tipo de item (.env verde, otros gris) quedan fuera de la marca.

### Modo claro

| Rol | oklch | hex | Contraste (texto blanco/ tinta sobre él) |
|---|---|---|---|
| Azul 500 · primario (fondos, acento UI) | `oklch(0.62 0.19 260)` | `#3A81F6` | 4.1:1 (solo texto grande) |
| Púrpura 500 · secundario | `oklch(0.56 0.21 300)` | `#8A4ADA` | 5.2:1 |
| Azul 600 · texto y enlaces | `oklch(0.52 0.19 260)` | `#1961D4` | 6.3:1 |
| Tinta | `oklch(0.20 0.012 270)` | `#14161C` | 16:1 |
| Grafito · texto secundario | `oklch(0.45 0.012 270)` | `#52555C` | 6.4:1 |
| Papel · fondo | `oklch(0.985 0.003 270)` | `#F9FAFC` | 18:1 con Tinta |

### Modo oscuro

| Rol | oklch | hex | Contraste sobre Fondo |
|---|---|---|---|
| Azul 400 · primario | `oklch(0.74 0.14 260)` | `#75ABFF` | 7.9:1 |
| Púrpura 400 · secundario | `oklch(0.72 0.15 300)` | `#B48DF4` | 7.6:1 |
| Fondo | `oklch(0.17 0.015 270)` | `#0D0F16` | — |
| Superficie | `oklch(0.23 0.015 270)` | `#1A1D24` | — |
| Texto | `oklch(0.93 0.006 270)` | `#E6E8EC` | 15:1 |
| Texto secundario | `oklch(0.68 0.012 270)` | `#9598A0` | 6.6:1 |

Degradado de marca: 160°, `#4490FE` → `#8443D3`. Úsalo solo en el ícono, la pantalla de bloqueo y piezas hero; nunca detrás de texto pequeño.

`colors.json` contiene todos los hex generados.

---

## 5. Tipografía

Solo fuentes del sistema. Fallback fuera de Apple: Helvetica Neue / Helvetica / Arial y Menlo.

| Rol | Fuente | Peso | Tracking | Uso |
|---|---|---|---|---|
| Display | SF Pro Display | Semibold | −2,5 % | Hero, wordmark |
| Título | SF Pro Display | Semibold | −1,5 % | Secciones, títulos de ventana |
| Texto | SF Pro Text | Regular | 0 | Cuerpo, descripciones |
| Etiqueta | SF Pro Text | Medium | +8 %, mayúsculas | Categorías, metadatos |
| Valores | SF Mono | Regular | 0 | Secretos, rutas, comandos |

Reglas: números tabulares en listas y tablas; SF Mono solo para valores, rutas y comandos, nunca para UI; en SwiftUI usa `.font(.system(.body, design: .default))` y `.monospaced()` para valores.

---

## 6. Aplicaciones incluidas

| Pieza | Archivo |
|---|---|
| Social preview de GitHub (1280×640) | `png/social-preview-1280x640.png`, `webp/…` |
| Encabezado README (1200×300, claro) | `png/readme-header-1200x300.png`, `webp/…` |
| Lockup para README (SVG, claro/oscuro) | `svg/lockup-light.svg`, `svg/lockup-dark.svg` |

README sugerido:

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/svg/lockup-dark.svg">
    <img src="brand/svg/lockup-light.svg" width="480" alt="OpenVault">
  </picture>
</p>
<p align="center">Secretos de desarrollo cifrados y locales, con app nativa y CLI para cada repositorio.</p>
```

Badges: `license GPL-3.0` en Azul 600 (`#1961D4`), el resto en Tinta.

---

## 7. Qué no hacer

- No añadir candado, escudo ni llave al glifo.
- No inclinar, rotar ni cambiar la posición de la abertura (siempre arriba-derecha).
- No usar el degradado detrás de texto pequeño ni como fondo de UI.
- No usar verde matrix, ni estética hacker.
- No recomponer el wordmark con SF Mono o con dos pesos.
- No escalar el glifo por debajo de 16 px ni añadirle detalle a tamaños grandes.

## Índice de archivos

```
brand/
├─ BRAND.md
├─ colors.json
├─ svg/
│  ├─ icon-light.svg · icon-dark.svg · icon-tinted.svg · icon-clear.svg
│  ├─ layers/01-background.svg · 02-ring.svg · 03-handle.svg
│  ├─ mark-ink.svg · mark-white.svg · mark-blue.svg · mark-current.svg
│  ├─ wordmark-light.svg · wordmark-dark.svg · lockup-light.svg · lockup-dark.svg · short-ov.svg
├─ png/
│  ├─ icon-{16,32,64,128,256,512,1024}.png · icon-dark-{512,1024}.png · icon-tinted-{512,1024}.png
│  ├─ mark-ink-{32,128,512}.png · mark-white-{32,128,512}.png
│  ├─ social-preview-1280x640.png · readme-header-1200x300.png
└─ webp/
   ├─ icon-{512,1024}.webp · icon-dark-{512,1024}.webp · icon-tinted-{512,1024}.webp
   ├─ mark-ink-512.webp · mark-white-512.webp
   └─ social-preview-1280x640.webp · readme-header-1200x300.webp
```
