#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FEED_FILE="${FEED_FILE:-$SCRIPT_DIR/content-feed.json}"
VAULT_DIR="${VAULT_DIR:-$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal-vault}"
GENERATED_DIR="${GENERATED_DIR:-$VAULT_DIR/Generated}"
STATE_FILE="${STATE_FILE:-$SCRIPT_DIR/.content-review-state.txt}"
FABRIC_PATTERN="${FABRIC_PATTERN:-label_and_rate}"
MAX_ITEMS_PER_FEED="${MAX_ITEMS_PER_FEED:-5}"
RUN_DATE="${RUN_DATE:-$(date +%F)}"
OUTPUT_DIR="$GENERATED_DIR/$RUN_DATE"
RESET_DATE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --reset-today)
      RESET_DATE="$RUN_DATE"
      shift
      ;;
    --reset-date)
      RESET_DATE="${2:-}"
      if [[ -z "$RESET_DATE" ]]; then
        printf 'Missing value for --reset-date\n' >&2
        exit 1
      fi
      shift 2
      ;;
    *)
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
done

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

for cmd in jq curl fabric python3 grep xmllint cut; do
  require_cmd "$cmd"
done

if [[ ! -f "$FEED_FILE" ]]; then
  printf 'Feed file not found: %s\n' "$FEED_FILE" >&2
  exit 1
fi

touch "$STATE_FILE"

sanitize_filename() {
  python3 - "$1" <<'PY'
import re
import sys
import unicodedata

value = sys.argv[1]
value = unicodedata.normalize('NFKD', value).encode('ascii', 'ignore').decode('ascii')
value = re.sub(r'[\\/:*?"<>|]+', '-', value)
value = re.sub(r'\s+', ' ', value).strip(' .')
print(value[:180] or 'untitled')
PY
}

already_processed() {
  local key="$1"
  grep -Fq "|$key" "$STATE_FILE"
}

mark_processed() {
  local key="$1"
  printf '%s|%s\n' "$RUN_DATE" "$key" >> "$STATE_FILE"
}

reset_date() {
  local target_date="$1"
  local target_dir="$GENERATED_DIR/$target_date"
  local tmp_state

  rm -rf "$target_dir"

  tmp_state="$(mktemp)"
  if [[ -f "$STATE_FILE" ]]; then
    grep -Ev "^${target_date//./\\.}\|" "$STATE_FILE" > "$tmp_state" || true
    mv "$tmp_state" "$STATE_FILE"
  else
    rm -f "$tmp_state"
  fi
}

if [[ -n "$RESET_DATE" ]]; then
  reset_date "$RESET_DATE"
fi

mkdir -p "$OUTPUT_DIR"

parse_feed_items() {
  local feed_type="$1"
  local limit="$2"

  local tmp_xml count i title url item_id published
  tmp_xml="$(mktemp)"
  cat > "$tmp_xml"

  if [[ ! -s "$tmp_xml" ]]; then
    rm -f "$tmp_xml"
    printf '[]\n'
    return 0
  fi

  if [[ "$feed_type" == "yt" ]]; then
    count="$(xmllint --xpath 'count(//*[local-name()="entry"])' "$tmp_xml" 2>/dev/null | cut -d. -f1 || true)"
  else
    count="$(xmllint --xpath 'count(//*[local-name()="item"])' "$tmp_xml" 2>/dev/null | cut -d. -f1 || true)"
  fi

  if ! [[ "$count" =~ ^[0-9]+$ ]]; then
    rm -f "$tmp_xml"
    return 1
  fi

  for ((i=1; i<=count && i<=limit; i++)); do
    if [[ "$feed_type" == "yt" ]]; then
      title="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='title'][1])" "$tmp_xml" 2>/dev/null || true)"
      url="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='link'][@rel='alternate'][1]/@href)" "$tmp_xml" 2>/dev/null || true)"
      item_id="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='videoId'][1])" "$tmp_xml" 2>/dev/null || true)"
      published="$(xmllint --xpath "string((//*[local-name()='entry'])[$i]/*[local-name()='published'][1])" "$tmp_xml" 2>/dev/null || true)"
    else
      title="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='title'][1])" "$tmp_xml" 2>/dev/null || true)"
      url="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='link'][1])" "$tmp_xml" 2>/dev/null || true)"
      item_id="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='guid'][1])" "$tmp_xml" 2>/dev/null || true)"
      published="$(xmllint --xpath "string((//*[local-name()='item'])[$i]/*[local-name()='pubDate'][1])" "$tmp_xml" 2>/dev/null || true)"
    fi

    jq -cn \
      --arg item_id "${item_id:-${url:-$title}}" \
      --arg title "$title" \
      --arg url "$url" \
      --arg published "$published" \
      '{item_id: $item_id, title: $title, url: $url, published: $published}'
  done | jq -s '.'

  rm -f "$tmp_xml"
}

extract_json_object() {
  python3 -c '
import sys

text = sys.stdin.read()
start = text.find("{")
end = text.rfind("}")

if start == -1 or end == -1 or end < start:
    raise SystemExit(1)

print(text[start:end+1])
'
}

score_to_nine() {
  local quality_score="$1"
  local rating=$(( 9 - (quality_score / 10) ))
  if (( rating < 0 )); then rating=0; fi
  if (( rating > 9 )); then rating=9; fi
  printf '%s' "$rating"
}

run_fabric_review() {
  local feed_type="$1"
  local url="$2"

  if [[ "$feed_type" == "yt" ]]; then
    fabric -p "$FABRIC_PATTERN" --suppress-think -y "$url"
  else
    fabric -p "$FABRIC_PATTERN" --suppress-think -u "$url"
  fi
}

write_note() {
  local filepath="$1"
  local creator="$2"
  local title="$3"
  local url="$4"
  local published="$5"
  local feed_type="$6"
  local rating_nine="$7"
  local quality_score="$8"
  local review_json="$9"

  local one_sentence_summary labels rating_label rating_explanation score_explanation content_type tags
  one_sentence_summary="$(jq -r '.["one-sentence-summary"] // "No summary returned."' <<<"$review_json")"
  labels="$(jq -r '.labels // ""' <<<"$review_json")"
  rating_label="$(jq -r '.["rating:"] // "Unknown"' <<<"$review_json")"
  rating_explanation="$(jq -r '.["rating-explanation:"] // ""' <<<"$review_json")"
  score_explanation="$(jq -r '.["quality-score-explanation"] // ""' <<<"$review_json")"

  case "$feed_type" in
    yt)
      content_type="YouTube"
      ;;
    rss|blog)
      content_type="Blog"
      ;;
    *)
      content_type="$feed_type"
      ;;
  esac

  tags="$(jq -rn --arg labels "$labels" '
    ($labels | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)))
    | map(ascii_downcase)
    | map(gsub("[^a-z0-9]+"; "_"))
    | map(gsub("^_+|_+$"; ""))
    | map(select(length > 0))
    | map("#" + .)
    | join(" ")
  ')"

  {
    printf '# %s - %s\n\n' "$creator" "$title"
    printf -- '- Creator: %s\n' "$creator"
    printf -- '- Content Type: %s\n' "$content_type"
    printf -- '- Published: %s\n' "${published:-unknown}"
    printf -- '- Impressiveness: %s/9\n' "$rating_nine"
    printf -- '- Fabric Quality Score: %s/100\n' "$quality_score"
    printf -- '- Source: %s\n\n' "$url"
    if [[ -n "$tags" ]]; then
      printf '%s\n\n' "$tags"
    fi
    printf '## Summary\n\n%s\n\n' "$one_sentence_summary"
    printf '## Recommendation\n\n'
    printf '**%s**\n\n' "$rating_label"
    printf '%s\n\n' "$rating_explanation"
    printf '## Labels\n\n%s\n\n' "${labels:-none}"
    printf '## Quality Notes\n\n%s\n\n' "$score_explanation"
    printf '## Fabric Output\n\n```json\n%s\n```\n' "$review_json"
  } > "$filepath"
}

