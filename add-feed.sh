#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEED_FILE="${FEED_FILE:-$SCRIPT_DIR/content-feed.json}"
CREATOR=""
FEED_TYPE=""
FEED_ID=""
LIST_ONLY=false

print_help() {
  cat <<'EOF'
Usage:
  ./add-feed.sh --creator "Name" --type yt --id CHANNEL_ID
  ./add-feed.sh --creator "Name" --type rss --id "https://example.com/feed.xml"
  ./add-feed.sh --creator "Name" --type blog --id "https://example.com/feed.xml"
  ./add-feed.sh --list

Options:
  --creator NAME       Display name for the feed
  --type TYPE          One of: yt, rss, blog
  --id VALUE           YouTube channel ID or feed URL
  --list               Print the current feeds
  --help               Show this help text
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

for cmd in jq mktemp mv; do
  require_cmd "$cmd"
done

while [[ $# -gt 0 ]]; do
  case "$1" in
    --creator)
      CREATOR="${2:-}"
      shift 2
      ;;
    --type)
      FEED_TYPE="${2:-}"
      shift 2
      ;;
    --id)
      FEED_ID="${2:-}"
      shift 2
      ;;
    --list)
      LIST_ONLY=true
      shift
      ;;
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

if [[ ! -f "$FEED_FILE" ]]; then
  printf 'Feed file not found: %s\n' "$FEED_FILE" >&2
  exit 1
fi

if $LIST_ONLY; then
  jq -r '.[] | "\(.feed_type) | \(.creator) | \(.id)"' "$FEED_FILE"
  exit 0
fi

if [[ -z "$CREATOR" || -z "$FEED_TYPE" || -z "$FEED_ID" ]]; then
  print_help >&2
  exit 1
fi

case "$FEED_TYPE" in
  yt|rss|blog)
    ;;
  *)
    printf 'Invalid feed type: %s\n' "$FEED_TYPE" >&2
    exit 1
    ;;
esac

if jq -e --arg id "$FEED_ID" '.[] | select(.id == $id)' "$FEED_FILE" >/dev/null; then
  printf 'Feed already exists for id: %s\n' "$FEED_ID" >&2
  exit 1
fi

tmp_file="$(mktemp)"
jq --arg creator "$CREATOR" --arg feed_type "$FEED_TYPE" --arg id "$FEED_ID" \
  '. + [{creator: $creator, feed_type: $feed_type, id: $id}]' \
  "$FEED_FILE" > "$tmp_file"
mv "$tmp_file" "$FEED_FILE"

printf 'Added feed: %s (%s)\n' "$CREATOR" "$FEED_TYPE"
