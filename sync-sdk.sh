#!/usr/bin/env bash
# sync-sdk.sh — vendor addons/cheddaboards into this template from the addon repo at a pinned tag.
#
# Usage:
#   ./sync-sdk.sh v2.3.0              # clone the tag from GitHub and copy it in
#   ./sync-sdk.sh v2.3.0 ~/Documents/cheddaboards-godot-addon
#                                     # use a local checkout instead (checks out the tag there)
#
# The addon repo is the single source of truth. This script wipes addons/cheddaboards
# and replaces it with the tagged copy, as-is. No submodule, no subtree.

set -euo pipefail

TAG="${1:-}"
LOCAL_SRC="${2:-}"
ADDON_REPO="${ADDON_REPO:-https://github.com/cheddatech/cheddaboards-godot-addon.git}"
ADDON_PATH="addons/cheddaboards"

if [[ -z "$TAG" ]]; then
  echo "usage: $0 <tag> [local-addon-checkout]" >&2
  exit 1
fi

# Run from the template repo root, wherever the script was invoked from.
cd "$(git rev-parse --show-toplevel)"

if [[ ! -d "$ADDON_PATH" ]]; then
  echo "error: $ADDON_PATH not found — is this the template repo?" >&2
  exit 1
fi

if [[ -n "$(git status --porcelain -- "$ADDON_PATH")" ]]; then
  echo "error: $ADDON_PATH has uncommitted changes. Commit or stash them first." >&2
  exit 1
fi

TMP=""
cleanup() { [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT

if [[ -n "$LOCAL_SRC" ]]; then
  SRC="$LOCAL_SRC"
  echo "==> using local checkout $SRC at $TAG"
  git -C "$SRC" fetch --tags --quiet
  git -C "$SRC" checkout --quiet "$TAG"
else
  TMP="$(mktemp -d)"
  echo "==> cloning $ADDON_REPO at $TAG"
  git clone --quiet --depth 1 --branch "$TAG" "$ADDON_REPO" "$TMP/addon"
  SRC="$TMP/addon"
fi

if [[ ! -d "$SRC/$ADDON_PATH" ]]; then
  echo "error: $SRC/$ADDON_PATH not found in the addon repo at $TAG" >&2
  exit 1
fi

echo "==> replacing $ADDON_PATH"
rm -rf "$ADDON_PATH"
mkdir -p "$(dirname "$ADDON_PATH")"
cp -R "$SRC/$ADDON_PATH" "$ADDON_PATH"

# Record what's vendored so the template always says which SDK it carries.
SHA="$(git -C "$SRC" rev-parse --short HEAD)"
printf 'cheddaboards-godot-addon %s (%s)\nsynced %s\n' \
  "$TAG" "$SHA" "$(date -u +%Y-%m-%dT%H:%MZ)" > "$ADDON_PATH/VENDORED"

# Sanity check the version the plugin itself reports.
CFG_VERSION="$(sed -n 's/^version="\(.*\)"/\1/p' "$ADDON_PATH/plugin.cfg" 2>/dev/null || true)"
if [[ -n "$CFG_VERSION" && "v$CFG_VERSION" != "$TAG" ]]; then
  echo "warning: plugin.cfg says $CFG_VERSION but you asked for $TAG" >&2
fi

echo "==> done: $ADDON_PATH is now $TAG ($SHA)"
echo
git status --short -- "$ADDON_PATH"
echo
echo "Next: open the template in Godot, run it, then:"
echo "  git add $ADDON_PATH && git commit -m \"sdk: vendor cheddaboards-godot-addon $TAG\""
