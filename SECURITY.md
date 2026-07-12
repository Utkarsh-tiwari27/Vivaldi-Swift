# Security Policy

## Scope

Vivaldi Swift modifies the local Vivaldi browser UI by injecting CSS/JS into
`window.html` and running local install/patch scripts with the permissions of
the invoking user (and, where the Vivaldi install directory requires it,
elevated permissions via `sudo` or an Administrator PowerShell session).

Security-relevant areas include:

- The `install/` scripts and patch engines (privilege handling, backup
  integrity, file write targets).
- `js/custom.js`, specifically icon/SVG handling (`IconSanitizer`,
  `AssetManager`) since it processes user-supplied files.
- Any future auto-update mechanism.

## Supported Versions

| Version | Supported |
| ------- | --------- |
| Latest `main` | ✅ |
| Tagged releases (last 2 minor versions) | ✅ |
| Older releases | ❌ |

## Reporting a Vulnerability

**Do not open a public issue for security reports.**

Instead, use GitHub's private vulnerability reporting for this repository
(**Security** tab → **Report a vulnerability**), which delivers the report
directly to maintainers without disclosing it publicly.

If private reporting is unavailable to you, open an issue titled
`Security contact request` with no technical details, and a maintainer will
follow up with a private channel.

Please include:

- A description of the issue and its potential impact
- Steps to reproduce (OS, Vivaldi version, exact script/version invoked)
- Any relevant log output from `~/Vivaldi-Swift/logs/`

## What to expect

- Acknowledgement within 5 business days.
- An initial assessment and, where applicable, a fix timeline within 14 days.
- Credit in the changelog for the disclosing party, unless you prefer to
  remain anonymous.

## Out of scope

- Vulnerabilities in Vivaldi itself — report those to Vivaldi Technologies AS
  directly.
- Issues requiring an already-compromised local machine (this tool operates
  with local user/admin privileges by design, like any local dotfile/theme
  manager).
