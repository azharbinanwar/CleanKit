# Contributing

Contributions are welcome! Here's how to help.

## Adding a New Cleanup Category

All categories are defined in `CleanKit/CleanupCategory.swift`.

Add a new entry to the `all` array:

```swift
CleanupCategory(
    name: "Your Tool Cache",
    icon: "folder",           // SF Symbol name
    paths: ["~/Library/Caches/com.yourtool"],
    shellCommand: nil         // or a shell command string if needed
),
```

- `paths` — use `~` for home directory, supports multiple paths per category
- `shellCommand` — use this when deletion requires a CLI command (e.g. `docker system prune -f`)
- `icon` — any [SF Symbol](https://developer.apple.com/sf-symbols/) name

## Reporting Issues

Open an issue with:
- What the app did
- What you expected
- macOS version and Xcode version

## Pull Requests

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-change`
3. Make your change
4. Open a PR with a clear description
