#!/usr/bin/env bash

set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="${APP_DIR:-$HOME/Library/Application Support/content-review}"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
LAUNCH_AGENT_PATH="$LAUNCH_AGENTS_DIR/com.gatherconsumables.content-review.plist"
LABEL="com.gatherconsumables.content-review"
LEGACY_LAUNCH_AGENT_PATH="$LAUNCH_AGENTS_DIR/com.chris.content-review.plist"
DEFAULT_VAULT_DIR="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/personal-vault"
VAULT_DIR_INPUT="${VAULT_DIR:-}"

print_help() {
  cat <<EOF
Usage:
  ./install.sh

What it installs:
  - $APP_DIR/content-review.sh
  - $APP_DIR/add-feed.sh
  - $APP_DIR/content-feed.json
  - $APP_DIR/content-review.conf
  - $APP_DIR/.content-review-state.txt
  - $APP_DIR/content-review.log
  - $LAUNCH_AGENT_PATH

The LaunchAgent runs every hour and starts once at load time.
EOF
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Missing required command: %s\n' "$1" >&2
    exit 1
  }
}

copy_file() {
  local source_path="$1"
  local target_path="$2"
  cp "$source_path" "$target_path"
}

prompt_for_vault_dir() {
  if [[ -n "$VAULT_DIR_INPUT" ]]; then
    return 0
  fi

  if [[ -t 0 ]]; then
    printf 'Obsidian vault absolute path [%s]: ' "$DEFAULT_VAULT_DIR"
    read -r VAULT_DIR_INPUT
  fi

  VAULT_DIR_INPUT="${VAULT_DIR_INPUT:-$DEFAULT_VAULT_DIR}"
}

validate_vault_dir() {
  if [[ "$VAULT_DIR_INPUT" != /* ]]; then
    printf 'Vault path must be absolute: %s\n' "$VAULT_DIR_INPUT" >&2
    exit 1
  fi

  if [[ ! -d "$VAULT_DIR_INPUT" ]]; then
    printf 'Vault directory does not exist: %s\n' "$VAULT_DIR_INPUT" >&2
    exit 1
  fi
}

for cmd in cp chmod mkdir launchctl; do
  require_cmd "$cmd"
done

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  print_help
  exit 0
fi

prompt_for_vault_dir
validate_vault_dir

mkdir -p "$APP_DIR"
mkdir -p "$LAUNCH_AGENTS_DIR"

copy_file "$SCRIPT_DIR/content-review.sh" "$APP_DIR/content-review.sh"
copy_file "$SCRIPT_DIR/add-feed.sh" "$APP_DIR/add-feed.sh"
copy_file "$SCRIPT_DIR/content-feed.json" "$APP_DIR/content-feed.json"

cat > "$APP_DIR/content-review.conf" <<EOF
VAULT_DIR="$VAULT_DIR_INPUT"
EOF

chmod +x "$APP_DIR/content-review.sh"
chmod +x "$APP_DIR/add-feed.sh"
touch "$APP_DIR/.content-review-state.txt"
touch "$APP_DIR/content-review.log"

cat > "$LAUNCH_AGENT_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
      <string>$APP_DIR/content-review.sh</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
      <key>PATH</key>
      <string>/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:$HOME/.local/bin</string>
      <key>HOME</key>
      <string>$HOME</string>
    </dict>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$APP_DIR/content-review.log</string>
    <key>StandardErrorPath</key>
    <string>$APP_DIR/content-review.log</string>
    <key>WorkingDirectory</key>
    <string>$APP_DIR</string>
  </dict>
</plist>
EOF

launchctl unload "$LAUNCH_AGENT_PATH" >/dev/null 2>&1 || true
launchctl unload "$LEGACY_LAUNCH_AGENT_PATH" >/dev/null 2>&1 || true
launchctl load "$LAUNCH_AGENT_PATH"
launchctl start "$LABEL" || true

if [[ -f "$LEGACY_LAUNCH_AGENT_PATH" ]]; then
  rm -f "$LEGACY_LAUNCH_AGENT_PATH"
fi

printf 'Installed to %s\n' "$APP_DIR"
printf 'Vault path: %s\n' "$VAULT_DIR_INPUT"
printf 'LaunchAgent loaded: %s\n' "$LAUNCH_AGENT_PATH"
printf 'Run now: %s/content-review.sh\n' "$APP_DIR"
printf 'Add feeds: %s/add-feed.sh\n' "$APP_DIR"
