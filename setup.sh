#!/usr/bin/env bash
#
# setup.sh — One-command setup for Kamidori Alchemy Meister on macOS Apple Silicon
# ==============================================================================
# Creates a CrossOver bottle, configures Japanese locale & game settings,
# copies game files, and verifies everything.
#
# Usage:
#   chmod +x setup.sh && ./setup.sh
#
# Requirements:
#   - macOS on Apple Silicon (M1/M2/M3/M4)
#   - CrossOver 26+ installed in /Applications/CrossOver.app
#   - Game files extracted in this repository's Kamadori/ directory
#   - ~10 GB free disk space
#
# What it does:
#   1. Checks prerequisites
#   2. Creates a "Kamadori" CrossOver bottle (Windows 7 64-bit)
#   3. Copies game files into the bottle's drive_c
#   4. Imports Japanese locale registry settings (SHIFT-JIS support)
#   5. Patches system.reg for Japanese codepages (ACP/OEMCP = 932)
#   6. Imports game-specific settings (virtual desktop, D3D overrides)
#   7. Verifies the final setup
# ==============================================================================

set -euo pipefail

# --- Configuration -----------------------------------------------------------
BOTTLE_NAME="Kamadori"
BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
GAME_DIR="$(cd "$(dirname "$0")" && pwd)/Kamadori"
CROSSOVER_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
WINE="$CROSSOVER_BIN/wine"
CXBOTTLE="$CROSSOVER_BIN/cxbottle"
REGEDIT="$CROSSOVER_BIN/regedit"
WINESERVER="$CROSSOVER_BIN/wineserver"
DEST_DIR="drive_c/Games/Kamadori"

# --- Helpers -----------------------------------------------------------------
info() { echo -e "\033[1;34m・ $1\033[0m"; }
ok() { echo -e "\033[1;32m✔ $1\033[0m"; }
warn() { echo -e "\033[1;33m⚠ $1\033[0m"; }
err() { echo -e "\033[1;31m✘ $1\033[0m"; }
die() {
	err "$1"
	exit 1
}

# --- Step 0: Prerequisites ---------------------------------------------------
check_prereqs() {
	echo ""
	info "Checking prerequisites..."

	# macOS / Apple Silicon
	local arch
	arch=$(uname -m)
	if [[ "$arch" != "arm64" ]]; then
		die "This script is intended for Apple Silicon (M1/M2/M3/M4). Detected: $arch"
	fi
	ok "Apple Silicon detected ($arch)"

	# CrossOver
	if [[ ! -d "/Applications/CrossOver.app" ]]; then
		die "CrossOver.app not found in /Applications. Please install CrossOver 26+ first."
	fi
	if [[ ! -x "$CXBOTTLE" ]]; then
		die "cxbottle CLI not found inside CrossOver. Is CrossOver 26+ installed?"
	fi
	ok "CrossOver found at /Applications/CrossOver.app"

	# Game files
	if [[ ! -d "$GAME_DIR" ]]; then
		die "Game directory not found at $GAME_DIR. Ensure Kamadori/ exists alongside this script."
	fi
	if [[ ! -f "$GAME_DIR/age.exe" ]] || [[ ! -f "$GAME_DIR/agerc.dll" ]]; then
		die "Required files age.exe and/or agerc.dll missing in $GAME_DIR"
	fi
	ok "Game files found in $GAME_DIR"

	# Disk space (rough check: ~3 GB free)
	local available_kb
	available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
	local available_gb=$((available_kb / 1024 / 1024))
	if ((available_gb < 5)); then
		warn "Only ${available_gb} GB free on $HOME — at least 5 GB is recommended."
	else
		ok "Disk space: ${available_gb} GB free"
	fi

	# Bottle not already existing
	if [[ -d "$BOTTLE_DIR" ]]; then
		warn "Bottle '$BOTTLE_NAME' already exists at:"
		echo "       $BOTTLE_DIR"
		echo "       Delete it first or rename it, then re-run."
		echo "       To delete:  rm -rf \"$BOTTLE_DIR\""
		die "Aborting to avoid overwriting an existing bottle."
	fi

	echo ""
}

# --- Step 1: Create Bottle ---------------------------------------------------
create_bottle() {
	info "Creating CrossOver bottle '$BOTTLE_NAME' (Windows 7 64-bit)..."
	"$CXBOTTLE" \
		--bottle "$BOTTLE_NAME" \
		--create \
		--template win7_64 \
		--description "Kamidori Alchemy Meister"
	ok "Bottle created at $BOTTLE_DIR"
	echo ""
}

# --- Step 2: Copy Game Files -------------------------------------------------
copy_game_files() {
	info "Copying game files to bottle..."
	local dest="$BOTTLE_DIR/$DEST_DIR"
	mkdir -p "$dest"
	# Use rsync to copy everything excluding Backup/ and patch/ if you want a clean install.
	# Include all files: game data, patch-overridden EXE/DLL, etc.
	echo "       Copying game files (this may take a minute)..."
	rsync -a --progress "$GAME_DIR/" "$dest/" \
		--exclude "Backup/" \
		--exclude "patch/"
	ok "Game files copied to C:\\Games\\Kamadori"
	echo ""
}

