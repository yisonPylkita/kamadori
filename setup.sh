#!/usr/bin/env bash
#
# setup.sh — One-command setup for Kamidori Alchemy Meister on macOS Apple Silicon
# ==============================================================================
# Creates a CrossOver bottle, configures Japanese locale & game settings,
# copies game files, and verifies everything.
#
# Usage:
#   chmod +x setup.sh && ./setup.sh         # fresh install
#   chmod +x setup.sh && ./setup.sh --force  # delete & recreate
#
# Requirements:
#   - macOS on Apple Silicon (M1/M2/M3/M4)
#   - CrossOver 26+ installed in /Applications/CrossOver.app
#   - Game files extracted in this repository's Kamadori/ directory
#   - ~10 GB free disk space
# ==============================================================================

set -euo pipefail

# --- CLI flags ---------------------------------------------------------------
FORCE=0
for arg in "$@"; do
	if [[ "$arg" == "--force" ]]; then FORCE=1; fi
done

# --- Configuration -----------------------------------------------------------
BOTTLE_NAME="Kamadori"
BOTTLE_DIR="$HOME/Library/Application Support/CrossOver/Bottles/$BOTTLE_NAME"
GAME_DIR="$(cd "$(dirname "$0")" && pwd)/Kamadori"
CROSSOVER_BIN="/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin"
WINE="$CROSSOVER_BIN/wine"
CXBOTTLE="$CROSSOVER_BIN/cxbottle"
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

# --- Helper: set a registry value via reg.exe (silent) -----------------------
reg_set() {
	local key="$1" name="$2" type="$3" value="$4"
	"$WINE" --bottle "$BOTTLE_NAME" reg.exe add "$key" \
		/v "$name" /t "$type" /d "$value" /f >/dev/null 2>&1 || true
}

# --- Helper: run a Python patcher -------------------------------------------
py_patch() {
	local script="$1" target="$2"
	python3 "$(cd "$(dirname "$0")" && pwd)/$script" "$target" 2>&1
}

# --- Step 0: Prerequisites ---------------------------------------------------
check_prereqs() {
	echo ""
	info "Checking prerequisites..."

	local arch
	arch=$(uname -m)
	if [[ "$arch" != "arm64" ]]; then
		die "This script is intended for Apple Silicon (M1/M2/M3/M4). Detected: $arch"
	fi
	ok "Apple Silicon detected ($arch)"

	if [[ ! -d "/Applications/CrossOver.app" ]]; then
		die "CrossOver.app not found in /Applications. Please install CrossOver 26+ first."
	fi
	if [[ ! -x "$CXBOTTLE" ]]; then
		die "cxbottle CLI not found inside CrossOver. Is CrossOver 26+ installed?"
	fi
	ok "CrossOver found at /Applications/CrossOver.app"

	if [[ ! -d "$GAME_DIR" ]]; then
		die "Game directory not found at $GAME_DIR. Ensure Kamadori/ exists alongside this script."
	fi
	if [[ ! -f "$GAME_DIR/age.exe" ]] || [[ ! -f "$GAME_DIR/agerc.dll" ]]; then
		die "Required files age.exe and/or agerc.dll missing in $GAME_DIR"
	fi
	ok "Game files found in $GAME_DIR"

	local available_kb
	available_kb=$(df "$HOME" | awk 'NR==2 {print $4}')
	local available_gb=$((available_kb / 1024 / 1024))
	if ((available_gb < 5)); then
		warn "Only ${available_gb} GB free on $HOME — at least 5 GB is recommended."
	else
		ok "Disk space: ${available_gb} GB free"
	fi

	if [[ -d "$BOTTLE_DIR" ]]; then
		if ((FORCE)); then
			warn "Bottle '$BOTTLE_NAME' exists — removing (--force)..."
			$WINESERVER -k 2>/dev/null || true
			sleep 1
			rm -rf "$BOTTLE_DIR"
			ok "Old bottle removed"
		else
			warn "Bottle '$BOTTLE_NAME' already exists at:"
			echo "       $BOTTLE_DIR"
			echo "       To delete:  rm -rf \"$BOTTLE_DIR\""
			warn "Or use:  ./setup.sh --force"
			die "Aborting to avoid overwriting an existing bottle."
		fi
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

	# Phase 1: Copy root game files (excluding Backup/ metadata)
	local root_count
	root_count=$(find "$GAME_DIR" -maxdepth 1 -type f 2>/dev/null | wc -l | tr -d ' ')

	echo -n "       Copying $root_count root files... "
	rsync -a "$GAME_DIR/" "$dest/" \
		--exclude "Backup/" --exclude "patch/" 2>/dev/null &
	local pid1=$!

	local spin='-\|/' i=0
	while kill -0 "$pid1" 2>/dev/null; do
		i=$(((i + 1) % 4))
		echo -ne "\b${spin:$i:1}"
		sleep 0.2
	done
	wait "$pid1" 2>/dev/null || true

	# Phase 2: Apply English patch files from patch/ directory (overwrites originals)
	local patch_dir="$GAME_DIR/patch"
	if [[ -d "$patch_dir" ]]; then
		local patch_count
		patch_count=$(find "$patch_dir" -type f 2>/dev/null | wc -l | tr -d ' ')
		echo -ne "\b, applying $patch_count English patch files... "
		rsync -a "$patch_dir/" "$dest/" 2>/dev/null &
		local pid2=$!

		i=0
		while kill -0 "$pid2" 2>/dev/null; do
			i=$(((i + 1) % 4))
			echo -ne "\b${spin:$i:1}"
			sleep 0.2
		done
		wait "$pid2" 2>/dev/null || true
	fi

	echo -e "\b done"
	ok "Game files + English patch applied to C:\\Games\\Kamadori"
	echo ""
}

