"""MySQL connection-pool access and transaction helpers."""

from __future__ import annotations

import os
from contextlib import contextmanager
from typing import Any, Iterator, Sequence

from dotenv import load_dotenv
import mysql.connector
from mysql.connector import pooling
from mysql.connector.connection import MySQLConnection

load_dotenv()

_pool: pooling.MySQLConnectionPool | None = None


def _get_pool() -> pooling.MySQLConnectionPool:
    global _pool
    if _pool is None:
        _pool = pooling.MySQLConnectionPool(
            pool_name="banking_fraud_pool",
            pool_size=5,
            host=os.getenv("DB_HOST") or os.getenv("MYSQL_HOST", "localhost"),
            port=int(os.getenv("DB_PORT") or os.getenv("MYSQL_PORT", "3306")),
            user=os.getenv("DB_USER") or os.getenv("MYSQL_USER", ""),
            password=os.getenv("DB_PASSWORD") or os.getenv("MYSQL_PASSWORD", ""),
            database=os.getenv("DB_NAME") or os.getenv("MYSQL_DATABASE", "banking_fraud_system"),
            autocommit=True,
        )
    return _pool


@contextmanager
def connection_context(staff_id: int | None = None) -> Iterator[MySQLConnection]:
    """Use one pooled connection and set the trigger actor for the transaction."""
    connection = _get_pool().get_connection()
    try:
        cursor = connection.cursor()
        try:
            cursor.execute("SET @app_staff_id = %s", (staff_id,))
        finally:
            cursor.close()
        yield connection
        if not connection.autocommit:
            connection.commit()
    except Exception:
        if not connection.autocommit:
            connection.rollback()
        raise
    finally:
        try:
            if not connection.autocommit:
                connection.rollback()
        except Exception:
            pass
        connection.close()


def query_all(
    sql: str,
    params: Sequence[Any] | None = None,
    *,
    connection: MySQLConnection | None = None,
    staff_id: int | None = None,
) -> list[dict[str, Any]]:
    def run(conn: MySQLConnection) -> list[dict[str, Any]]:
        cursor = conn.cursor(dictionary=True)
        try:
            cursor.execute(sql, params or ())
            return list(cursor.fetchall())
        finally:
            cursor.close()

    if connection is not None:
        return run(connection)
    with connection_context(staff_id) as conn:
        return run(conn)


def query_one(
    sql: str,
    params: Sequence[Any] | None = None,
    *,
    connection: MySQLConnection | None = None,
    staff_id: int | None = None,
) -> dict[str, Any] | None:
    rows = query_all(sql, params, connection=connection, staff_id=staff_id)
    return rows[0] if rows else None


def execute(
    sql: str,
    params: Sequence[Any] | None = None,
    *,
    connection: MySQLConnection | None = None,
    staff_id: int | None = None,
) -> tuple[int, int]:
    def run(conn: MySQLConnection) -> tuple[int, int]:
        cursor = conn.cursor()
        try:
            cursor.execute(sql, params or ())
            return cursor.lastrowid, cursor.rowcount
        finally:
            cursor.close()

    if connection is not None:
        return run(connection)
    with connection_context(staff_id) as conn:
        return run(conn)


def call_proc(
    name: str,
    args: Sequence[Any],
    *,
    staff_id: int | None = None,
) -> tuple[Any, ...]:
    if not name.replace("_", "").isalnum():
        raise ValueError("Invalid stored procedure name.")
    with connection_context(staff_id) as connection:
        cursor = connection.cursor()
        try:
            result = cursor.callproc(name, tuple(args))
            for stored_result in cursor.stored_results():
                stored_result.fetchall()
                stored_result.close()
            while cursor.nextset():
                pass
            return tuple(result)
        finally:
            cursor.close()


def close_pool() -> None:
    """Reset the pool reference; individual pooled connections close per use."""
    global _pool
    _pool = None
