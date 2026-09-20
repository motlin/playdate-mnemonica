#!/bin/bash
# build.sh
# Builds builds/MnemonicaInputDebug.pdx: the real game with an overlay showing what the
# hardware reports (button press counts, crank travel, menu row). For chasing input bugs that
# only happen on a device. It has its own name and bundleID so it never replaces the real game.
set -euo pipefail
ROOT="$(command cd "$(dirname "$0")/../.." && pwd)"
SRC="$ROOT/builds/input-debug-source"
PDX="$ROOT/builds/MnemonicaInputDebug.pdx"

mkdir -p "$SRC"
rsync --archive --delete "$ROOT/source/" "$SRC/"
sed -i '' "s/^bundleID=.*/bundleID=com.motlin.mnemonica.inputdebug/" "$SRC/pdxinfo"
sed -i '' "s/^name=.*/name=Mnemonica INPUT DEBUG/" "$SRC/pdxinfo"
{
  echo ""
  echo "local pd <const> = playdate"
  echo "local gfx <const> = playdate.graphics"
  cat "$ROOT/tools/input-debug/overlay.lua"
} >> "$SRC/main.lua"
pdc -q "$SRC" "$PDX"
echo "✅ built $PDX"
