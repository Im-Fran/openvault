# OpenVault — Brand Guide

**English** · [Español](BRAND.es.md)

Native macOS secrets manager for developers, open source (GPL v3).
Name: **OpenVault** · CLI: **ovault** · Repo: github.com/Im-Fran/openvault · Author: Fran (franciscosolis.cl)

Personality: trustworthy and calm, precise, Apple-native, open, built for developers. Emotions: peace of mind, control, trust.

---

## 1. App icon (direction 1a — Vault door)

The "O" is the vault's round door. A gap in the ring and the handle crossing it: the vault is open, but only slightly and only for its owner. The center dot anchors the dial. No padlocks, no shields, no literal key.

### Geometry (1024 × 1024 canvas, glyph within the central 72 %)

| Element | Value |
|---|---|
| Container | 1024 squircle, radius 22.37 % (`rx=229` in SVG; in Icon Composer use the system mask) |
| Glyph safe area | 14 % inset → `translate(143.36 143.36) scale(0.72)` |
| Ring | center (512, 512), radius 300, stroke 72, round caps |
| Gap | 43° arc, centered at −45° (top-right). In SVG: `stroke-dasharray="1660 225"` + `rotate(-24 512 512)` |
| Handle | line from (660, 364) to (800, 224), stroke 72, round caps |
| Dot | circle centered at (512, 512), radius 66 |
| Background | 160° linear gradient: `#4490FE` → `#8443D3` (oklch 0.66 0.18 258 → 0.54 0.21 300) |

### macOS 26 appearances

| Mode | Background | Glyph | File |
|---|---|---|---|
| Light (default) | blue→purple gradient | white `#FFFFFF` | `svg/icon-light.svg` |
| Dark | `#1A1F2E` → `#0C0C18` | gradient `#82B9FF` → `#B58BF9` | `svg/icon-dark.svg` |
| Clear | system glass | white 92 % | `svg/icon-clear.svg` (reference; the glass comes from the system) |
| Tinted | graphite `#393D48` → `#20242E` (the system applies the tint) | `#DBDEE5` | `svg/icon-tinted.svg` |

### Icon Composer layers (Liquid Glass)

Import in this order (`svg/layers/`):

1. `01-background.svg` — gradient. No glass, no shadow.
2. `02-ring.svg` — white ring. Glass on, low specular, soft shadow.
3. `03-handle.svg` — handle + dot. Glass on, medium specular; this is the layer that "shines" the most.

For dark mode, swap the background for the graphite gradient and apply the blue→lilac gradient to layers 2 and 3. For tinted and clear, leave layers 2 and 3 monochrome and let the system apply the material.

### Verified sizes

`png/icon-{16,32,64,128,256,512,1024}.png`. At 16 px it reads as a ring with a top-right notch and a dot; don't add detail (ticks, text, inner highlights).

---

## 2. Monochrome mark

The same glyph without the container: `svg/mark-ink.svg` (ink), `svg/mark-white.svg`, `svg/mark-blue.svg` (Blue 600), `svg/mark-current.svg` (`currentColor`, for inline use on the web/README).

Uses: favicon (`png/mark-ink-32.png` or `svg/mark-current.svg`), CLI help, README, menu bar (template image). Minimum size 16 px. Clear space: half the ring's radius all around.

---

## 3. Logo

- **Wordmark**: "OpenVault" in SF Pro Display Semibold, tracking −2.5 %. A single weight; "Open" in Blue 600 (light) / Blue 400 (dark), "Vault" in Ink / white. `svg/wordmark-light.svg`, `svg/wordmark-dark.svg`.
- **Lockup**: icon + wordmark, spacing = 50 % of the icon height, aligned to the optical center. `svg/lockup-light.svg`, `svg/lockup-dark.svg`.
- **Short "ov" version**: SF Pro Semibold, tracking −3 %, blue "o", ink "v". For avatars and square spaces. `svg/short-ov.svg`.
- **`ovault`** only in SF Mono and only in the terminal / command documentation. Never as a logo.

