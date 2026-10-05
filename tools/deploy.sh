#!/bin/sh
# For development: syntax-check the Lua, then copy Cursor Finder into a WoW client's AddOns folder.
# The AddOns folder comes from WOW_ADDONS, or from tools/deploy.local (kept out of git), for example:
#   WOW_ADDONS="/Applications/World of Warcraft/_retail_/Interface/AddOns"
# rsync --inplace and chflags nohidden: an SMB share marks rsync's temporary files hidden, and the client then
# fails to load them.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$(dirname "$HERE")"
if [ -z "$WOW_ADDONS" ] && [ -f "$HERE/deploy.local" ]; then
	. "$HERE/deploy.local"
fi
if [ -z "$WOW_ADDONS" ]; then
	echo "Set WOW_ADDONS to the client's Interface/AddOns folder, or put WOW_ADDONS=... in tools/deploy.local"
	exit 1
fi
DEST="$WOW_ADDONS/CursorFinder"
if command -v luajit > /dev/null; then
	find "$SRC" -name '*.lua' -not -path '*/tools/*' | while read -r f; do
		luajit -bl "$f" > /dev/null || { echo "syntax error: $f"; exit 1; }
	done
else
	echo "luajit not found: syntax check skipped"
fi
mkdir -p "$DEST"
rsync -r --inplace --delete --exclude tools --exclude .git --exclude .gitignore --exclude .DS_Store \
	--exclude README.md --exclude screenshots "$SRC/" "$DEST/"
if command -v chflags > /dev/null; then chflags -R nohidden "$DEST"; fi
echo "deployed to $DEST ($(find "$DEST" -type f | wc -l | tr -d ' ') files)"
