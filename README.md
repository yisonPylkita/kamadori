# Kamidori Alchemy Meister — macOS Playbook

> **Game:** Kamidori Alchemy Meister (神採りアルケミーマイスター)
> **Publisher:** Eushully (2011)
> **Engine:** System4.x (age.exe)
> **Platform:** Windows → macOS (Apple Silicon) via CrossOver

---

## 📦 Repository Contents

| Path | Description |
|---|---|
| `setup.sh` | **All-in-one setup script** — creates the bottle, copies files, configures locale & settings |
| `jp_locale.reg` | Registry file for Japanese system locale (required for text rendering) |
| `game_config.reg` | Registry file for game-specific settings (virtual desktop, D3D overrides) |
| `game.rar` | Original game archive (Win32 RAR, ~2.9 GB) |
| `Kamadori/` | Extracted game + Fuwanovel English patch |
| `Kamadori/Backup/` | Original Japanese file backups (`.bak`) |
| `Kamadori/patch/` | English patch files |
| `Kamadori/age.exe` | Eushully System4.x engine (2.1 MB — patched) |
| `Kamadori/agerc.dll` | Eushully engine runtime (418 KB — patched) |
| `README.md` | This file |

## 💻 Requirements

- **macOS** on Apple Silicon (M1/M2/M3/M4)
- **CrossOver 26+** (installed at `/Applications/CrossOver.app`)
- ~10 GB free disk space

---

## 🚀 One-command Setup

```bash
chmod +x setup.sh && ./setup.sh
```

The script will automatically:

| Step | What it does |
|---|---|
| 1. **Prerequisites** | Verifies Apple Silicon, CrossOver, game files, and disk space |
| 2. **Create bottle** | Creates a `Kamadori` CrossOver bottle (Windows 7 64-bit) using `cxbottle` |
| 3. **Copy game files** | Copies `Kamadori/` into the bottle's `C:\Games\Kamadori` |
| 4. **Japanese locale** | Imports `jp_locale.reg` — sets Japanese system locale for Shift-JIS text support |
| 5. **Codepages** | Patches `system.reg` with `ACP=932`, `OEMCP=932`, `MACCP=10001` |
| 6. **Game config** | Imports `game_config.reg` — enables 640×480 virtual desktop, D3D overrides |
| 7. **Verification** | Checks all settings and reports the result |

### Manual steps (if not using the script)

<details>
<summary>Click to expand manual instructions</summary>

### 1. Create the bottle in CrossOver

- Open **CrossOver**
- Click **"+" → New Bottle**
- Select: **"Windows 7 64-bit"** (template `win7_64`)
- Name: **`Kamadori`**

### 2. Copy game files

```bash
cp -R Kamadori/ ~/Library/Application\ Support/CrossOver/Bottles/Kamadori/drive_c/Games/Kamadori/
```

Make sure `age.exe` and `agerc.dll` are in the **same** directory.

### 3. Set Windows version to 7

**Via CrossOver GUI:**
- Select the `Kamadori` bottle
- Right-click → **Settings**
- Change "Windows Version" to **Windows 7**

**Via registry:**
```bash
cp jp_locale.reg ~/Library/Application\ Support/CrossOver/Bottles/Kamadori/drive_c/
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle Kamadori regedit "C:\jp_locale.reg"
```

### 4. Set Japanese system locale (CRITICAL)

The game requires Japanese **System Locale** (non-Unicode program language).
In Windows: *Region → Administrative → Change system locale → Japanese (Japan)*.

In Wine/CrossOver this is set via registry. Create `jp_locale.reg`:

```registry
REGEDIT4

[HKEY_CURRENT_USER\Control Panel\International]
"Locale"="00000411"
"LocaleName"="ja-JP"
"ACP"="932"
"OEMCP"="932"
"Country"="81"
"sLanguage"="JPN"

[HKEY_CURRENT_USER\Software\Wine\AppDefaults\age.exe\Locales]
"LC_ALL"="ja_JP.UTF-8"
"LC_CTYPE"="ja_JP.UTF-8"
"LANG"="ja_JP.UTF-8"

[HKEY_CURRENT_USER\Software\Wine\AppDefaults\age.exe\International]
"Locale"="00000411"
"ACP"="932"
"OEMCP"="932"
```

Copy to the bottle and import:
```bash
cp jp_locale.reg ~/Library/Application\ Support/CrossOver/Bottles/Kamadori/drive_c/
/Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle Kamadori regedit "C:\jp_locale.reg"
```

Additionally, edit the bottle's `system.reg` — add in the `[System\CurrentControlSet\Control\Nls\Codepage]` section:
```registry
"ACP"="932"
"OEMCP"="932"
"MACCP"="10001"
```

### 5. Virtual Desktop (recommended)

