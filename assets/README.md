# assets/

**English** · [Español](README.es.md)

OpenVault branding. **Source of truth:** everything in `brand/` comes as-is from `App icon design briefing.zip` (generated with Claude Design, 2026-09-27). The full guide —icon geometry, palette, typography and what not to do— is in [`brand/BRAND.md`](brand/BRAND.md); the hex values are in [`brand/colors.json`](brand/colors.json).

```
brand/
├─ BRAND.md, BRAND.es.md, colors.json
├─ svg/      icons (light/dark/tinted/clear), Icon Composer layers,
│            marks, wordmarks, lockups and "ov"
├─ png/      icon at 16–1024 px, marks, README header and social preview
└─ webp/     lightweight web versions of the above
```

## Where each file is used

| Use | Project file | How | Source |
|---|---|---|---|
| App icon (Liquid Glass) | `App/AppIcon.icon/Assets/02-ring.svg`, `03-handle.svg` | **copy** | `brand/svg/layers/` |
| Icon background gradient (light and dark) | `App/AppIcon.icon/icon.json` → `fill-specializations` | values | `BRAND.md` §1 (`#4490FE → #8443D3`, dark `#1A1F2E → #0C0C18`) |
| Lock screen mark | `App/Assets.xcassets/BrandMark.imageset/mark.svg` | **symlink** | `brand/svg/mark-ink.svg` (rendered as template) |
| App accent color | `App/Assets.xcassets/AccentColor.colorset` | values | Blue 500 `#3A81F6` / Blue 400 `#75ABFF` |
| Brand gradient in SwiftUI (`Brand.gradient`) | `App/Assets.xcassets/BrandStart`, `BrandEnd` | values | light `#4490FE → #8443D3`, dark `#82B9FF → #B58BF9` |
| README header | `README.md` | direct reference | `brand/svg/lockup-light.svg`, `lockup-dark.svg` |
| GitHub social preview | *Settings → Social preview* (manual upload, GitHub has no API for it) | upload | `brand/png/social-preview-1280x640.png` |

### Why are the icon layers copies and not symlinks?

The Icon Composer exporter used by `actool` fails with symlinks inside a `.icon` (`Icon export exited with status 255`). Asset catalogs (`.xcassets`) do follow them, which is why `BrandMark` is a symlink.

## Updating the branding

1. Replace the files in `brand/` (same names).
2. Copy the icon layers again:
   ```sh
   cp assets/brand/svg/layers/0{2-ring,3-handle}.svg App/AppIcon.icon/Assets/
   ```
3. If colors change, update `App/AppIcon.icon/icon.json` and the `.colorset`s in `App/Assets.xcassets` with the values from `colors.json`.
4. Run `make app` and check the icon in the Dock (light, dark and tinted).
5. If `social-preview-1280x640.png` changed, upload it again in GitHub → *Settings → Social preview*.

`brand/svg/layers/01-background.svg` is not used in the `.icon`: the background is defined by `fill-specializations` so the system applies its own mask and dark mode. For finer icon tweaks, open `App/AppIcon.icon` in Icon Composer.