The text SVGs use the system font (SF Pro on Apple, Helvetica Neue / Arial elsewhere). For distribution outside Apple platforms, convert to outlines on macOS.

---

## 4. Palette

Blue and purple share lightness and chroma; the neutrals carry ~1 % coolness (hue 270) to sit well with macOS materials. Per-item-type colors (.env green, others gray) are outside the brand.

### Light mode

| Role | oklch | hex | Contrast (white/ink text on it) |
|---|---|---|---|
| Blue 500 · primary (backgrounds, UI accent) | `oklch(0.62 0.19 260)` | `#3A81F6` | 4.1:1 (large text only) |
| Purple 500 · secondary | `oklch(0.56 0.21 300)` | `#8A4ADA` | 5.2:1 |
| Blue 600 · text and links | `oklch(0.52 0.19 260)` | `#1961D4` | 6.3:1 |
| Ink | `oklch(0.20 0.012 270)` | `#14161C` | 16:1 |
| Graphite · secondary text | `oklch(0.45 0.012 270)` | `#52555C` | 6.4:1 |
| Paper · background | `oklch(0.985 0.003 270)` | `#F9FAFC` | 18:1 with Ink |

### Dark mode

| Role | oklch | hex | Contrast on Background |
|---|---|---|---|
| Blue 400 · primary | `oklch(0.74 0.14 260)` | `#75ABFF` | 7.9:1 |
| Purple 400 · secondary | `oklch(0.72 0.15 300)` | `#B48DF4` | 7.6:1 |
| Background | `oklch(0.17 0.015 270)` | `#0D0F16` | — |
| Surface | `oklch(0.23 0.015 270)` | `#1A1D24` | — |
| Text | `oklch(0.93 0.006 270)` | `#E6E8EC` | 15:1 |
| Secondary text | `oklch(0.68 0.012 270)` | `#9598A0` | 6.6:1 |

Brand gradient: 160°, `#4490FE` → `#8443D3`. Use it only on the icon, the lock screen and hero pieces; never behind small text.

`colors.json` contains all the generated hex values.

---

## 5. Typography

System fonts only. Fallback outside Apple platforms: Helvetica Neue / Helvetica / Arial and Menlo.

| Role | Font | Weight | Tracking | Use |
|---|---|---|---|---|
| Display | SF Pro Display | Semibold | −2.5 % | Hero, wordmark |
| Title | SF Pro Display | Semibold | −1.5 % | Sections, window titles |
| Body | SF Pro Text | Regular | 0 | Body copy, descriptions |
| Label | SF Pro Text | Medium | +8 %, uppercase | Categories, metadata |
| Values | SF Mono | Regular | 0 | Secrets, paths, commands |

Rules: tabular numbers in lists and tables; SF Mono only for values, paths and commands, never for UI; in SwiftUI use `.font(.system(.body, design: .default))` and `.monospaced()` for values.

---

## 6. Included applications

| Piece | File |
|---|---|
| GitHub social preview (1280×640) | `png/social-preview-1280x640.png`, `webp/…` |
| README header (1200×300, light) | `png/readme-header-1200x300.png`, `webp/…` |
| README lockup (SVG, light/dark) | `svg/lockup-light.svg`, `svg/lockup-dark.svg` |

Suggested README:

```html
<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="brand/svg/lockup-dark.svg">
    <img src="brand/svg/lockup-light.svg" width="480" alt="OpenVault">
  </picture>
</p>
<p align="center">Encrypted, local development secrets, with a native app and a CLI for every repository.</p>
```

Badges: `license GPL-3.0` in Blue 600 (`#1961D4`), the rest in Ink.

---

## 7. Don'ts

- Don't add a padlock, shield or key to the glyph.
- Don't tilt, rotate or move the gap (always top-right).
- Don't use the gradient behind small text or as a UI background.
- Don't use matrix green or a hacker aesthetic.
- Don't rebuild the wordmark with SF Mono or with two weights.
- Don't scale the glyph below 16 px or add detail to it at large sizes.

## File index

```
brand/
├─ BRAND.md · BRAND.es.md
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
