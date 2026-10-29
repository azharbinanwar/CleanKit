# Roadmap

Where CleanKit is heading. There are no dates: things ship when they're ready
and safe. Want something here sooner, or have an idea? Open an issue or
upvote one with a 👍.

## Planned

- **Project build-folder sweeper.** Find `node_modules`, `build`, `Pods`,
  `.dart_tool` and similar folders in projects you haven't touched for months,
  and clean them per project.
- **AI tool cleanup.** Caches and old versions left by AI coding tools, plus
  local models from Ollama and LM Studio, listed per model so you choose what
  goes.
- **Port Manager.** See which process is using each port and stop it.
- **Hosts file editor.** View and edit `/etc/hosts` without the Terminal.

## Ideas we're considering

- Warn before cleaning the cache of an app that's running.
- A menu bar app showing free space, with a quick clean.
- Scheduled cleanups.
- Signing and notarizing releases with an Apple Developer ID, so the first
  launch shows no security warning.

## Recently shipped

- Pick individual simulator runtimes, DerivedData projects, backups and more
  before cleaning.
- Old simulator runtimes, Android system images and old Android Studio
  settings.
- Real sizes for Docker and unavailable simulators, measured during the scan.
- Large File Finder and Duplicate Finder move files to the Trash.
- An extra confirmation before deleting anything marked "Your data".