# --- Step 3: Set Japanese locale ---------------------------------------------
import_jp_locale() {
	info "Setting Japanese locale..."

	$WINESERVER -k 2>/dev/null || true
	sleep 1
	py_patch "patch_user_reg_jp.py" "$BOTTLE_DIR/user.reg"

	reg_set "HKCU\\Control Panel\\International" ACP REG_SZ "932"
	reg_set "HKCU\\Control Panel\\International" OEMCP REG_SZ "932"
	reg_set "HKCU\\Control Panel\\International" sLanguage REG_SZ "JPN"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\International" Locale REG_SZ "00000411"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\International" ACP REG_SZ "932"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\International" OEMCP REG_SZ "932"

	ok "Japanese locale set"
	echo ""
}

# --- Step 4: Patch system.reg for codepages ----------------------------------
patch_system_reg() {
	info "Patching system.reg for Japanese codepages..."
	py_patch "patch_codepages.py" "$BOTTLE_DIR/system.reg"
	ok "system.reg patched with Japanese codepages"
	echo ""
}

# --- Step 5: Set game config (Virtual Desktop, D3D) --------------------------
import_game_config() {
	info "Setting game config (Virtual Desktop, D3D overrides)..."

	$WINESERVER -k 2>/dev/null || true
	sleep 1
	py_patch "patch_game_config.py" "$BOTTLE_DIR/user.reg"

	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\X11 Driver" VirtualDesktop REG_SZ "640x480"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\X11 Driver" Managed REG_SZ "Y"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\X11 Driver" WindowDecorated REG_SZ "Y"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\DllOverrides" d3d9 REG_SZ "builtin"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\DllOverrides" d3dx9_43 REG_SZ "builtin"

	ok "Game config set"
	echo ""
}

# --- Step 6: Install Japanese fonts -----------------------------------------
install_japanese_fonts() {
	info "Installing Japanese IPAex fonts..."
	local font_dir="$BOTTLE_DIR/drive_c/windows/Fonts"
	mkdir -p "$font_dir"

	# IPAex fonts are freely licensed Japanese fonts
	local ipaex_g="$font_dir/ipaexg.ttf"
	local ipaex_m="$font_dir/ipaexm.ttf"

	if [[ -f "$ipaex_g" && -f "$ipaex_m" ]]; then
		ok "IPAex fonts already installed"
	else
		local tmp_dir
		local zip_path
		tmp_dir=$(mktemp -d)
		zip_path="$tmp_dir/ipa.zip"

		if curl -sL "https://moji.or.jp/wp-content/ipafont/IPAexfont/IPAexfont00401.zip" -o "$zip_path" 2>/dev/null && [[ -s "$zip_path" ]]; then
			unzip -q -o "$zip_path" -d "$tmp_dir/extracted" 2>/dev/null
			cp "$tmp_dir/extracted"/*/ipaexg.ttf "$font_dir/" 2>/dev/null || true
			cp "$tmp_dir/extracted"/*/ipaexm.ttf "$font_dir/" 2>/dev/null || true
			rm -rf "$tmp_dir"
		fi

		if [[ -f "$ipaex_g" && -f "$ipaex_m" ]]; then
			ok "IPAex fonts installed"
		else
			warn "Could not download IPAex fonts — game may crash on text rendering"
			warn "Manual install: place ipaexg.ttf and ipaexm.ttf in:"
			warn "  $font_dir"
		fi
	fi

	# Update font substitutions in user.reg to use IPAex fonts
	$WINESERVER -k 2>/dev/null || true
	python3 "$(cd "$(dirname "$0")" && pwd)/patch_fonts.py" "$BOTTLE_DIR/user.reg"
	ok "Japanese fonts configured"
	echo ""
}

