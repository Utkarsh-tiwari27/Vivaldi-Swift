# Frequently Asked Questions

### Is this an official Vivaldi product?

No. Vivaldi Swift is an independent, community-made modification and is not
affiliated with, endorsed by, or sponsored by Vivaldi Technologies AS. It
works by injecting CSS/JS into the browser's own UI files — see
[architecture.md](architecture.md) for how.

### Is it safe? Will it get my Vivaldi flagged or break something?

It only modifies `window.html` (adding two reference tags) and copies two
files (`vivaldi_swift.css`, `custom.js`) into Vivaldi's resource directory.
No telemetry, no network access, no browser extension, no changes to your
browsing data, passwords, history, or sync. Every modification is backed up
first and fully reversible via the uninstall script. See
[SECURITY.md](../SECURITY.md) for the project's security scope.

### Will a Vivaldi update break it?

Vivaldi updates overwrite `window.html`, which does remove the patch. This
is expected and handled automatically — the installer sets up a background
task that reapplies the patch within hours (or immediately at next login).
See [update-system.md](update-system.md) for full detail, or just relaunch
Vivaldi after running the patch script manually if you don't want to wait.

### My Speed Dial custom icons disappeared after an update — did I lose them?

No. Custom icon assignments are stored by `StorageManager` with a versioned
schema (currently v4.1, with automatic migration from older schema
versions) separate from Vivaldi's own profile data, not baked into
`window.html`. If icons look reset, it usually means the *layout wrapper*
CSS wasn't loaded yet — restart Vivaldi or manually run the patch script for
your OS (see [update-system.md](update-system.md#manual-reapplication)).

### Does this work with Vivaldi Snapshot builds?

Yes, on Linux the patch engine detects both `vivaldi-bin` and
`vivaldi-snapshot-bin` installs under `/opt`. On macOS and Windows, snapshot
builds install to the same locations as stable and are detected the same
way. Snapshot builds change more frequently, so you may see the patch
reapply more often — this is expected and automatic.

### Does this work with the Vivaldi macOS App Store / other distribution channels?

The patch engine looks for `Vivaldi.app` in `/Applications`,
`~/Applications`, and Homebrew's Caskroom. Other sandboxed distribution
channels (if any) that restrict write access to the app bundle are not
currently supported — please open an issue with details if you hit this.

### Can I use only the CSS, or only the JS?

Yes. The install/patch scripts inject both by default, but you can apply
just one manually by editing `window.html` yourself and adding only the
`<link>` or only the `<script>` tag, then copying the corresponding file.
This isn't managed by the automatic reapply task unless you edit the patch
engine's marker logic to match.

### Does this affect performance?

The CSS and JS are scoped, lightweight, and use hardware-accelerated
properties (transforms, opacity) for animation. The custom icon system uses
a single debounced `MutationObserver` rather than per-tile observers to keep
overhead low. No measurable startup delay has been observed in testing, but
please open an issue if you notice otherwise on your setup.

### How do I customize the design further?

See [architecture.md](architecture.md) for the CSS module structure and
[icons.md](icons.md) for the custom icon system. Because each CSS module
owns its own custom properties rather than sharing a global token set,
you can safely override a single module's variables in your own local
`.local.css` override (see `.gitignore`) without needing to fork the whole
stylesheet.

### I found a bug / have a feature idea — where do I go?

Open an issue using the appropriate template — see
[CONTRIBUTING.md](../CONTRIBUTING.md#reporting-bugs). For anything involving
a possible security issue, use [SECURITY.md](../SECURITY.md) instead of a
public issue.
