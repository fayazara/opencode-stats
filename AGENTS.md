# AGENTS.md

Guidance for AI coding agents and new contributors working in this repository.
Keep this file up to date when project structure, build steps, or conventions change.

## What this project is

OpenCode Stats is a native macOS menu bar app that displays local OpenCode usage
statistics. It is a SwiftUI application built with Xcode. It is not a web app, so
"run it locally" means building and launching the `.app`, not starting a dev server.

The app reads the local OpenCode SQLite database directly in read-only mode. There
is no backend, network API, or API key. The app sandbox is intentionally disabled
so the app can read the database from the user's home directory.

## Requirements

- macOS 15.6 or newer
- Xcode 26 or newer
- OpenCode installed and run at least once, so the database exists at
  `~/.local/share/opencode/opencode.db`

## Build and run

Open `OpenCode Stats.xcodeproj` in Xcode, select the "OpenCode Stats" scheme, and Run.

The first build resolves the Sparkle Swift package, so it needs network access.

The project ships with a specific `DEVELOPMENT_TEAM` and automatic signing. To build
on your own machine, set your own team in Xcode under the target's Signing and
Capabilities tab, or sign to run locally. Do not commit your personal team ID.

The app has no main window. After launching, look for the stats icon in the macOS
menu bar and click it to open the popover.

## Project layout

All Swift sources live in the `OpenCode Stats/` directory.

| File                       | Responsibility                                            |
| -------------------------- | --------------------------------------------------------- |
| `OpenCode_StatsApp.swift`  | App entry point, `AppDelegate`, menu bar status item      |
| `ContentView.swift`        | Main popover UI, tabs, time filter menu                   |
| `OpenCodeDatabase.swift`   | Reads and aggregates stats from the SQLite database       |
| `SettingsView.swift`       | Settings window UI                                        |
| `SettingsWindowManager.swift` | Manages the settings window lifecycle                  |
| `UpdaterManager.swift`     | Sparkle auto-update integration                           |
| `ProviderIcon.swift`       | Provider and model icon rendering                         |
| `PopoverBackground.swift`  | Popover background styling                                |
| `Helpers.swift`            | Shared formatting and utility helpers                     |

## Conventions

- Database access is read-only. Open the database with `SQLITE_OPEN_READONLY` and
  never write to it.
- The database path is derived from the user's home directory, not hardcoded.
- The time filter uses rolling windows. `daysFilter` is the number of days back from
  now, and `nil` means all time.
- App sandbox stays disabled. The entitlements file sets
  `com.apple.security.app-sandbox` to false so the database is readable.

## Dependencies

- Sparkle, for in-app updates, added as a Swift package and resolved by Xcode.
