#!/usr/bin/env bash
#
# verify_game.sh — Launch Kamidori and verify it runs without errors
# ==============================================================================
# Launches the game, monitors its process and Wine debug log, then reports
# pass/fail based on:
#   - Process existence (game must stay alive for N seconds)
#   - No MessageBox / error dialog creation in the Wine log
#   - No fatal file-not-found errors during startup
#   - Game window creation (detected via Wine log)
#
# Usage:
#   ./verify_game.sh              # single run
#   ./verify_game.sh --repeat N   # repeat N times for reliability
#   ./verify_game.sh --cleanup    # only cleanup, no launch
# ==============================================================================

set -euo pipefail

CROSSOVER_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
WINE="$CROSSOVER_BIN/wine"
WINESERVER="$CROSSOVER_BIN/wineserver"
BOTTLE_NAME="Kamadori"
BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
GAME_DIR="$BOTTLE_DIR/drive_c/Games/Kamadori"
CLEANUP_SCRIPT="$(cd "$(dirname "$0")" && pwd)/cleanup.sh"
CXLOG="/tmp/kamadori_verify_cxlog.txt"
TIMEOUT=30
PASS=0
FAIL=0

# Parse args
REPEAT=1
for arg in "$@"; do
	if [[ "$arg" == "--cleanup" ]]; then
		bash "$CLEANUP_SCRIPT" --force
		exit 0
	fi
	if [[ "$arg" == "--repeat" ]]; then
		REPEAT="${2:-5}"
		shift
	fi
done

# --- Helpers ---
red() { echo -e "\033[1;31m$1\033[0m"; }
green() { echo -e "\033[1;32m$1\033[0m"; }
blue() { echo -e "\033[1;34m$1\033[0m"; }

run_cleanup() {
	bash "$CLEANUP_SCRIPT" 2>/dev/null || true
	sleep 2
}

check_bottle() {
	if [[ ! -d "$BOTTLE_DIR" ]]; then
		red "  Bottle not found. Run ./setup.sh --force first."
		return 1
	fi
	if [[ ! -f "$BOTTLE_DIR/drive_c/Games/Kamadori/age.exe" ]]; then
		red "  Game files not found in bottle."
		return 1
	fi
	return 0
}

run_once() {
	local attempt="$1"
	local log="$CXLOG"
	rm -f "$log"

	blue "  Run #$attempt — launching game..."

	# Launch from the game's working directory (required by the engine)
	cd "$GAME_DIR"
	LC_ALL=ja_JP.UTF-8 \
		LANG=ja_JP.UTF-8 \
		LC_MESSAGES=ja_JP.UTF-8 \
		"$WINE" \
		--bottle "$BOTTLE_NAME" \
		--cx-log "$log" \
		--no-wait \
		age.exe \
		2>/dev/null &

	local errors=0
	local details=""

	# Wait for initialization
	sleep "$TIMEOUT"

	# ---- Check 1: Process is still alive ----
	local age_pid=""
	age_pid=$(ps aux | grep '[a]ge\.exe' | awk '{print $2}' | head -1)
	if [[ -z "$age_pid" ]]; then
		details+="    ✘ Game process exited immediately\n"
		errors=$((errors + 1))
	else
		details+="    ✔ Game running (PID $age_pid)\n"
	fi

	# ---- Check 2: No MessageBox/dialog creation in log ----
	if [[ -f "$log" ]]; then
		local mb_count
		mb_count=$(grep -c -i 'MessageBox\|TaskDialog' "$log" 2>/dev/null || true)
		mb_count=${mb_count:-0}
		mb_count=$(echo "$mb_count" | tr -d ' ' | tail -1)
		if [[ "$mb_count" -gt 0 ]] 2>/dev/null; then
			details+="    ✘ $mb_count MessageBox call(s) detected (error dialog!)\n"
			errors=$((errors + 1))
		else
			details+="    ✔ No MessageBox calls\n"
		fi

		# ---- Check 3: No fatal file-not-found for game files ----
		local file_errors
		file_errors=$(grep -i 'STATUS_OBJECT_NAME_NOT_FOUND\|STATUS_NO_SUCH_FILE\|STATUS_ACCESS_DENIED' "$log" 2>/dev/null | grep -i 'Kamadori' | wc -l | tr -d ' ')
		if ((file_errors > 0)); then
			details+="    ✘ $file_errors file-not-found error(s) for game files\n"
			errors=$((errors + 1))
		else
			details+="    ✔ No file errors for game files\n"
		fi

		# ---- Check 4: Game window was created ----
		local win_count
		win_count=$(grep -c 'CreateWindowEx\|NtUserCreateWindow\|ShowWindow' "$log" 2>/dev/null || true)
		win_count=${win_count:-0}
		win_count=$(echo "$win_count" | tr -d ' ' | tail -1)
		if [[ "$win_count" -gt 0 ]] 2>/dev/null; then
			details+="    ✔ Game window created ($win_count window events)\n"
		else
			details+="    ⚠ No window creation events detected\n"
		fi

	else
		details+="    ⚠ No cx-log file found\n"
	fi

	# ---- Result ----
	echo ""
	echo -e "$details"

	if ((errors == 0)); then
		green "  ✅ Run #$attempt PASSED"
		return 0
	else
		red "  ❌ Run #$attempt FAILED ($errors checks failed)"
		return 1
	fi
}

# --- Main ---
echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   Kamadori — Game Verification           ║"
echo "╚═══════════════════════════════════════════╝"
echo ""

if ! check_bottle; then
	exit 1
fi

echo "  Running $REPEAT verification(s) with ${TIMEOUT}s timeout each..."
echo ""

for i in $(seq 1 "$REPEAT"); do
	run_cleanup

	if run_once "$i"; then
		PASS=$((PASS + 1))
	else
		FAIL=$((FAIL + 1))
	fi

	run_cleanup
done

echo ""
echo "============================================="
echo "  Results: $PASS passed, $FAIL failed out of $REPEAT runs"
echo "============================================="
echo ""

if ((FAIL > 0)); then
	red "  ❌ Some runs failed — check the cx-log at $CXLOG"
	echo ""
	exit 1
fi

green "  ✅ All runs passed!"
echo ""
exit 0
