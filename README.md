# Mac Drive Cleaner

Mac Drive Cleaner is a native macOS desktop app for finding temporary files and oversized files, reviewing them in a desktop table, and sending them to Trash.

## Features

- Scan `NSTemporaryDirectory()` and `~/Library/Caches` for temporary files
- Scan the current user's home directory for large files over a configurable threshold
- Search and filter results before taking action
- Select specific files or move every visible result to Trash
- Keep cleanup reversible by using the macOS Trash instead of permanent deletion

## Build

```bash
./scripts/build_app.sh
```

The build script creates:

- `dist/Mac Drive Cleaner.app`

## Run

```bash
open "dist/Mac Drive Cleaner.app"
```

## Notes

- Large-file scanning excludes temp folders and `~/.Trash` to avoid duplicates and already-trashed files.
- The app is built with AppKit and Objective-C so it can compile against the local macOS command line tools without requiring a full Xcode install.
