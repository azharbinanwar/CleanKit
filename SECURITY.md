# Security Policy

CleanKit deletes files, can ask for an administrator password, and installs its
own updates, so security reports are taken seriously.

## Reporting a vulnerability

Please **do not open a public issue** for a security problem.

Report it privately on GitHub instead:
[Security → Report a vulnerability](https://github.com/azharbinanwar/CleanKit/security/advisories/new).
Only the maintainer can see the report.

Please include:

- what an attacker could do, and how (steps to reproduce)
- the CleanKit version (Settings shows it) and your macOS version
- whether it needs anything unusual to work, such as a specific file layout

You will get a reply within 14 days. Once a fix is released, the advisory is
published with credit to you, unless you prefer to stay anonymous.

## Supported versions

Only the latest release receives fixes. CleanKit updates itself, or you can
re-run the [install command](README.md#quick-install).

## In scope

- deleting files outside what a category, scan, or uninstall said it would
- commands run with administrator rights that can be influenced by another
  user or app
- the updater or `install.sh` accepting a download that isn't an official release

Bugs where CleanKit removes less than it should, or reports a wrong size, are
normal issues; please open those publicly.