In the bottle's `user.reg` add:
```registry
[HKEY_CURRENT_USER\Software\Wine\AppDefaults\age.exe\X11 Driver]
"Managed"="Y"
"VirtualDesktop"="640x480"
"WindowDecorated"="Y"

[HKEY_CURRENT_USER\Software\Wine\AppDefaults\age.exe\DllOverrides]
"d3d9"="builtin"
"d3dx9_43"="builtin"
```

### 6. Verification

Your `cxbottle.conf` should contain:
```
"Template" = "win7_64"
```

Check in `system.reg` that `CurrentVersion` is `"6.1"` (Windows 7) and in `[Control Panel\International]` that `Locale` is `"00000411"` (Japanese).

</details>

---

## 🎮 Launching

### Via CrossOver GUI:
1. Select the **Kamadori** bottle
2. Click **Run Command...**
3. Choose: `C:\Games\Kamadori\age.exe`
4. Click **Run**

### Via Terminal:

```bash
cd "$HOME/Library/Application Support/CrossOver/Bottles/Kamadori/drive_c/Games/Kamadori"
LC_ALL=ja_JP.UTF-8 LANG=ja_JP.UTF-8 LC_MESSAGES=ja_JP.UTF-8 \
  /Applications/CrossOver.app/Contents/SharedSupport/CrossOver/bin/wine \
  --bottle Kamadori \
  --no-wait \
  age.exe
```

> **Important:** The game must be launched from its own directory.
> The `LC_ALL=ja_JP.UTF-8` is required because Wine on macOS cannot change
> the locale internally. Without it, system dialogs show garbled Shift-JIS text.

---

## 🐛 Known Issues & Fixes

### ❌ "Exception c0000005" (ACCESS_VIOLATION)

**Cause:** Bottle set to Windows XP (template `winxp_64`).
**Fix:** Switch to Windows 7 (see Step 3 above).

### ❌ Empty squares instead of text / missing fonts

**Cause:** Missing Japanese locale.
**Fix:** Add the Locales entries in `user.reg` (see Step 4 above).

### ❌ Game runs but no audio

**Cause:** WineGStreamer / CoreAudio issues.
**Fixes:**
- In CrossOver → Settings → Audio → select "CoreAudio"
- Launch via terminal with `WINEDLLOVERRIDES="winmm=native"`

### ❌ Black screen / no rendering

**Cause:** D3D9 → wined3d → Metal/VKD3D issues.
**Fixes:**
- In CrossOver → Settings → disable "Use DXVK" if enabled
- Try adding override: `d3d9=b`, `wined3d=b` in DllOverrides
- In `user.reg`:

```registry
[Software\\Wine\\AppDefaults\\age.exe\\DllOverrides] 1781395365
#time=1dcfb913c2a0308
"d3d9"="builtin"
```

---

## 📁 Game Technical Structure

### age.exe — Eushully System4.x Engine

- 32-bit PE (i386)
- Uses custom runtime `agerc.dll`
- Rendering via Direct3D 9
- Assets in `.ALF` archives (encrypted)
- Scenario scripts in `.BIN` files
- Graphics in `.AGF` files (proprietary Eushully format)
- Music in `.OGG`

### agerc.dll — Eushully Runtime

- Custom runtime library
- Handles: memory management, file I/O, text encoding (Shift-JIS)
- Loaded as a dependency of `age.exe`
- In the English patch — modified for ASCII/UTF-8 support

### Data Files

| Extension | Contents |
|---|---|
| `.ALF` | Asset archives (graphics, data) |
| `.BIN` | Compiled scripts (scenario, maps, AI) |
| `.AGF` | Graphics + character/item data |
| `.OGG` | Music and sound effects |

---

## 🔄 Backup & Restore

Backups of original Japanese files are in `Backup/`:

| Original File | Backup |
|---|---|
| `age.exe` (2.1 MB, EN) | `Backup/age.exe.bak` (1.1 MB, JP) |
| `agerc.dll` (418 KB, EN) | `Backup/agerc.dll.bak` (347 KB, JP) |
| `$1$CIMES.bin` | `Backup/$1$CIMES.bin.bak` |
| ... | ... |

To restore the Japanese version, copy files from `Backup/` to the game directory.

---

## 🧠 Technical Notes

- **CrossOver 26.2.0** is based on **Wine 11.0**
- Apple Silicon → Wine in WOW64 mode (64-bit host, 32-bit guest)
- Rendering: Direct3D 9 → WineD3D → Metal (via Apple Game Porting Toolkit)
- `agerc.dll` requires base address `0x7e960000` — verified to load correctly
- Encoding: original Shift-JIS, English patch ASCII/UTF-8

---

## 📚 Sources

- [Fuwanovel — Kamidori Alchemy Meister English Patch](https://fuwanovel.net/)
- [Eushully — Official Website](https://www.eushully.com/)
- [CrossOver — CodeWeavers](https://www.codeweavers.com/crossover/)
- [WineHQ — Kamidori Alchemy Meister](https://appdb.winehq.org/)
