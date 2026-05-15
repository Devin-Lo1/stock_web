import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager
import os
from pathlib import Path
from typing import Any

import psycopg
from dotenv import load_dotenv
from psycopg.rows import dict_row


BACKEND_ROOT = Path(__file__).resolve().parents[2]
load_dotenv(BACKEND_ROOT / ".env")

DATABASE_PATH = BACKEND_ROOT / "data" / "stock_mvp.sqlite3"
DATABASE_URL = os.getenv("DATABASE_URL", "").strip()


class _DatabaseConnection:
    def __init__(self, connection: Any, *, is_postgres: bool) -> None:
        self._connection = connection
        self.is_postgres = is_postgres

    def execute(self, query: str, parameters: Any = ()) -> Any:
        return self._connection.execute(
            _sql_for_backend(query, self.is_postgres),
            parameters,
        )

    def executemany(self, query: str, parameters: Any) -> Any:
        sql = _sql_for_backend(query, self.is_postgres)
        if not self.is_postgres:
            return self._connection.executemany(sql, parameters)
        with self._connection.cursor() as cursor:
            return cursor.executemany(sql, parameters)

    def commit(self) -> None:
        self._connection.commit()

    def close(self) -> None:
        self._connection.close()


@contextmanager
def _connect() -> Iterator[_DatabaseConnection]:
    if _uses_postgres():
        connection = psycopg.connect(DATABASE_URL, row_factory=dict_row)
        wrapped = _DatabaseConnection(connection, is_postgres=True)
    else:
        connection = sqlite3.connect(DATABASE_PATH)
        connection.row_factory = sqlite3.Row
        wrapped = _DatabaseConnection(connection, is_postgres=False)
    try:
        yield wrapped
        wrapped.commit()
    finally:
        wrapped.close()


def _uses_postgres() -> bool:
    return DATABASE_URL.startswith(("postgresql://", "postgres://"))


def _sql_for_backend(query: str, is_postgres: bool) -> str:
    if not is_postgres:
        return query
    return query.replace("?", "%s")


def _first_column(row: Any) -> Any:
    if isinstance(row, dict):
        return next(iter(row.values()))
    return row[0]

def _ensure_column(
    connection: _DatabaseConnection,
    table_name: str,
    column_name: str,
    column_definition: str,
) -> None:
    if connection.is_postgres:
        columns = {
            row["column_name"]
            for row in connection.execute(
                """
                SELECT column_name
                FROM information_schema.columns
                WHERE table_schema = current_schema()
                  AND table_name = ?
                """,
                (table_name,),
            ).fetchall()
        }
    else:
        columns = {
            row["name"]
            for row in connection.execute(f"PRAGMA table_info({table_name})").fetchall()
        }
    if column_name in columns:
        return
    connection.execute(
        f"ALTER TABLE {table_name} ADD COLUMN {column_name} {column_definition}",
    )
