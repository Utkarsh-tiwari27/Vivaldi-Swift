# Contributing to Vivaldi Swift

Thanks for your interest in improving Vivaldi Swift. This document covers how
the project is organized and how to get a change merged.

## Before you start

- Search existing [issues](../../issues) and [pull requests](../../pulls) to
  avoid duplicate work.
- For anything larger than a small fix (new modules, structural changes to the
  patch/install system), open an issue first to discuss the approach.
- For security-sensitive reports, follow [SECURITY.md](SECURITY.md) instead of
  opening a public issue.

## Project layout

```
vivaldi-swift/
├── css/            Production stylesheet (single-file build, module sections)
├── js/              Production custom.js (Speed Dial framework, etc.)
├── version.json     Version metadata read by the updater
├── install/         Installers, uninstallers, updaters, bootstrap scripts,
│                    and per-OS patch engines (install/patch/)
├── icons/           Bundled and user-contributed icon sets
├── docs/             Installation, architecture, FAQ, troubleshooting, icons
└── screenshots/     Repository preview images
```

See [docs/architecture.md](docs/architecture.md) for how these pieces fit
together at runtime.

## Development setup

You do not need Vivaldi installed to work on documentation, but you do need it
to test CSS/JS or installer changes end to end.

1. Fork and clone the repository.
2. Make your changes on a feature branch: `git checkout -b fix/short-description`.
3. If you're testing installer or patch script changes, run them against a
   real Vivaldi install on the target OS — there is no meaningful way to
   fully mock a browser's `resources/vivaldi/window.html` layout.
4. Keep changes scoped. A pull request that touches CSS, install scripts, and
   docs at once is harder to review than three focused PRs.

## Coding guidelines

### CSS (`css/vivaldi_swift.css`)

- The stylesheet is organized as independent module blocks (see the table of
  contents comment at the top of the file). Keep new rules inside the
  relevant module, or add a new module block with its own header comment.
- Prefer CSS custom properties (`--variable-name`) for anything themeable,
  scoped to the module's own `:root`/selector block rather than shared
  globals, matching the existing architecture.
- Do not introduce dependencies on external fonts, images, or web services.

### JavaScript (`js/custom.js`)

- Follow the existing module structure (`StorageManager`, `IconSanitizer`,
  `AssetManager`, `Renderer`, `EditingEngine`, `ContextMenu`, `IconModal`,
  `Observer`, etc.) documented in the file header.
- Never mutate Vivaldi's native DOM nodes or their `transform`/`left`/`top`/
  `z-index` properties directly — all customization must live inside the
  injected wrapper elements. This constraint exists because Vivaldi's own
  GPU layout pipeline owns those nodes; fighting it causes flicker and
  crashes on update.
- Use a single debounced `MutationObserver` rather than adding new observers.
- Sanitize any user-supplied SVG/icon content through `IconSanitizer` before
  it touches the DOM.

### Shell / PowerShell (`install/`)

- Scripts must remain POSIX-`bash` (Linux/macOS) or Windows PowerShell 5.1+
  compatible — no bashisms in scripts that also need to run in restricted
  environments, no PowerShell Core-only cmdlets without a fallback.
- Every destructive operation (patching `window.html`, deleting files) must
  be preceded by a backup or an explicit confirmation.
- New code paths should log through the existing `log()` / `Write-Log`
  helpers so operations remain traceable in `~/Vivaldi-Swift/logs/`.
- Scripts should fail loudly with a clear, actionable message — never fail
  silently.

## Commit messages

Use short, descriptive commit messages in the imperative mood:

```
Fix macOS patch script failing on spaces in Applications path
Add FAQ entry for Vivaldi snapshot builds
```

## Pull requests

- Fill out the PR template completely, including which platform(s) you
  tested on.
- Include before/after screenshots for visual changes.
- Keep the diff focused; avoid unrelated reformatting.
- A maintainer will review and may request changes before merging.

## Reporting bugs

Use the **Bug report** issue template and include:

- OS and Vivaldi version
- Output of the relevant log file in `~/Vivaldi-Swift/logs/`
- Steps to reproduce

## License

By contributing, you agree that your contributions will be licensed under the
project's [MIT License](LICENSE).
