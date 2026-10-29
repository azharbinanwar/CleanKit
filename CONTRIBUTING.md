# Contributing

Contributions are welcome. CleanKit deletes files on people's Macs, so the one
rule above all others: **when in doubt, don't delete it.**

## Getting started

```sh
git clone https://github.com/azharbinanwar/CleanKit.git
cd CleanKit
open CleanKit.xcodeproj
```

Requires Xcode 26+ and macOS 15+. Press Cmd+R to run.

Running from Xcode builds **CleanKit Dev**: an orange icon and its own bundle ID
(`com.kodeelite.cleankit.dev`), so it never touches an installed CleanKit.
Updates are disabled in it. Grant it Full Disk Access separately in
System Settings → Privacy & Security.

## Branches and pull requests

- `main` always builds. Never commit to it directly; open a pull request.
- Name branches by type: `feat/simulator-runtimes`, `fix/uninstaller-paths`,
  `docs/…`, `chore/…`, `ci/…`.
- Keep one change per pull request. They are squash-merged, so the title becomes
  the commit message: write it as a short sentence in the present tense, e.g.
  "Add Bun install cache to Bun Cache".
- Every pull request is built automatically; it must pass before merging.

## Adding a cleanup category

Categories live in
`CleanKit/Features/MacCleaner/Domain/Entities/CleanupCategory.swift`, in the
`all` array. Then add its name to a group in `CleanerGroup.all`
(`CleanKit/Features/MacCleaner/Presentation/Views/MacCleanerView.swift`), or it
won't appear.

```swift
CleanupCategory(
    name: "Your Tool Cache",
    icon: "folder",                              // SF Symbol name
    paths: ["~/Library/Caches/com.yourtool"],
    subpath: nil,
    shellCommand: nil,
    info: "What it is. What happens after it's cleaned.",
    safety: .safe
),
```

| Field | Use |
|---|---|
| `paths` | Folders whose **contents** are deleted (the folder itself stays). `~` is your home. One `/*/` wildcard is allowed, e.g. `~/Library/Application Support/Google/Chrome/*/GPUCache` matches every Chrome profile. |
| `subpath` | Appended to every child of each path (e.g. per-version SDK caches). |
| `shellCommand` | Cleans with a command instead, e.g. `docker system prune -f`. |
| `measureOnly` | `paths` are only measured for size; `shellCommand` does the cleaning. |
| `keepNewestPrefix` | For versioned folders like `AndroidStudio2026.1.3`: cleans old versions, keeps the newest, the most recently used, and the one an installed IDE is using. |
| `requiresElevation` | The command needs an administrator password. Avoid it if you can. |
| `info` | One line: what it is, and what happens after cleaning. Users read this before deleting. |

### Choosing `safety`

This is the most important field. It decides how the item is presented and
whether it's selected by default.

| Value | Label | Meaning | Examples |
|---|---|---|---|
| `.safe` | Safe | Rebuilt automatically, nothing to download | Build caches, DerivedData, app caches |
| `.caution` | Re-downloads | Comes back, but costs a download | npm/Gradle caches, simulator runtimes |
| `.data` | Your data | Can't be rebuilt. Never selected by default, and cleaning it requires an extra confirmation | iOS backups, Xcode Archives, downloaded models, emulators |

If you aren't sure, choose the stricter one.

### Rules for paths

- Only point at caches or data that are safe as described. Never at a folder
  that also holds settings, documents, or credentials.
- Prefer the narrowest folder that does the job (`…/Chrome/Default/GPUCache`,
  not `…/Chrome`).
- Never build a path from a value that can be empty: an empty value turns
  `~/Library/Caches/<id>` into all of `~/Library/Caches`.

## Testing a change

There's no automated test suite yet. Before opening a pull request:

1. Run CleanKit Dev and scan. Check the new item appears with a believable size.
2. Clean **only** that item, and confirm exactly the expected files went.
3. Use the tool afterwards (rebuild the project, relaunch the app) to confirm it
   still works.

## Reporting bugs

Open an issue with what CleanKit did, what you expected, and your macOS and
CleanKit versions.

**Security problems** (deleting the wrong files, admin commands, the updater):
don't open a public issue. See [SECURITY.md](SECURITY.md).

## Releases (maintainer)

1. Bump `MARKETING_VERSION` in Xcode (e.g. 1.0.5) in a pull request and merge it.
2. `git tag v1.0.5 && git push origin v1.0.5`

The release workflow builds and signs the app, makes `CleanKit.dmg` and its
checksum, and publishes the GitHub release. The tag must match the app version.
See [docs/signing.md](docs/signing.md) for the signing setup.
