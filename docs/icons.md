# Icons Guide

Vivaldi Swift's Speed Dial framework (`js/custom.js`) includes a full custom
icon system: right-click a Speed Dial tile → **Change Icon** to upload your
own SVG or PNG, reposition and resize it, or reset it back to the site's
favicon.

This guide covers supported formats, recommended sizing, the bundled folder
structure, and how to build/find good icons.

## Supported formats

| Format | Notes |
|---|---|
| **SVG** | Preferred. Scales cleanly at any tile size, is automatically sanitized (`IconSanitizer` strips `<script>`, event-handler attributes, and external references) and gets its internal IDs namespaced to avoid colliding with other injected icons. |
| **PNG** | Supported for raster icons or logos that don't exist as clean vector art. Use a transparent background. |

SVGs are strongly preferred: PNGs will look soft on high-DPI displays unless
exported at 2x–3x the target display size.

## Recommended sizes

- **Design at 64×64 or 128×128** and let the layout system scale down — the
  editing panel's `--custom-icon-size` control handles final sizing per
  tile, so you don't need to hand-tune multiple export sizes.
- Keep meaningful content inside roughly the center 80% of the viewBox/canvas
  — the glass tile background and hover animation add a small amount of
  visual padding around the edges.
- For PNG exports, 256×256 gives comfortable headroom for larger tile sizes
  and Retina/HiDPI displays without needing per-size exports.

## Folder structure

```
icons/
├── toolbar/   Icons matching the toolbar/address bar glass style
├── sidebar/   Icons for the side panel
├── social/    Common social/site icons for Speed Dial tiles
├── custom/    User-contributed or project-specific icons
└── README.md
```

Icons placed in these folders are copied into `~/Vivaldi-Swift/icons/` by the
installer and are available for the custom icon picker; icons uploaded
through the in-app editor are stored per-tile via `StorageManager` and don't
need to be added to this repo.

## Custom icon workflow

1. Right-click any Speed Dial tile → **Customize Layout** / **Change Icon**.
2. Choose the **SVG** or **PNG** tab in the icon modal and upload your file.
3. Use the properties panel to adjust size, padding, and offset — changes
   are live and scoped to that tile via the wrapper's CSS custom properties
   (see [architecture.md](architecture.md#the-injection-hierarchy)).
4. **Reset Icon** restores the site's default favicon; **Reset Layout**
   clears size/offset/padding back to defaults without removing the custom
   icon itself.

## Finding or building icons

For clean, consistently-styled SVG icons that work well with the glass tile
aesthetic, we recommend:

- **[thesvg.org](https://thesvg.org/)** — curated SVG icon search across
  multiple open icon sets.
- **[Heroicons](https://heroicons.com/)** — clean, consistent outline/solid
  icons, MIT licensed.
- **[Lucide](https://lucide.dev/)** — a large, actively maintained fork of
  Feather Icons, ISC licensed.
- **[Tabler Icons](https://tabler.io/icons)** — 4,000+ free SVG icons, MIT
  licensed.

Always check the license of any icon set before committing it to this
repository or redistributing it — the sets above are permissively licensed,
but always verify current terms on the source site.

## Contributing icons

If you'd like to contribute an icon set to `icons/`, see
[CONTRIBUTING.md](../CONTRIBUTING.md) — keep contributions to permissively
licensed or original artwork, and group related icons together (e.g. a full
social-icon set goes in `icons/social/`, not scattered across folders).
