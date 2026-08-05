"""Shared argparse helpers for consistent CLI exit codes."""
from __future__ import annotations

import argparse
import sys


PARSE_HELP = object()
PARSE_ERROR = object()


def make_parser(prog: str, *, description: str | None = None) -> argparse.ArgumentParser:
    """ArgumentParser with consistent help formatting."""
    return argparse.ArgumentParser(
        prog=prog,
        description=description,
        add_help=True,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )


def parse_known_or_error(
    parser: argparse.ArgumentParser,
    argv: list[str],
) -> tuple[argparse.Namespace, list[str]] | object:
    """Parse argv; return PARSE_HELP or PARSE_ERROR sentinel on failure."""
    if "-h" in argv or "--help" in argv:
        parser.print_help()
        return PARSE_HELP
    try:
        return parser.parse_known_args(argv)
    except SystemExit as exc:
        if exc.code == 0:
            return PARSE_HELP
        return PARSE_ERROR


def first_unknown_flag(argv: list[str], known: set[str]) -> str | None:
    """Return the first unknown option token in argv, or None if all are valid."""
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            i += 1
            continue
        if arg.startswith("--"):
            flag = arg.split("=", 1)[0]
            if flag not in known:
                return arg
            if "=" not in arg and flag in known and i + 1 < len(argv) and not argv[i + 1].startswith("-"):
                i += 2
                continue
        elif arg.startswith("-") and arg not in known:
            return arg
        i += 1
    return None


def reject_unknown_flags(argv: list[str], known: set[str]) -> int | None:
    """Print and return exit code 2 when argv contains an unknown flag."""
    bad = first_unknown_flag(argv, known)
    if bad is None:
        return None
    print(f"Unknown option: {bad}", file=sys.stderr)
    return 2
