#!/usr/bin/env bash
# Copies this Mac's current Loop settings into macos/loop.plist (only the keys already listed there).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
want="$DOTFILES_DIR/macos/loop.plist"
current=$(mktemp "${TMPDIR:-/tmp}/loop.XXXXXX")
trap 'rm -f "$current"' EXIT

defaults export com.MrKai77.Loop "$current"
for key in $(grep -E $'^\t<key>' "$want" | sed 's/.*<key>\(.*\)<\/key>.*/\1/'); do
  plutil -replace "$key" -xml "$(plutil -extract "$key" xml1 -o - "$current")" "$want"
done
plutil -convert xml1 "$want"
echo "macos/loop.plist を更新しました。git diff で確認してからコミットしてください。"