process_item() {
  local creator="$1"
  local feed_type="$2"
  local item_id="$3"
  local title="$4"
  local url="$5"
  local published="$6"

  local key="${creator}|${item_id}"
  if already_processed "$key"; then
    return 0
  fi

  if [[ -z "$url" || -z "$title" ]]; then
    printf 'Skipping incomplete item for %s\n' "$creator" >&2
    return 0
  fi

  local fabric_output review_json quality_score rating_nine filename filepath
  if ! fabric_output="$(run_fabric_review "$feed_type" "$url")"; then
    printf 'Fabric review failed for %s\n' "$url" >&2
    return 0
  fi

  if ! review_json="$(printf '%s' "$fabric_output" | extract_json_object)"; then
    printf 'Could not extract JSON from Fabric output for %s\n' "$url" >&2
    return 0
  fi

  if ! jq -e . >/dev/null 2>&1 <<<"$review_json"; then
    printf 'Fabric JSON was invalid for %s\n' "$url" >&2
    return 0
  fi

  quality_score="$(jq -r '.["quality-score"] // 50' <<<"$review_json")"
  if ! [[ "$quality_score" =~ ^[0-9]+$ ]]; then
    quality_score=50
  fi
  rating_nine="$(score_to_nine "$quality_score")"

  filename="$(sanitize_filename "$rating_nine - $creator - $title")"
  filepath="$OUTPUT_DIR/$filename.md"

  write_note "$filepath" "$creator" "$title" "$url" "$published" "$feed_type" "$rating_nine" "$quality_score" "$review_json"
  mark_processed "$key"
  printf 'Wrote %s\n' "$filepath"
}

process_feed() {
  local creator="$1"
  local feed_type="$2"
  local feed_id="$3"
  local feed_url="$feed_id"

  case "$feed_type" in
    yt)
      feed_url="https://www.youtube.com/feeds/videos.xml?channel_id=$feed_id"
      ;;
    rss|blog)
      ;;
    *)
      printf 'Skipping unsupported feed type: %s\n' "$feed_type" >&2
      return 0
      ;;
  esac

  local feed_xml items_json
  if ! feed_xml="$(curl -fsSL "$feed_url")"; then
    printf 'Failed to fetch feed %s\n' "$feed_url" >&2
    return 0
  fi

  if ! items_json="$(printf '%s' "$feed_xml" | parse_feed_items "$feed_type" "$MAX_ITEMS_PER_FEED")"; then
    printf 'Failed to parse feed %s\n' "$feed_url" >&2
    return 0
  fi

  while IFS= read -r item; do
    [[ -z "$item" ]] && continue
    process_item \
      "$creator" \
      "$feed_type" \
      "$(jq -r '.item_id // ""' <<<"$item")" \
      "$(jq -r '.title // ""' <<<"$item")" \
      "$(jq -r '.url // ""' <<<"$item")" \
      "$(jq -r '.published // ""' <<<"$item")"
  done < <(jq -c '.[]' <<<"$items_json")
}

while IFS= read -r feed; do
  [[ -z "$feed" ]] && continue
  process_feed \
    "$(jq -r '.creator' <<<"$feed")" \
    "$(jq -r '.feed_type' <<<"$feed")" \
    "$(jq -r '.id' <<<"$feed")"
done < <(jq -c '.[]' "$FEED_FILE")