# --- Step 3: Import Japanese Locale ------------------------------------------
import_jp_locale() {
	info "Importing Japanese locale registry via regedit..."
	local reg_src
	reg_src="$(cd "$(dirname "$0")" && pwd)/jp_locale.reg"
	if [[ ! -f "$reg_src" ]]; then
		die "jp_locale.reg not found alongside this script."
	fi
	cp "$reg_src" "$BOTTLE_DIR/drive_c/"
	"$REGEDIT" --bottle "$BOTTLE_NAME" "C:\\jp_locale.reg" 2>/dev/null || true

	# Kill wineserver
	"$CROSSOVER_BIN/wineserver" -k 2>/dev/null || true

	ok "Japanese locale imported"
	echo ""
}
# --- Step 4: Patch system.reg for Codepages ----------------------------------
patch_system_reg() {
	info "Patching system.reg for Japanese codepages..."
	local sysreg="$BOTTLE_DIR/system.reg"
	local script_dir
	script_dir="$(cd "$(dirname "$0")" && pwd)"

	if [[ ! -f "$sysreg" ]]; then
		die "system.reg not found in bottle — something went wrong during creation."
	fi

	# wineserver is already dead from previous step; patch directly
	python3 "$script_dir/patch_codepages.py" "$sysreg" 2>&1

	ok "system.reg patched with Japanese codepages"
	echo ""
}

# --- Step 5: Import Game Config (Virtual Desktop, D3D) -----------------------
import_game_config() {
	info "Importing game-specific config (Virtual Desktop, D3D overrides)..."
	local reg_src
	reg_src="$(cd "$(dirname "$0")" && pwd)/game_config.reg"
	if [[ ! -f "$reg_src" ]]; then
		die "game_config.reg not found alongside this script."
	fi

	# Use regedit to import game config
	cp "$reg_src" "$BOTTLE_DIR/drive_c/"
	"$REGEDIT" --bottle "$BOTTLE_NAME" "C:\\game_config.reg" 2>/dev/null

	# Kill wineserver
	"$CROSSOVER_BIN/wineserver" -k 2>/dev/null || true

	ok "Game config imported"
	echo ""
}

# --- Step 6: Verification ----------------------------------------------------
verify() {
	echo ""
	info "Verifying bottle configuration..."

	# Kill wineserver so we can safely finalize registry files
	"$CROSSOVER_BIN/wineserver" -k 2>/dev/null || true
	sleep 1

	# Now that wineserver is dead, apply all remaining patches directly
	local script_dir
	script_dir="$(cd "$(dirname "$0")" && pwd)"
	python3 "$script_dir/patch_user_reg_jp.py" "$BOTTLE_DIR/user.reg"
	python3 "$script_dir/patch_codepages.py" "$BOTTLE_DIR/system.reg" 2>&1

	# Remove wineserver state so old data can't be resurrected later
	rm -f "$BOTTLE_DIR/.update-timestamp" 2>/dev/null || true
	rm -f "$BOTTLE_DIR/dosdevices/*:wineserver" 2>/dev/null || true
	local errors=0

	# Check template
	if grep -q '"Template" = "win7_64"' "$BOTTLE_DIR/cxbottle.conf"; then
		ok "Template: Windows 7 64-bit"
	else
		err "Template is not win7_64"
		errors=$((errors + 1))
	fi

	# Check game files exist
	if [[ -f "$BOTTLE_DIR/$DEST_DIR/age.exe" ]] && [[ -f "$BOTTLE_DIR/$DEST_DIR/agerc.dll" ]]; then
		ok "Game files present"
	else
		err "Game files missing in $BOTTLE_DIR/$DEST_DIR"
		errors=$((errors + 1))
	fi

	# Check Japanese locale in user.reg
	if grep -q '00000411' "$BOTTLE_DIR/user.reg" && grep -q 'ja_JP.UTF-8' "$BOTTLE_DIR/user.reg"; then
		ok "Japanese locale set in user.reg"
	else
		err "Japanese locale not found in user.reg — run jp_locale import"
		errors=$((errors + 1))
	fi

	# Check codepages in system.reg
	if grep -q '"ACP"="932"' "$BOTTLE_DIR/system.reg" && grep -q '"OEMCP"="932"' "$BOTTLE_DIR/system.reg"; then
		ok "Japanese codepages set in system.reg"
	else
		err "Japanese codepages not found in system.reg"
		errors=$((errors + 1))
	fi

	# Check virtual desktop config
	if grep -q 'VirtualDesktop' "$BOTTLE_DIR/user.reg"; then
		ok "Virtual Desktop configured"
	else
		warn "Virtual Desktop not configured (optional)"
	fi

	if ((errors > 0)); then
		die "$errors verification check(s) failed. Review the output above."
	fi

	echo ""
	echo "============================================="
	echo "  ✅  Setup complete!"
	echo "============================================="
	echo ""
	echo "  Bottle:  $BOTTLE_NAME"
	echo "  Path:    $BOTTLE_DIR"
	echo "  Game:    C:\\Games\\Kamadori\\age.exe"
	echo ""
	echo "  To launch via CrossOver GUI:"
	echo "    1. Open CrossOver"
	echo "    2. Select the '$BOTTLE_NAME' bottle"
	echo "    3. Click 'Run Command...'"
	echo "    4. Choose C:\\Games\\Kamadori\\age.exe"
	echo "    5. Click Run"
	echo ""
	echo "  To launch via Terminal:"
	echo "    $WINE \"$BOTTLE_DIR/$DEST_DIR/age.exe\""
	echo ""
	echo "============================================="
}

# --- Main --------------------------------------------------------------------
main() {
	echo ""
	echo "╔═══════════════════════════════════════════════╗"
	echo "║   Kamidori Alchemy Meister — macOS Setup      ║"
	echo "╚═══════════════════════════════════════════════╝"

	check_prereqs
	create_bottle
	copy_game_files
	import_jp_locale
	patch_system_reg
	import_game_config
	verify
}

main "$@"
