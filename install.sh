#!/bin/bash
# One-line installer for a new Mac (no git / Homebrew needed):
#   curl -fsSL https://raw.githubusercontent.com/kaito5757/dotfiles/main/install.sh | bash
# Downloads the repository archive to a temporary directory and runs setup.sh.
set -euo pipefail

REPO="kaito5757/dotfiles"
BRANCH="main"

work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles.XXXXXX")
trap 'rm -rf "$work"' EXIT

echo "dotfiles をダウンロードしています: https://github.com/$REPO ($BRANCH)"
curl -fsSL "https://github.com/$REPO/archive/refs/heads/$BRANCH.tar.gz" | tar -xz -C "$work" --strip-components=1

# Stdin is the piped script itself, so prompts must read from the terminal.
bash "$work/setup.sh" </dev/tty