# --- Step 7: Verify ----------------------------------------------------------
verify() {
	echo ""
	info "Verifying and finalizing bottle configuration..."

	# Phase 1: Patch user.reg while wineserver is dead
	$WINESERVER -k 2>/dev/null || true
	sleep 1

	py_patch "patch_user_reg_jp.py" "$BOTTLE_DIR/user.reg"
	py_patch "patch_game_config.py" "$BOTTLE_DIR/user.reg"

	# Phase 2: Load user values into wineserver memory via reg.exe
	reg_set "HKCU\\Control Panel\\International" ACP REG_SZ "932"
	reg_set "HKCU\\Control Panel\\International" OEMCP REG_SZ "932"
	reg_set "HKCU\\Control Panel\\International" sLanguage REG_SZ "JPN"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\Locales" LANG REG_SZ "ja_JP.UTF-8"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\Locales" LC_ALL REG_SZ "ja_JP.UTF-8"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\Locales" LC_CTYPE REG_SZ "ja_JP.UTF-8"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\International" Locale REG_SZ "00000411"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\International" ACP REG_SZ "932"
	reg_set "HKCU\\Software\\Wine\\AppDefaults\\age.exe\\International" OEMCP REG_SZ "932"

	$WINESERVER -k 2>/dev/null || true
	$WINESERVER -w 2>/dev/null || true
	sleep 2
	py_patch "patch_codepages.py" "$BOTTLE_DIR/system.reg"
	$WINESERVER -k 2>/dev/null || true
	sleep 1
	py_patch "patch_codepages.py" "$BOTTLE_DIR/system.reg"
	py_patch "patch_codepages.py" "$BOTTLE_DIR/system.reg"

	rm -f "$BOTTLE_DIR/.update-timestamp" 2>/dev/null || true

	local errors=0

	# Checks
	if grep -q '"Template" = "win7_64"' "$BOTTLE_DIR/cxbottle.conf"; then
		ok "Template: Windows 7 64-bit"
	else
		err "Template is not win7_64"
		errors=$((errors + 1))
	fi

	if [[ -f "$BOTTLE_DIR/$DEST_DIR/age.exe" ]] && [[ -f "$BOTTLE_DIR/$DEST_DIR/agerc.dll" ]]; then
		ok "Game files present"
	else
		err "Game files missing in $BOTTLE_DIR/$DEST_DIR"
		errors=$((errors + 1))
	fi

	if grep -q '00000411' "$BOTTLE_DIR/user.reg" && grep -q 'ja_JP.UTF-8' "$BOTTLE_DIR/user.reg"; then
		ok "Japanese locale set in user.reg"
	else
		err "Japanese locale not found in user.reg"
		errors=$((errors + 1))
	fi

	if grep -q '"ACP"="932"' "$BOTTLE_DIR/system.reg" && grep -q '"OEMCP"="932"' "$BOTTLE_DIR/system.reg"; then
		ok "Japanese codepages set in system.reg"
	else
		err "Japanese codepages not found in system.reg"
		errors=$((errors + 1))
	fi

	if grep -q 'VirtualDesktop' "$BOTTLE_DIR/user.reg"; then
		ok "Virtual Desktop configured"
	else
		warn "Virtual Desktop not configured (optional)"
	fi

	if ((errors > 0)); then
		die "$errors verification check(s) failed. Review above."
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
	echo "    cd \"$BOTTLE_DIR/$DEST_DIR\""
	echo "    LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8 LC_MESSAGES=ja_JP.UTF-8 \\"
	echo "      $WINE --bottle $BOTTLE_NAME --no-wait age.exe"
	echo ""
	echo "    (The game must be launched from its own directory. The LC_ALL"
	echo "     environment variable is required for proper Japanese text display.)"
	echo ""
	echo "============================================="
}

# --- Main --------------------------------------------------------------------
usage() {
	echo "Usage: $(basename "$0") [--force]"
	echo ""
	echo "  --force    Remove existing bottle and recreate from scratch"
	exit 0
}

main() {
	echo ""
	echo "╔═══════════════════════════════════════════════╗"
	echo "║   Kamidori Alchemy Meister — macOS Setup      ║"
	echo "╚═══════════════════════════════════════════════╝"

	for arg in "$@"; do
		if [[ "$arg" != "--force" ]]; then
			echo "Unknown option: $arg"
			usage
		fi
	done

	check_prereqs
	create_bottle
	copy_game_files
	import_jp_locale
	patch_system_reg
	import_game_config
	install_japanese_fonts
	verify
}

main "$@"
