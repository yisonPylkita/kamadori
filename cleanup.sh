#!/usr/bin/env bash
#
# cleanup.sh — Reliably kill all Wine/CrossOver processes
# ==============================================================================
# Kills age.exe, wineserver, winedevice.exe, wineboot.exe, and any related
# processes. Handles stubborn processes by escalating to SIGKILL.
#
# Usage:
#   ./cleanup.sh              # normal cleanup (SIGTERM + escalate)
#   ./cleanup.sh --force      # immediate SIGKILL
#   ./cleanup.sh --status     # only report, don't kill
# ==============================================================================

set -euo pipefail

CROSSOVER_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
WINESERVER="$CROSSOVER_BIN/wineserver"
BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/Kamadori"

FORCE=0
STATUS=0
for arg in "$@"; do
	case "$arg" in
	--force) FORCE=1 ;;
	--status) STATUS=1 ;;
	esac
done

echo ""
echo "╔═══════════════════════════════════════════╗"
echo "║   Kamadori — Process Cleanup             ║"
echo "╚═══════════════════════════════════════════╝"

if [[ -d "$BOTTLE_DIR" ]]; then
	echo "  Bottle: $BOTTLE_DIR"
fi
echo ""

# --- Collect all Wine/CrossOver PIDs ---
PIDS=()
PATTERNS=("age.exe" "wineserver" "winewrapper" "wineloader" "winedevice.exe" "wineboot.exe" "explorer.exe" "wine.exe")

for pattern in "${PATTERNS[@]}"; do
	while IFS= read -r line; do
		[[ -z "$line" ]] && continue
		pid=$(echo "$line" | awk '{print $2}')
		name=$(echo "$pattern" | sed 's/\.exe//' | sed 's/\\\\//')
		cmd=$(echo "$line" | awk '{$1=$2=$3=""; print $0}' | xargs | head -c 80)
		PIDS+=("$pid:$name:$cmd")
	done < <(ps aux 2>/dev/null | grep "["${pattern:0:1}"]${pattern:1}" || true)
done

if [[ ${#PIDS[@]} -eq 0 ]]; then
	echo "  No Wine/CrossOver processes found."
	echo ""
	exit 0
fi

# --- Status mode ---
if ((STATUS)); then
	echo "  Running processes:"
	for entry in "${PIDS[@]}"; do
		IFS=':' read -r pid name cmd <<<"$entry"
		echo "    $name (PID $pid)"
	done
	echo ""
	exit 0
fi

# --- Kill phase ---
SIGNAL="-15"
((FORCE)) && SIGNAL="-9"

if ((FORCE)); then sig="KILL"; else sig="TERM"; fi
echo "  Sending SIG$sig..."

# First: kill through wineserver (cleanest shutdown)
[[ -x "$WINESERVER" ]] && "$WINESERVER" -k 2>/dev/null || true

for entry in "${PIDS[@]}"; do
	IFS=':' read -r pid name cmd <<<"$entry"
	if kill "$SIGNAL" "$pid" 2>/dev/null; then
		echo "    Killed $name (PID $pid)"
	fi
done

# Remove bottle state files
[[ -d "$BOTTLE_DIR" ]] && rm -f "$BOTTLE_DIR/.update-timestamp" 2>/dev/null || true

# Wait & escalate
sleep 2
remaining=0
for entry in "${PIDS[@]}"; do
	IFS=':' read -r pid name cmd <<<"$entry"
	if kill -0 "$pid" 2>/dev/null; then
		if ((!FORCE)); then
			echo "    $name (PID $pid) still alive — sending SIGKILL"
			kill -9 "$pid" 2>/dev/null || true
			remaining=$((remaining + 1))
		else
			echo "    WARNING: $name (PID $pid) still alive"
			remaining=$((remaining + 1))
		fi
	fi
done

echo ""
if ((remaining > 0)); then
	echo "  WARNING: $remaining process(es) could not be killed."
else
	echo "  All processes cleaned up."
fi
echo ""
