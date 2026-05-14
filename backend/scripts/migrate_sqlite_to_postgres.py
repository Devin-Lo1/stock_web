from __future__ import annotations

import sqlite3
import sys
from pathlib import Path
from typing import Iterable

import psycopg
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
load_dotenv(ROOT / ".env")

from app import database  # noqa: E402


TABLES = {
    "positions": ("id",),
    "quote_snapshots": ("code",),
    "klines": ("code", "period", "time"),
}


def main() -> None:
    if not database.DATABASE_URL:
        raise SystemExit("DATABASE_URL is required.")
    if not database.DATABASE_PATH.exists():
        raise SystemExit(f"SQLite database does not exist: {database.DATABASE_PATH}")

    database.init_database(seed_defaults=False)

    sqlite_connection = sqlite3.connect(database.DATABASE_PATH)
    sqlite_connection.row_factory = sqlite3.Row
    try:
        with psycopg.connect(database.DATABASE_URL) as postgres_connection:
            for table_name, conflict_columns in TABLES.items():
                count = migrate_table(
                    sqlite_connection,
                    postgres_connection,
                    table_name,
                    conflict_columns,
                )
                print(f"migrated {table_name}: {count}")
            postgres_connection.commit()

        database.init_database()
        print("migration completed")
    finally:
        sqlite_connection.close()


def migrate_table(
    sqlite_connection: sqlite3.Connection,
    postgres_connection: psycopg.Connection,
    table_name: str,
    conflict_columns: tuple[str, ...],
) -> int:
    columns = _table_columns(sqlite_connection, table_name)
    if not columns:
        return 0

    rows = sqlite_connection.execute(f"SELECT * FROM {table_name}").fetchall()
    if not rows:
        return 0

    insert_columns = ", ".join(columns)
    placeholders = ", ".join(["%s"] * len(columns))
    conflict_target = ", ".join(conflict_columns)
    update_columns = [column for column in columns if column not in conflict_columns]
    update_clause = ", ".join(
        f"{column} = excluded.{column}" for column in update_columns
    )
    sql = (
        f"INSERT INTO {table_name} ({insert_columns}) "
        f"VALUES ({placeholders}) "
        f"ON CONFLICT ({conflict_target}) DO UPDATE SET {update_clause}"
    )

    with postgres_connection.cursor() as cursor:
        cursor.executemany(
            sql,
            [tuple(row[column] for column in columns) for row in rows],
        )
    return len(rows)


def _table_columns(
    sqlite_connection: sqlite3.Connection,
    table_name: str,
) -> list[str]:
    return [
        row["name"]
        for row in sqlite_connection.execute(f"PRAGMA table_info({table_name})")
    ]


if __name__ == "__main__":
    main()
