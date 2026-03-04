#!/usr/bin/env python3
from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: patch_gn_bootstrap.py <bootstrap.py>")
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"missing file: {path}")
        return 1

    text = path.read_text(encoding="utf-8")
    original = text

    text = text.replace(
        "gn_path = options.output or os.path.join(out_dir, 'gn')",
        "gn_bin = 'gn.exe' if os.name == 'nt' else 'gn'\n"
        "  gn_path = options.output or os.path.join(out_dir, gn_bin)",
    )
    text = text.replace(
        "cmd = [ninja_binary, '-C', gn_build_dir, 'gn.exe']",
        "cmd = [ninja_binary, '-C', gn_build_dir, gn_bin]",
    )
    text = text.replace(
        "cmd = [ninja_binary, '-C', gn_build_dir, 'gn']",
        "cmd = [ninja_binary, '-C', gn_build_dir, gn_bin]",
    )
    text = text.replace(
        "shutil.copy2(os.path.join(gn_build_dir, 'gn'), gn_path)",
        "shutil.copy2(os.path.join(gn_build_dir, gn_bin), gn_path)",
    )

    if text != original:
        path.write_text(text, encoding="utf-8")
        print("Patched bootstrap.py for Windows GN binary naming")
    else:
        print("bootstrap.py already patched")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
