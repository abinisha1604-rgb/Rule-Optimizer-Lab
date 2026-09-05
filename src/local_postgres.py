"""Create/manage our separate local PostgreSQL instance and restore the learning dump.

Examples:
    python local_postgres.py setup
    python local_postgres.py status
    python local_postgres.py stop
    python local_postgres.py start
    python local_postgres.py overview
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import time

import psycopg
from psycopg import sql

from step_01_environment import postgres_tool


SOURCE_DIR = Path(__file__).resolve().parent
LAB_DIR = SOURCE_DIR.parent
STATE = LAB_DIR / ".local-postgres"
PG_DATA = STATE / "data"
PASSWORD_FILE = STATE / "password.txt"
RECEIPT = STATE / "restore_receipt.json"
DEFAULT_DUMP = LAB_DIR / "data" / "Kanji_011_20260903-133238.dump"
CONFIG = {"host": "127.0.0.1", "port": 55432,
          "dbname": "efrm_optimizer_lab", "user": "lab_owner"}


def run_tool(name, args, *, check=True, env=None, capture=False):
    executable = postgres_tool(name)
    if executable is None:
        raise ValueError(f"PostgreSQL tool missing: {name}")
    command = [str(executable), *map(str, args)]
    creationflags = subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0
    if name == "pg_ctl" and "start" in args:
        # The server can inherit pg_ctl's output handles on Windows. A pipe
        # makes communicate() wait until the server exits; a file does not.
        startup_log = STATE / "startup.log"
        with startup_log.open("w", encoding="utf-8") as output:
            completed = subprocess.run(
                command, check=False, env=env, stdin=subprocess.DEVNULL,
                stdout=output, stderr=subprocess.STDOUT, creationflags=creationflags,
            )
        result = subprocess.CompletedProcess(
            command, completed.returncode,
            startup_log.read_text(encoding="utf-8", errors="replace"), "",
        )
    else:
        result = subprocess.run(
            command, check=False, env=env,
            capture_output=True, text=True, encoding="utf-8", errors="replace",
            creationflags=creationflags,
        )
    # Forward captured output explicitly; hidden Windows child processes can
    # otherwise lose inherited console output in the desktop terminal.
    if not capture:
        print(result.stdout, end="", flush=True)
        print(result.stderr, end="", file=sys.stderr, flush=True)
    if check:
        result.check_returncode()
    return result


def initialize():
    if (PG_DATA / "PG_VERSION").is_file():
        if not PASSWORD_FILE.is_file():
            raise ValueError("Existing lab cluster has no saved lab password; inspect it before proceeding.")
        return
    if PG_DATA.exists() and any(PG_DATA.iterdir()):
        raise ValueError("Lab data directory is not empty. Inspect the previous initialization first.")
    STATE.mkdir(exist_ok=True)
    if not PASSWORD_FILE.exists():
        with PASSWORD_FILE.open("x", encoding="utf-8") as stream:
            stream.write(secrets.token_urlsafe(32) + "\n")
    print("Initializing a separate PostgreSQL cluster in the lab directory...", flush=True)
    run_tool("initdb", ["-D", PG_DATA, "--username=lab_owner", "--pwfile", PASSWORD_FILE,
                       "--auth=scram-sha-256", "--encoding=UTF8", "--locale=C"])
    with (PG_DATA / "postgresql.conf").open("a", encoding="utf-8") as stream:
        stream.write("\n# Local rule optimizer learning instance\n"
                     "listen_addresses = '127.0.0.1'\nport = 55432\n"
                     "max_connections = 20\nshared_buffers = '64MB'\ntimezone = 'UTC'\n")


def _postmaster_process_is_alive():
    """Return whether the PID in postmaster.pid still belongs to a process."""
    pid_file = PG_DATA / "postmaster.pid"
    if not pid_file.is_file():
        return False
    try:
        pid = int(pid_file.read_text(encoding="utf-8").splitlines()[0])
    except (OSError, ValueError, IndexError):
        return False
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except OSError:
        # Permission errors mean a process exists but cannot be inspected.
        return True
    return True


def _remove_stale_postmaster_pid():
    """Remove only a lock file whose postmaster process is definitely gone."""
    pid_file = PG_DATA / "postmaster.pid"
    if pid_file.is_file() and not _postmaster_process_is_alive():
        pid_file.unlink()


def _direct_start():
    """Start postgres.exe when Windows pg_ctl cannot create a restricted token."""
    executable = postgres_tool("postgres")
    if executable is None:
        raise ValueError("PostgreSQL server executable is missing.")
    startup_log = STATE / "direct_server.log"
    command = [str(executable), "-D", str(PG_DATA)]
    creationflags = (getattr(subprocess, "CREATE_NO_WINDOW", 0)
                     | getattr(subprocess, "DETACHED_PROCESS", 0))
    with startup_log.open("a", encoding="utf-8") as output:
        process = subprocess.Popen(
            command, stdin=subprocess.DEVNULL, stdout=output, stderr=subprocess.STDOUT,
            creationflags=creationflags,
        )
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if process.poll() is not None:
            details = startup_log.read_text(encoding="utf-8", errors="replace")
            raise ValueError(f"Direct PostgreSQL start failed; inspect {startup_log}.\n{details[-1200:]}")
        try:
            with socket.create_connection((CONFIG["host"], CONFIG["port"]), timeout=1):
                print("Lab PostgreSQL started directly (Windows pg_ctl token fallback).", flush=True)
                return
        except OSError:
            time.sleep(0.25)
    raise ValueError(f"PostgreSQL did not accept connections within 30 seconds; inspect {startup_log}.")


def start():
    if not (PG_DATA / "PG_VERSION").is_file():
        raise ValueError("Run setup first to create this lab instance.")
    status = run_tool("pg_ctl", ["-D", PG_DATA, "status"], check=False, capture=True)
    if status.returncode == 0:
        print("Lab PostgreSQL is already running.", flush=True)
        return
    if status.returncode != 3:
        raise ValueError("Cannot determine lab server status. Inspect the lab directory and server.log.")
    # If another application uses our port, do not change or stop that application.
    try:
        with socket.socket() as probe:
            probe.bind((CONFIG["host"], CONFIG["port"]))
    except OSError as exc:
        # A server can finish starting between the status check and the probe.
        # Re-check before reporting a real port conflict.
        latest_status = run_tool("pg_ctl", ["-D", PG_DATA, "status"], check=False, capture=True)
        if latest_status.returncode == 0:
            print("Lab PostgreSQL is already running.", flush=True)
            return
        raise ValueError(
            f"Port {CONFIG['port']} is already in use by another process; no process was stopped."
        ) from exc
    _remove_stale_postmaster_pid()
    result = run_tool(
        "pg_ctl", ["-D", PG_DATA, "-l", STATE / "server.log", "-w", "-t", "30", "start"],
        check=False,
    )
    if result.returncode == 0:
        return
    if os.name == "nt" and "restricted token" in (result.stdout or "").lower():
        print("pg_ctl could not create a Windows restricted token; using direct postgres.exe startup.", flush=True)
        _remove_stale_postmaster_pid()
        _direct_start()
        return
    raise subprocess.CalledProcessError(
        result.returncode, result.args, output=result.stdout, stderr=result.stderr
    )


def restore(dump):
    with dump.open("rb") as stream:
        if stream.read(5) != b"PGDMP":
            raise ValueError("This setup exercise expects a PostgreSQL custom archive.")
        stream.seek(0)
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    password = PASSWORD_FILE.read_text(encoding="utf-8").strip()
    admin_config = {**CONFIG, "dbname": "postgres"}
    with psycopg.connect(**admin_config, password=password, autocommit=True, connect_timeout=5) as conn:
        exists = conn.execute("SELECT 1 FROM pg_database WHERE datname = %s",
                              (CONFIG["dbname"],)).fetchone()
        if exists:
            previous = json.loads(RECEIPT.read_text()) if RECEIPT.exists() else {}
            if previous.get("sha256") != digest:
                raise ValueError("Lab DB already exists without a successful receipt for this dump. No overwrite performed.")
            print("This dump was already restored successfully; proceeding to the live inventory.", flush=True)
            return
        conn.execute(sql.SQL("CREATE DATABASE {} TEMPLATE template0").format(
            sql.Identifier(CONFIG["dbname"])))

    environment = os.environ.copy()
    environment["PGPASSWORD"] = password
    environment["PGCONNECT_TIMEOUT"] = "5"
    outputs = LAB_DIR / "outputs"
    outputs.mkdir(exist_ok=True)
    log_file = outputs / "restore.log"
    executable = postgres_tool("pg_restore")
    if executable is None:
        raise ValueError("pg_restore is missing.")
    command = [str(executable), "--host=127.0.0.1", "--port=55432", "--username=lab_owner",
               "--dbname=efrm_optimizer_lab", "--no-password", "--no-owner", "--no-privileges",
               "--exit-on-error", "--single-transaction", "--verbose", str(dump)]
    print(f"Restoring {dump.name} into 127.0.0.1:55432 / efrm_optimizer_lab...", flush=True)
    print(f"Restore progress log: {log_file}", flush=True)
    with log_file.open("w", encoding="utf-8") as log:
        result = subprocess.run(
            command, env=environment, stdout=log, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0,
        )
    if result.returncode:
        raise ValueError("Restore failed; inspect outputs/restore.log. The restore transaction rolled back; the newly created database remains.")
    receipt = {"dump": str(dump), "bytes": dump.stat().st_size, "sha256": digest,
               "connection": CONFIG, "restored_at_utc": datetime.now(timezone.utc).isoformat(),
               "restore_log": str(log_file), "restore_exit_code": result.returncode}
    RECEIPT.write_text(json.dumps(receipt, indent=2) + "\n", encoding="utf-8")
    print("Restore completed successfully.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("setup", "start", "stop", "status", "overview"))
    parser.add_argument("--dump", type=Path, default=DEFAULT_DUMP)
    args = parser.parse_args()
    if args.action == "setup":
        dump = args.dump.resolve(strict=True)
        # Validate the archive and all tools before creating the instance.
        for name in ("initdb", "pg_ctl", "pg_restore"):
            if postgres_tool(name) is None:
                raise ValueError(f"PostgreSQL tool missing: {name}")
        run_tool("pg_restore", ["--list", dump], capture=True)
        initialize()
        start()
        restore(dump)
        (LAB_DIR / "config.local.json").write_text(json.dumps(CONFIG, indent=2) + "\n", encoding="utf-8")
        result = subprocess.run([sys.executable, str(SOURCE_DIR / "step_02_connect.py")], cwd=LAB_DIR)
        return result.returncode
    if args.action == "start":
        start()
        return 0
    if args.action == "overview":
        environment = os.environ.copy()
        environment["PGPASSWORD"] = PASSWORD_FILE.read_text(encoding="utf-8").strip()
        environment["PGCONNECT_TIMEOUT"] = "5"
        environment["PGOPTIONS"] = "-c default_transaction_read_only=on -c statement_timeout=30000"
        result = run_tool("psql", ["-X", "--no-password", "--host=127.0.0.1", "--port=55432",
                                   "--username=lab_owner", "--dbname=efrm_optimizer_lab",
                                   "--set=ON_ERROR_STOP=1", "--file", LAB_DIR / "sql" / "01_case_overview.sql"],
                          env=environment, check=False)
        if result.returncode == 0:
            output = LAB_DIR / "outputs" / "case_overview.txt"
            output.parent.mkdir(exist_ok=True)
            output.write_text(result.stdout, encoding="utf-8")
            print(f"Case overview saved: {output}")
        return result.returncode
    if not (PG_DATA / "PG_VERSION").is_file():
        print("Lab PostgreSQL has not been initialized.")
        return 1
    if args.action == "stop":
        # Fast shutdown closes connections and rolls back active transactions cleanly.
        return run_tool("pg_ctl", ["-D", PG_DATA, "-w", "-t", "30", "-m", "fast", "stop"],
                        check=False).returncode
    return run_tool("pg_ctl", ["-D", PG_DATA, "status"], check=False).returncode


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except psycopg.Error as exc:
        print(f"Local database operation failed ({type(exc).__name__}); inspect .local-postgres/server.log.", file=sys.stderr)
        raise SystemExit(1)
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"Lab setup failed: {exc}", file=sys.stderr)
        raise SystemExit(1)
