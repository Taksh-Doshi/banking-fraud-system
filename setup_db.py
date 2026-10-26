from __future__ import annotations

import argparse
import os
import re
from pathlib import Path
from typing import Iterator

import mysql.connector
from dotenv import load_dotenv
from mysql.connector.connection import MySQLConnection


ROOT = Path(__file__).resolve().parent
SQL_DIR = ROOT / "sql"


def _has_sql(text: str) -> bool:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.DOTALL)
    text = re.sub(r"(?m)^\s*(?:--|#).*$", "", text)
    return bool(text.strip())


def parse_sql_script(script: str) -> Iterator[str]:
    """Yield complete SQL statements while honoring DELIMITER directives."""
    delimiter = ";"
    buffer: list[str] = []
    quote: str | None = None
    line_comment = False
    block_comment = False
    index = 0

    while index < len(script):
        if not quote and not block_comment:
            line_end = script.find("\n", index)
            if line_end < 0:
                line_end = len(script)
            line = script[index:line_end].strip()
            delimiter_match = re.fullmatch(r"DELIMITER\s+(\S+)", line, re.IGNORECASE)
            if delimiter_match and not _has_sql("".join(buffer)):
                delimiter = delimiter_match.group(1)
                buffer.clear()
                index = line_end + (line_end < len(script))
                continue

        char = script[index]
        next_char = script[index + 1] if index + 1 < len(script) else ""

        if line_comment:
            buffer.append(char)
            if char == "\n":
                line_comment = False
            index += 1
            continue
        if block_comment:
            buffer.append(char)
            if char == "*" and next_char == "/":
                buffer.append(next_char)
                block_comment = False
                index += 2
            else:
                index += 1
            continue
        if quote:
            buffer.append(char)
            if char == "\\" and next_char:
                buffer.append(next_char)
                index += 2
                continue
            if char == quote:
                if next_char == quote:
                    buffer.append(next_char)
                    index += 2
                    continue
                quote = None
            index += 1
            continue

        if char in ("'", '"', "`"):
            quote = char
            buffer.append(char)
            index += 1
            continue
        if char == "-" and next_char == "-" and (
            index + 2 == len(script) or script[index + 2].isspace()
        ):
            line_comment = True
            buffer.extend((char, next_char))
            index += 2
            continue
        if char == "#":
            line_comment = True
            buffer.append(char)
            index += 1
            continue
        if char == "/" and next_char == "*":
            block_comment = True
            buffer.extend((char, next_char))
            index += 2
            continue
        if script.startswith(delimiter, index):
            statement = "".join(buffer).strip()
            if _has_sql(statement):
                yield statement
            buffer.clear()
            index += len(delimiter)
            continue

        buffer.append(char)
        index += 1

    remaining = "".join(buffer).strip()
    if _has_sql(remaining):
        yield remaining


def load_script(
    connection: MySQLConnection, path: Path, database_name: str
) -> None:
    script = path.read_text(encoding="utf-8")
    if path.name == "schema.sql":
        quoted_name = f"`{database_name}`"
        script = script.replace(
            "CREATE DATABASE IF NOT EXISTS banking_fraud_db;",
            f"CREATE DATABASE IF NOT EXISTS {quoted_name};",
        ).replace("USE banking_fraud_db;", f"USE {quoted_name};")

    cursor = connection.cursor()
    try:
        for statement in parse_sql_script(script):
            cursor.execute(statement)
            while cursor.nextset():
                pass
            connection.commit()
    except mysql.connector.Error as error:
        connection.rollback()
        raise RuntimeError(
            f"Failed while executing {path.relative_to(ROOT)}: {error}"
        ) from error
    finally:
        cursor.close()


def print_summary(connection: MySQLConnection) -> None:
    tables = (
        "CUSTOMER_ACCOUNT",
        "STAFF",
        "BANK_TRANSACTION",
        "FRAUD_FLAG",
        "INVESTIGATION",
        "TRANSACTION_AUDIT",
    )
    cursor = connection.cursor()
    try:
        print("Database row counts:")
        for table in tables:
            cursor.execute(f"SELECT COUNT(*) FROM `{table}`")
            print(f"  {table}: {cursor.fetchone()[0]}")
        cursor.execute(
            "SELECT COALESCE(rule_id, 'MANUAL') AS rule_id, COUNT(*) "
            "FROM FRAUD_FLAG GROUP BY rule_id ORDER BY rule_id"
        )
        print("Fraud flags by rule:")
        for rule_id, count in cursor.fetchall():
            print(f"  {rule_id}: {count}")
    finally:
        cursor.close()


def main() -> int:
    load_dotenv(ROOT / ".env")
    parser = argparse.ArgumentParser(description="Set up the banking fraud database.")
    parser.add_argument(
        "--no-sample",
        action="store_true",
        help="Load schema and database logic without sample data.",
    )
    args = parser.parse_args()

    database_name = os.getenv("DB_NAME") or os.getenv(
        "MYSQL_DATABASE", "banking_fraud_db"
    )
    if not re.fullmatch(r"[A-Za-z0-9_]+", database_name):
        parser.error("DB_NAME may contain only letters, numbers, and underscores.")
    config = {
        "host": os.getenv("DB_HOST") or os.getenv("MYSQL_HOST", "localhost"),
        "port": int(os.getenv("DB_PORT") or os.getenv("MYSQL_PORT", "3306")),
        "user": os.getenv("DB_USER") or os.getenv("MYSQL_USER", ""),
        "password": os.getenv("DB_PASSWORD") or os.getenv("MYSQL_PASSWORD", ""),
    }
    if not config["user"]:
        parser.error("Set DB_USER in .env before continuing.")
    if not (os.getenv("SECRET_KEY") or os.getenv("FLASK_SECRET_KEY")):
        parser.error("Set SECRET_KEY in .env before continuing.")

    connection = mysql.connector.connect(**config)
    try:
        for file_name in ("schema.sql", "procedures.sql"):
            load_script(connection, SQL_DIR / file_name, database_name)
        if not args.no_sample:
            load_script(connection, SQL_DIR / "sample_data.sql", database_name)
        print_summary(connection)
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
