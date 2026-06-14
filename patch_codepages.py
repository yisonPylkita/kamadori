#!/usr/bin/env python3
"""
Patch system.reg with Japanese codepages (ACP=932, OEMCP=932, MACCP=10001).

Usage:
    python3 patch_codepages.py <path/to/system.reg>
"""

import re
import sys


def patch_system_reg(path: str) -> bool:
    with open(path) as f:
        text = f.read()

    section_header = r"[System\\CurrentControlSet\\Control\\Nls\\Codepage]"
    section_pattern = re.compile(re.escape(section_header))
    section_match = section_pattern.search(text)

    if not section_match:
        # Section doesn't exist — append it
        text += "\n" + section_header + "\n"
        text += '"ACP"="932"\n'
        text += '"OEMCP"="932"\n'
        text += '"MACCP"="10001"\n'
        with open(path, "w") as f:
            f.write(text)
        return True

    # Section exists - find its boundaries
    rest = text[section_match.end() :]

    next_section = re.search(r"^\[", rest, re.MULTILINE)
    if next_section:
        section_body = rest[: next_section.start()]
        section_end = section_match.end() + next_section.start()
    else:
        section_body = rest
        section_end = len(text)

    # Process section lines — always set correct values
    lines = section_body.split("\n")
    new_lines = []
    acp_found = False
    oemcp_found = False
    maccp_found = False

    for line in lines:
        if line.startswith('"ACP"='):
            new_lines.append('"ACP"="932"')
            acp_found = True
        elif line.startswith('"OEMCP"='):
            new_lines.append('"OEMCP"="932"')
            oemcp_found = True
        elif line.startswith('"MACCP"='):
            new_lines.append('"MACCP"="10001"')
            maccp_found = True
        else:
            new_lines.append(line)

    # Insert missing keys after header/comment lines
    if not (acp_found and oemcp_found and maccp_found):
        # Find insertion index: skip blank lines and the #time= comment
        insert_idx = 0
        for i, line in enumerate(new_lines):
            stripped = line.strip()
            if stripped == "" or stripped.startswith("#"):
                insert_idx = i + 1
            else:
                break

        if not acp_found:
            new_lines.insert(insert_idx, '"ACP"="932"')
            insert_idx += 1
        if not oemcp_found:
            new_lines.insert(insert_idx, '"OEMCP"="932"')
            insert_idx += 1
        if not maccp_found:
            new_lines.insert(insert_idx, '"MACCP"="10001"')

    new_body = "\n".join(new_lines)
    text = text[: section_match.end()] + '\n' + new_body + text[section_end:]

    with open(path, "w") as f:
        f.write(text)
    return True


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <path/to/system.reg>", file=sys.stderr)
        sys.exit(1)
    path = sys.argv[1]
    patch_system_reg(path)
    print(f"Patched {path}")
