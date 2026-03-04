#!/usr/bin/env python3
"""
Minimal vpython3 compatibility shim for local builds.

It strips vpython-only flags and forwards the remaining args to the system
Python interpreter.
"""

from __future__ import annotations

import os
import sys


def _filter_args(argv: list[str]) -> list[str]:
    out: list[str] = []
    i = 0
    while i < len(argv):
        arg = argv[i]

        # vpython uses "--" to separate its own args from target command args.
        if arg == "--":
            out.extend(argv[i + 1 :])
            break

        # Drop vpython-specific flags.
        if arg.startswith("-vpython"):
            # Handle "-vpython-foo=value" form.
            if "=" in arg:
                i += 1
                continue
            # Handle "-vpython-spec FILE" / "-vpython-tool TOOL" form.
            if arg in ("-vpython-spec", "-vpython-tool") and i + 1 < len(argv):
                i += 2
                continue
            i += 1
            continue

        out.append(arg)
        i += 1

    return out


def main() -> int:
    args = _filter_args(sys.argv[1:])
    if not args:
        return 0
    os.execv(sys.executable, [sys.executable] + args)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
