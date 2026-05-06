#!/usr/bin/env bash
set -euo pipefail

# Install local branding PNGs into the BHTwitter bundle before building.
#
# Usage:
#   tools/install_branding_assets.sh \
#     --app-icon /path/to/icon.png \
#     --logo /path/to/logo.png \
#     --launch-logo /path/to/launch-logo.png
#
# Notes:
# - The image files are not committed by this script.
# - Use artwork that you own or are allowed to use.
# - If --logo or --launch-logo are omitted, --app-icon is reused as a fallback.

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANDING_DIR="$ROOT_DIR/layout/Library/Application Support/BHT/BHTwitter.bundle/Branding"

APP_ICON=""
LOGO=""
LAUNCH_LOGO=""
TAB_LOGO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app-icon)
      APP_ICON="${2:-}"
      shift 2
      ;;
    --logo)
      LOGO="${2:-}"
      shift 2
      ;;
    --launch-logo)
      LAUNCH_LOGO="${2:-}"
      shift 2
      ;;
    --tab-logo)
      TAB_LOGO="${2:-}"
      shift 2
      ;;
    -h|--help)
      sed -n '1,28p' "$0"
      exit 0
      ;;
    *)
      echo "[error] Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z "$APP_ICON" ]]; then
  echo "[error] --app-icon is required" >&2
  exit 1
fi

if [[ ! -f "$APP_ICON" ]]; then
  echo "[error] App icon not found: $APP_ICON" >&2
  exit 1
fi

LOGO="${LOGO:-$APP_ICON}"
LAUNCH_LOGO="${LAUNCH_LOGO:-$LOGO}"
TAB_LOGO="${TAB_LOGO:-$LOGO}"

for file in "$LOGO" "$LAUNCH_LOGO" "$TAB_LOGO"; do
  if [[ ! -f "$file" ]]; then
    echo "[error] Branding file not found: $file" >&2
    exit 1
  fi
done

mkdir -p "$BRANDING_DIR"
cp "$APP_ICON" "$BRANDING_DIR/twitter_app_icon.png"
cp "$LOGO" "$BRANDING_DIR/twitter_logo.png"
cp "$LAUNCH_LOGO" "$BRANDING_DIR/twitter_launch_logo.png"
cp "$TAB_LOGO" "$BRANDING_DIR/twitter_tab_logo.png"

echo "[done] Installed branding assets into: $BRANDING_DIR"
ls -lah "$BRANDING_DIR"