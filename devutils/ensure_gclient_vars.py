#!/usr/bin/env python3
from pathlib import Path
import re
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: ensure_gclient_vars.py <.gclient path>")
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"missing file: {path}")
        return 1

    text = path.read_text(encoding="utf-8")
    original = text

    if '"generate_location_tags"' not in text:
        marker = '"custom_vars": {'
        idx = text.find(marker)
        if idx != -1:
            insert_at = idx + len(marker)
            text = (
                text[:insert_at]
                + '\n      "generate_location_tags": False,'
                + text[insert_at:]
            )
    if '"checkout_pgo_profiles"' not in text:
        marker = '"custom_vars": {'
        idx = text.find(marker)
        if idx != -1:
            insert_at = idx + len(marker)
            text = (
                text[:insert_at]
                + '\n      "checkout_pgo_profiles": False,'
                + text[insert_at:]
            )
    text = re.sub(
        r'"checkout_pgo_profiles"\s*:\s*(?:"True"|True)',
        '"checkout_pgo_profiles": False',
        text,
    )

    # Ensure CIPD deps (including third_party/ninja) are fetched.
    text = re.sub(
        r'"non_git_source"\s*:\s*(?:"False"|False)',
        '"non_git_source": True',
        text,
    )
    # Ensure Windows host deps (CIPD ninja.exe, etc.) are selected on Windows.
    text = re.sub(r"target_os\s*=\s*\[[^\]]*\];", "target_os = ['win'];", text)
    text = re.sub(r"target_os_only\s*=\s*(True|False);", "target_os_only = True;", text)

    if text != original:
        path.write_text(text, encoding="utf-8")
        print("Updated .gclient: ensured local build custom_vars")
    else:
        print(".gclient already contains required custom vars")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
