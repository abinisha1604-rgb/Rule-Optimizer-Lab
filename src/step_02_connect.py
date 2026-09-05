"""Lesson 2: connect to the restored local lab and inspect its actual schema."""

import argparse
import getpass
import json
import os
from pathlib import Path
import sys


LAB_DIR = Path(__file__).resolve().parent.parent
REQUIRED_TABLES = (
    "case_master", "case_alert_mapping", "case_decision_master",
    "transaction_request", "transaction_master", "transaction_result",
    "transaction_match", "transaction_alert", "rule_master", "rule_version",
)
SUPPORTING_TABLES = (
    "rule_group_master", "rule_group_version", "rule_group_version_map",
    "rule_group_source_binding", "rule_decision_policy", "rule_decision_upgrade",
    "rule_metric_dependency", "metric_definition", "aggregated_metric", "case_events",
)


def load_config(path):
    config = json.loads(path.read_text(encoding="utf-8-sig"))
    allowed = {"host", "port", "dbname", "user"}
    if set(config) != allowed:
        raise ValueError("Config must contain only host, port, dbname, and user. No password field.")
    # Keep this exercise pointed at the local learning copy requested by the user.
    if config["host"] != "127.0.0.1" or config["dbname"] != "efrm_optimizer_lab":
        raise ValueError("This lesson connects only to 127.0.0.1 / efrm_optimizer_lab.")
    if type(config["port"]) is not int or not 1 <= config["port"] <= 65535:
        raise ValueError("port must be an integer from 1 to 65535.")
    if not isinstance(config["user"], str) or not config["user"].strip():
        raise ValueError("user must be a nonempty string.")
    return config


def inspect_database(conn, sql):
    """Get metadata and exact counts, without selecting case/transaction payloads."""
    identity = conn.execute(
        "SELECT current_database(), current_user, current_setting('server_version'), "
        "current_setting('transaction_read_only')"
    ).fetchone()
    if identity[0] != "efrm_optimizer_lab" or identity[3] != "on":
        raise ValueError("The connection must use the lab database and a read-only transaction.")

    expected = REQUIRED_TABLES + SUPPORTING_TABLES
    columns = conn.execute(
        "SELECT table_name, column_name, data_type "
        "FROM information_schema.columns "
        "WHERE table_schema = %s AND table_name = ANY(%s) "
        "ORDER BY table_name, ordinal_position",
        ("efrm", list(expected)),
    ).fetchall()
    inventory = {}
    for table in expected:
        table_columns = [
            {"name": name, "type": data_type}
            for table_name, name, data_type in columns if table_name == table
        ]
        item = {"present": bool(table_columns), "columns": table_columns}
        if table_columns:
            # Values use %s parameters above; SQL identifiers use Identifier here.
            query = sql.SQL("SELECT count(*) FROM {}.{}").format(
                sql.Identifier("efrm"), sql.Identifier(table)
            )
            item["rows"] = conn.execute(query).fetchone()[0]
            print(f"  {table}: {item['rows']:,} rows")
        else:
            print(f"  {table}: MISSING OR NOT VISIBLE TO THIS USER")
        inventory[table] = item

    return {
        "database": identity[0], "user": identity[1], "server_version": identity[2],
        "transaction_read_only": identity[3], "schema": "efrm", "tables": inventory,
        "missing_required_tables": [t for t in REQUIRED_TABLES if not inventory[t]["present"]],
        "note": "Counts cover the local copy across institutions. This is a schema inventory, not optimizer evidence.",
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--config", type=Path, default=LAB_DIR / "config.local.json")
    parser.add_argument("--check-config", action="store_true", help="Validate configuration without connecting")
    args = parser.parse_args()
    config = load_config(args.config)
    if args.check_config:
        print("Config OK: local lab database selected. No connection attempted.")
        return 0

    try:
        import psycopg
        from psycopg import sql
    except ImportError:
        print("Install the lab requirements first: python -m pip install -r requirements.txt")
        return 1

    password = os.environ.get("EFRM_LAB_PASSWORD")
    local_password = LAB_DIR / ".local-postgres" / "password.txt"
    if (password is None and config["user"] == "lab_owner"
            and config["port"] == 55432 and local_password.is_file()):
        password = local_password.read_text(encoding="utf-8").strip()
    if password is None:
        password = getpass.getpass("Local PostgreSQL password (input hidden): ")

    try:
        with psycopg.connect(
            **config, password=password, connect_timeout=5,
            application_name="rule_optimizer_learning_lab",
            options="-c default_transaction_read_only=on -c statement_timeout=30000",
        ) as conn:
            conn.isolation_level = psycopg.IsolationLevel.REPEATABLE_READ
            conn.read_only = True
            report = inspect_database(conn, sql)
    except psycopg.Error as exc:
        # Do not dump connection arguments or credentials into logs.
        print(f"Database check failed ({type(exc).__name__}).", file=sys.stderr)
        print("Check the service, local port/user/password, restore status, and table permissions.", file=sys.stderr)
        print("A count taking over 30 seconds also stops this lesson.", file=sys.stderr)
        return 1

    output = LAB_DIR / "outputs" / "db_inventory.json"
    output.parent.mkdir(exist_ok=True)
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(f"Inventory saved: {output}")
    if report["missing_required_tables"]:
        print("Connection succeeded, but required tables are missing/inaccessible. Check the restore.")
        return 1
    print("Connection and required tables: OK. Next: select an institution and inspect case decisions.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, EOFError) as exc:
        print(f"Setup error: {exc}", file=sys.stderr)
        raise SystemExit(1)
