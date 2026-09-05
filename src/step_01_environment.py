"""Lesson 1: inspect local tools and optionally a dump, without connecting to a DB."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys


def postgres_tool(name):
    """Find a PostgreSQL command even when Windows PATH does not include it."""
    found = shutil.which(name)
    if found:
        return Path(found)
    root = Path(os.environ.get("ProgramFiles", "C:/Program Files")) / "PostgreSQL"
    installs = list(root.glob("*/bin"))
    installs.sort(
        key=lambda path: tuple(int(n) for n in path.parent.name.split(".") if n.isdigit()),
        reverse=True,
    )
    for folder in installs:
        executable = folder / f"{name}.exe"
        if executable.is_file():
            return executable
    return None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dump", type=Path, help="Full path to the latest database dump")
    args = parser.parse_args()

    print(f"Python: {sys.version.split()[0]}")
    print(f"Interpreter: {sys.executable}")
    ready = sys.version_info >= (3, 10)
    for name in ("psql", "pg_restore", "createdb"):
        executable = postgres_tool(name)
        if executable is None:
            print(f"MISSING: {name}")
            ready = False
        else:
            result = subprocess.run(
                [str(executable), "--version"], capture_output=True, text=True, check=True
            )
            print(f"{result.stdout.strip()} | {executable}")

    if args.dump:
        dump = args.dump.expanduser().resolve(strict=True)
        if dump.is_file():
            with dump.open("rb") as stream:
                prefix = stream.read(4096)
            print(f"Dump: {dump} ({dump.stat().st_size:,} bytes)")
            is_archive = prefix.startswith(b"PGDMP") or prefix[257:262] == b"ustar"
        else:
            is_archive = (dump / "toc.dat").is_file()
            print(f"Dump directory: {dump}")

        if is_archive:
            executable = postgres_tool("pg_restore")
            if executable is None:
                raise ValueError("pg_restore is needed to inspect this archive.")
            result = subprocess.run(
                [str(executable), "--list", str(dump)], capture_output=True,
                text=True, encoding="utf-8", errors="replace", check=True,
            )
            # Only summary metadata is printed; row contents are never read here.
            print("Format: PostgreSQL archive")
            for line in result.stdout.splitlines():
                if "Dumped from database version:" in line or "Dumped by pg_dump version:" in line:
                    print(line.lstrip("; "))
            data_entries = sum(" TABLE DATA efrm " in line for line in result.stdout.splitlines())
            print(f"EFRM table-data entries: {data_entries} (entries do not prove row counts)")
        elif dump.is_file() and b"PostgreSQL database dump" in prefix:
            print("Format: plain SQL. Restore uses psql; data completeness is not yet checked.")
        else:
            raise ValueError("Dump format is unrecognized. Inspect it before choosing a restore command.")
    else:
        print("Dump: not checked. Rerun with --dump and the latest dump path.")

    print("Local tools: READY" if ready else "Local tools: NEED SETUP")
    print("No database connection or restore was attempted.")
    return 0 if ready else 1


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"Check failed: {exc}", file=sys.stderr)
        raise SystemExit(1)

