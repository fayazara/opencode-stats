# OpenCode Stats

A native macOS menubar app that shows your [OpenCode](https://opencode.ai) usage stats at a glance.

Reads directly from the local OpenCode SQLite database -- no server or API keys needed.

## What it shows

- Total cost, sessions, messages, days active
- Today's spend in the menu bar
- Daily cost chart (last 30 days, respects time filter)
- Token breakdown (input, output, reasoning, cache read/write)
- Tool usage
- Per-project and per-model cost breakdown
- Recent sessions with Live/Recent/Idle activity badges
- Installed MCP servers
- Time filter (24h, 7d, 30d, 90d, all time)
- Daily and monthly cost budget alerts (menu bar turns orange, OS notification)
- CSV and JSON export of all stats

## Requirements

- macOS 15.0+
- [OpenCode](https://opencode.ai) installed and used at least once

## Install

Download the latest DMG from [Releases](https://github.com/fayazara/opencode-stats/releases).

## Build from source

Open `OpenCode Stats.xcodeproj` in Xcode and run.

## Author

[Fayaz Ahmed](https://x.com/fayazara)
