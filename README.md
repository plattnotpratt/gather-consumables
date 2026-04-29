# Gather Consumables

Hourly content ingestion and review for Obsidian.

This project reads `content-feed.json`, pulls new YouTube and RSS/blog items, runs each item through Fabric, scores it, and writes a dated Markdown note into your Obsidian vault.

## What It Does

- Reads feeds from `content-feed.json`
- Supports `yt`, `rss`, and `blog`
- Pulls only new items based on `.content-review-state.txt`
- Uses Fabric to rate each item
- Converts Fabric's `quality-score` into a sortable `0-9` prefix
- Writes notes to `Generated/YYYY-MM-DD/`
- Adds Obsidian-safe tags like `#ai #technology #human3_0`

## Output Format

Generated files are named like:

```text
0 - Daniel Miessler - Unsupervised Learning - We're All Building a Single Digital Assistant.md
```

Scoring is inverted for sorting:

- `0` = best
- `9` = worst

## Requirements

Install these tools first:

- `bash`
- `jq`
- `curl`
- `python3`
- `xmllint`
- `fabric`

## Install on macOS

Install command line dependencies with Homebrew:

```bash
brew install jq python
```

`xmllint` ships with macOS via `libxml2` in `/usr/bin/xmllint`.

Install Fabric however you normally manage it. On this machine it is available at:

```bash
/Users/chris/.local/bin/fabric
```

Make sure Fabric is configured and working before running the script:

```bash
fabric --help
fabric -l
```

## Files

Project copy:

- `content-review.sh`
- `content-feed.json`

Active launchd copy:

- `/Users/chris/Library/Application Support/content-review/content-review.sh`
- `/Users/chris/Library/Application Support/content-review/content-feed.json`
- `/Users/chris/Library/Application Support/content-review/.content-review-state.txt`
- `/Users/chris/Library/Application Support/content-review/content-review.log`

LaunchAgent:

- `/Users/chris/Library/LaunchAgents/com.chris.content-review.plist`

## Manual Run

Run the active installed copy:

```bash
"/Users/chris/Library/Application Support/content-review/content-review.sh"
```

Run the project copy:

```bash
"/Users/chris/Desktop/projects/gather-consumables/content-review.sh"
```

## Built-In Commands

Normal run:

```bash
"/Users/chris/Library/Application Support/content-review/content-review.sh"
```

Reset today and repull today's set:

```bash
"/Users/chris/Library/Application Support/content-review/content-review.sh" --reset-today
```

Reset a specific date and repull it:

```bash
"/Users/chris/Library/Application Support/content-review/content-review.sh" --reset-date 2026-04-29
```

## Environment Overrides

You can override defaults at runtime:

```bash
VAULT_DIR="/path/to/vault" \
GENERATED_DIR="/path/to/vault/Generated" \
STATE_FILE="/tmp/content-review-state.txt" \
MAX_ITEMS_PER_FEED=3 \
RUN_DATE="2026-04-29" \
"/Users/chris/Library/Application Support/content-review/content-review.sh"
```

Supported environment variables:

- `FEED_FILE`
- `VAULT_DIR`
- `GENERATED_DIR`
- `STATE_FILE`
- `FABRIC_PATTERN`
- `MAX_ITEMS_PER_FEED`
- `RUN_DATE`

## Obsidian Output

Default output path:

```text
$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal-vault/Generated
```

Each run writes into a date folder:

```text
Generated/YYYY-MM-DD/
```

Each note includes:

- creator
- content type (`YouTube` or `Blog`)
- published date
- `0-9` impressiveness score
- Fabric quality score
- source URL
- normalized Obsidian tags
- summary
- recommendation
- raw Fabric JSON

## launchd Setup

This job is already configured to run hourly via:

```text
/Users/chris/Library/LaunchAgents/com.chris.content-review.plist
```

Reload the job after plist changes:

```bash
launchctl unload "/Users/chris/Library/LaunchAgents/com.chris.content-review.plist"
launchctl load "/Users/chris/Library/LaunchAgents/com.chris.content-review.plist"
```

Run immediately:

```bash
launchctl start com.chris.content-review
```

Check if it is loaded:

```bash
launchctl list | grep content-review
```

Watch logs:

```bash
tail -f "/Users/chris/Library/Application Support/content-review/content-review.log"
```

## Updating the Feed List

Edit `content-feed.json` and add entries like:

```json
{
  "creator": "Marcus House",
  "feed_type": "yt",
  "id": "UCBNHHEoiSF8pcLgqLKVugOw"
}
```

For YouTube:

- `feed_type`: `yt`
- `id`: channel ID

For blogs and RSS feeds:

- `feed_type`: `blog` or `rss`
- `id`: feed URL

## Troubleshooting

If the job does not run:

1. Check the log file.
2. Verify Fabric works manually.
3. Verify the LaunchAgent is loaded.
4. Verify the Obsidian vault path still exists.

Quick checks:

```bash
fabric --help
jq . "/Users/chris/Library/Application Support/content-review/content-feed.json"
bash -n "/Users/chris/Library/Application Support/content-review/content-review.sh"
launchctl list | grep content-review
```
