#!/usr/bin/env python3
"""
Patch user.reg with game-specific settings (Virtual Desktop, D3D overrides).

Sets:
  [Software\\Wine\\AppDefaults\\age.exe\\X11 Driver]
    Managed=Y, VirtualDesktop=640x480, WindowDecorated=Y

  [Software\\Wine\\AppDefaults\\age.exe\\DllOverrides]
    d3d9=builtin, d3dx9_43=builtin

Usage:
    python3 patch_game_config.py <path/to/user.reg>
"""

import re
import sys


def set_section_values(text, section_header, fix_map):
    """Set or update key=value pairs in a registry section."""
    section_pat = re.compile(re.escape(section_header))
    section_match = section_pat.search(text)

    if not section_match:
        lines = [section_header]
        for key, val in fix_map.items():
            lines.append(f'"{key}"="{val}"')
        text += "\n" + "\n".join(lines) + "\n"
        return text

    rest = text[section_match.end() :]
    next_sec = re.search(r"^\[", rest, re.MULTILINE)
    if next_sec:
        body = rest[: next_sec.start()]
        end = section_match.end() + next_sec.start()
    else:
        body = rest
        end = len(text)

    lines = body.split("\n")
    new_lines = []
    fixed = set()

    for line in lines:
        matched = False
        for key, val in fix_map.items():
            if line.startswith(f'"{key}"='):
                new_lines.append(f'"{key}"="{val}"')
                fixed.add(key)
                matched = True
                break
        if not matched:
            new_lines.append(line)

    missing_keys = [k for k in fix_map if k not in fixed]
    if missing_keys:
        insert_idx = 0
        for i, line in enumerate(new_lines):
            s = line.strip()
            if s == "" or s.startswith("#"):
                insert_idx = i + 1
            else:
                break
        for k in missing_keys:
            new_lines.insert(insert_idx, f'"{k}"="{fix_map[k]}"')
            insert_idx += 1

    new_body = "\n".join(new_lines)
    return text[: section_match.end()] + new_body + text[end:]


def patch_game_config(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()

    text = set_section_values(
        text,
        r"[Software\\Wine\\AppDefaults\\age.exe\\X11 Driver]",
        {
            "Managed": "Y",
            "VirtualDesktop": "640x480",
            "WindowDecorated": "Y",
        },
    )

    text = set_section_values(
        text,
        r"[Software\\Wine\\AppDefaults\\age.exe\\DllOverrides]",
        {
            "d3d9": "builtin",
            "d3dx9_43": "builtin",
        },
    )

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path/to/user.reg>", file=sys.stderr)
        sys.exit(1)
    patch_game_config(sys.argv[1])
    print("Patched user.reg with game config")
