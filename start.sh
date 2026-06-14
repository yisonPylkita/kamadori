#!/usr/bin/env bash
#
# start.sh — Launch Kamidori Alchemy Meister
# ==============================================================================
# Usage:
#   ./start.sh              # launch game (background)
#   ./start.sh --foreground # launch game (foreground, blocks terminal)
#   ./start.sh --cleanup    # kill all game/wine processes
# ==============================================================================

set -euo pipefail

CROSSOVER_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
WINE="$CROSSOVER_BIN/wine"
WINESERVER="$CROSSOVER_BIN/wineserver"
BOTTLE_NAME="Kamadori"
BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
GAME_DIR="$BOTTLE_DIR/drive_c/Games/Kamadori"

case "${1:-}" in
--cleanup | -k)
	echo "Cleaning up..."
	"$WINESERVER" -k 2>/dev/null || true
	for p in age wineserver wine winedevice wineboot explorer; do
		killall -q "$p" 2>/dev/null || true
	done
	sleep 1
	echo "Done."
	exit 0
	;;
--foreground | -f)
	FG=1
	;;
--help | -h)
	echo "Usage: $(basename "$0") [--foreground|--cleanup|--help]"
	exit 0
	;;
esac

# Verify game exists
if [[ ! -f "$GAME_DIR/age.exe" ]]; then
	echo "Error: Game not found. Run ./setup.sh --force first."
	exit 1
fi

# Launch from the game's directory (required by the engine)
cd "$GAME_DIR"

if [[ -n "${FG:-}" ]]; then
	LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8 LC_MESSAGES=ja_JP.UTF-8 \
		"$WINE" --bottle "$BOTTLE_NAME" --no-wait age.exe
else
	LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8 LC_MESSAGES=ja_JP.UTF-8 \
		"$WINE" --bottle "$BOTTLE_NAME" --no-wait age.exe >/dev/null 2>&1 &
	echo "Game launched in background. PID: $!"
	echo "Use './start.sh --cleanup' to kill it."
fi
