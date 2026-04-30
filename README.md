# Gather Consumables

Pull content from YouTube and RSS feeds, score it with Fabric, and save the results into Obsidian.

## Files

- `content-review.sh`: pulls new content and writes Markdown notes
- `add-feed.sh`: adds a feed to `content-feed.json`
- `install.sh`: installs the scripts and sets up `launchd`
- `content-feed.json`: your feed list

## Requirements

- macOS
- `jq`
- `python3`
- `fabric`
- `curl`
- `xmllint`

Install the missing command line tools:

```bash
brew install jq python
```

`xmllint` already ships with macOS.

Make sure Fabric is installed and working:

```bash
fabric --help
fabric -l
```

## Install

From this folder, run:

```bash
chmod +x *.sh
./install.sh
```

That will:

- copy the scripts into `~/Library/Application Support/content-review/`
- create a `launchd` job
- start the job

## Commands

Run the review job now:

```bash
~/Library/Application\ Support/content-review/content-review.sh
```

Reset today and rerun:

```bash
~/Library/Application\ Support/content-review/content-review.sh --reset-today
```

Reset a specific date and rerun:

```bash
~/Library/Application\ Support/content-review/content-review.sh --reset-date 2026-04-29
```

Show help:

```bash
~/Library/Application\ Support/content-review/content-review.sh --help
```

## Feed Commands

List current feeds:

```bash
~/Library/Application\ Support/content-review/add-feed.sh --list
```

Add a YouTube feed:

```bash
~/Library/Application\ Support/content-review/add-feed.sh \
  --creator "Marcus House" \
  --type yt \
  --id "UCBNHHEoiSF8pcLgqLKVugOw"
```

Add an RSS feed:

```bash
~/Library/Application\ Support/content-review/add-feed.sh \
  --creator "Example Blog" \
  --type rss \
  --id "https://example.com/feed.xml"
```

Add a blog feed:

```bash
~/Library/Application\ Support/content-review/add-feed.sh \
  --creator "Example Blog" \
  --type blog \
  --id "https://example.com/feed.xml"
```

Show feed script help:

```bash
~/Library/Application\ Support/content-review/add-feed.sh --help
```

## Output

Notes are written to:

```text
~/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal-vault/Generated/YYYY-MM-DD/
```

Filenames start with a score:

- `0` = best
- `9` = worst

Example:

```text
0 - Daniel Miessler - Unsupervised Learning - We're All Building a Single Digital Assistant.md
```

Each note includes:

- creator
- content type
- published date
- score
- source URL
- Obsidian tags
- summary
- recommendation
- Fabric JSON

## launchd

The installer creates this job:

```text
~/Library/LaunchAgents/com.gatherconsumables.content-review.plist
```

Start it manually:

```bash
launchctl start com.gatherconsumables.content-review
```

Reload it:

```bash
launchctl unload "$HOME/Library/LaunchAgents/com.gatherconsumables.content-review.plist"
launchctl load "$HOME/Library/LaunchAgents/com.gatherconsumables.content-review.plist"
```

Check that it is loaded:

```bash
launchctl list | grep gatherconsumables
```

Watch the log:

```bash
tail -f "$HOME/Library/Application Support/content-review/content-review.log"
```

## Notes

- `content-review.sh` uses the `label_and_rate` Fabric pattern by default.
- The default vault path is `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal-vault`.
- If you change the local `content-feed.json`, run `./install.sh` again to copy it into the installed location.
