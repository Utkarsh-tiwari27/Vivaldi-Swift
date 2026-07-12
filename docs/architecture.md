# Architecture

This document explains how Vivaldi Swift's pieces fit together: the CSS, the
JS, the patch mechanism, and the update flow that keeps everything working
across Vivaldi's frequent auto-updates.

## Why patching is necessary

Vivaldi is a Chromium-based browser; its UI (toolbar, Speed Dial, panel, tab
bar) is itself an HTML/CSS/JS application (`window.html` and friends) bundled
inside the browser's `resources/vivaldi` directory, not a native OS UI. That
means it can be restyled and extended the same way a webpage can — by loading
additional CSS and JS into that page. Vivaldi doesn't expose a supported
"load my own CSS/JS" toggle for this depth of customization on every release
channel, so Vivaldi Swift injects the references directly into
`window.html`.

The tradeoff: **every Vivaldi update overwrites `window.html`**, silently
removing the injected `<link>`/`<script>` tags. This is the reason the
install/patch/update system exists — see [update-system.md](update-system.md)
for how that's handled automatically.

## Component overview

```
┌─────────────────────────────┐
│         Vivaldi.app          │  ← the actual browser (not modified except
│  resources/vivaldi/          │     window.html, and only 2 injected tags)
│    window.html  (patched)    │
│    vivaldi_swift.css (copy)  │
│    custom.js (copy)          │
└──────────────┬───────────────┘
               │ loaded at UI startup
               ▼
┌─────────────────────────────┐      ┌──────────────────────────────┐
│   css/vivaldi_swift.css      │      │        js/custom.js           │
│   (this repo, source of      │      │   (this repo, source of       │
│    truth — copied into       │      │    truth — copied into        │
│    Vivaldi's resource dir)   │      │    Vivaldi's resource dir)    │
└─────────────────────────────┘      └──────────────────────────────┘
```

The files under `css/` and `js/` in this repository are the source of truth.
The copies inside Vivaldi's own `resources/vivaldi/` directory are
disposable — they're overwritten by every install/patch run and by every
Vivaldi update (which is exactly why they need to be reapplied).

## CSS (`css/vivaldi_swift.css`)

Single-file build assembled from independently-developed modules, each
retaining its own header comment and (where applicable) its own `:root`
custom-property block, rather than sharing a single global token set. This
mirrors how the modules were originally developed and iterated on as
standalone files:

| Module | Covers |
|---|---|
| Toolbar & Address Bar | Toolbar capsule, address field material, buttons, icons, URL text |
| Address Dropdown | Omnibox / address bar suggestion dropdown |
| Search Bar | Speed Dial search field |
| Search Dropdown | Speed Dial search suggestion dropdown |
| Speed Dial | Speed Dial tiles / liquid glass tile system |
| Speed Dial Context Menu | Right-click menu, icon modal, editing panel |
| Panel | Side panel (bookmarks/notes/downloads/etc.) glass theme |
| Tab Bar | Tab strip / tab material system |

Each module is intentionally self-contained so it can be worked on, tested,
and (eventually) toggled independently without breaking the others.

## JS (`js/custom.js`)

A framework for the Speed Dial custom-icon system, organized into modules
documented in the file's own header comment:

- **StorageManager** — schema-versioned persistence (currently v4.1, with
  migration from v3 and v4.0 records).
- **IconSanitizer** — security pass over uploaded SVGs (strips scripts/event
  handlers), viewBox normalization, ID namespacing to avoid collisions
  between multiple injected icons.
- **AssetManager** — SVG/PNG validation, normalization, and preview
  generation.
- **Renderer** — `renderLayoutWrapper`, `renderSVG`, `renderPNG`,
  `applyLayout` (wrapper-level), `applyTransforms` (icon-level).
- **EditingEngine** — Pointer Events-based icon move/resize, and the
  properties panel for size/padding/scale.
- **ContextMenu** — Change Icon, Reset Icon, Remove Speed Dial entry,
  Customize Layout, Reset Layout.
- **IconModal** — the dual SVG/PNG upload tab flow.
- **Observer** — a single debounced `MutationObserver` watching for Speed
  Dial DOM changes, rather than one observer per tile.

### The injection hierarchy

Vivaldi's native Speed Dial DOM must never be resized, replaced, or have its
positioning properties (`transform`, `left`, `top`, `z-index`) touched
directly — those belong to Vivaldi's own GPU-accelerated layout pipeline, and
fighting it causes flicker, layout thrash, or crashes across Vivaldi
versions. Instead, all customization lives inside wrapper elements injected
at a safe point in the tree:

```
.SpeedDial
  .thumbnail-favicon          ← Vivaldi's safe injection point
    .custom-layout-wrapper    ← padding · scale   (CSS vars)
      .custom-icon-wrapper    ← size · offset      (CSS vars)
        <svg> or <img>
```

Layout is driven entirely by CSS custom properties on the wrapper elements
(`--custom-icon-size`, `--custom-icon-offset-x`, `--custom-icon-offset-y`,
`--custom-padding`, `--custom-wrapper-scale`), so Renderer/EditingEngine
changes never need to touch Vivaldi's own nodes.

## Patch mechanism

See [update-system.md](update-system.md) for the full detail on the
patch engines under `install/patch/` and how re-application is scheduled.
In short: the patch engine finds `window.html`, checks for the injected
`<link>`/`<script>` markers (idempotency check), backs the file up if a
patch is actually needed, injects the markers, and copies the current
`css/vivaldi_swift.css` and `js/custom.js` alongside it.

## Directory layout

- `css/`, `js/` — source of truth, versioned in this repo.
- `version.json` — small metadata file (current version, minimum supported
  Vivaldi version, patch schema version) read by the updater to decide
  whether an update is actually needed.
- `install/` — installers (`install-*`), uninstallers (`uninstall-*`),
  updaters (`update-*`), one-line bootstrap scripts (`bootstrap.sh` /
  `bootstrap.ps1`), and per-OS patch engines (`install/patch/patch-*`).
- `icons/` — bundled icon sets for the Speed Dial custom icon system.
- `~/Vivaldi-Swift/` (created on the user's machine, **not** part of this
  repo) — the working install directory: copies of `css/`/`js/`, `icons/`,
  `version.json`, `backups/` (timestamped `window.html` snapshots), `logs/`,
  and `bin/` (copies of the patch/uninstall/update scripts used by the
  scheduled background task and by manual runs).
