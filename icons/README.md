# Icons

This directory holds the icon sets used by Vivaldi Swift's Speed Dial custom
icon system (see `js/custom.js` → `AssetManager` / `IconModal`).

```
icons/
├── toolbar/   Icons matching the toolbar/address bar glass style
├── sidebar/   Icons for the side panel
├── social/    Common social/site icons for Speed Dial tiles
└── custom/    User-contributed or project-specific icons
```

For supported formats, sizing recommendations, and the icon authoring
workflow, see [docs/icons.md](../docs/icons.md).

## Quick rules

- SVGs are preferred over PNGs: they scale cleanly across the tile sizes the
  Speed Dial editor supports and are automatically sanitized and
  ID-namespaced by `IconSanitizer` before use.
- Keep icons visually consistent: single-color or duotone glyphs on a
  transparent background, centered within their viewBox, generally work best
  with the glass tile background.
- Do not commit trademarked or copyrighted icon sets without verifying their
  license permits redistribution. See `docs/icons.md` for recommended
  open-licensed sources.
