#!/usr/bin/env python3
from pathlib import Path
import argparse


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("args_gn")
    parser.add_argument("--set", action="append", default=[])
    ns = parser.parse_args()

    path = Path(ns.args_gn)
    path.parent.mkdir(parents=True, exist_ok=True)
    text = path.read_text(encoding="utf-8") if path.exists() else ""
    text = text.replace("\r\n", "\n").replace("\\n", "\n")

    pairs = []
    keys = set()
    for item in ns.set:
        if "=" not in item:
            raise SystemExit(f"invalid --set value: {item}")
        k, v = item.split("=", 1)
        k = k.strip()
        v = v.strip()
        pairs.append((k, v))
        keys.add(k)

    lines = []
    for ln in text.splitlines():
        s = ln.strip()
        if not s:
            continue
        skip = False
        for key in keys:
            if s.startswith(key):
                skip = True
                break
        if not skip:
            lines.append(ln.rstrip())

    for k, v in pairs:
        lines.append(f"{k} = {v}")

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
