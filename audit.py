"""Read-only audit-log query helpers."""

from __future__ import annotations

from typing import Any

import db


def search(
    filters: dict[str, str], *, page: int = 1, page_size: int = 20
) -> dict[str, Any]:
    clauses: list[str] = []
    params: list[Any] = []

    if filters.get("reference"):
        clauses.append("t.reference_number LIKE %s")
        params.append(f"%{filters['reference']}%")
    if filters.get("staff"):
        clauses.append("s.staff_name LIKE %s")
        params.append(f"%{filters['staff']}%")
    if filters.get("action"):
        clauses.append("a.action_type = %s")
        params.append(filters["action"].upper())
    if filters.get("from"):
        clauses.append("DATE(a.action_time) >= %s")
        params.append(filters["from"])
    if filters.get("to"):
        clauses.append("DATE(a.action_time) <= %s")
        params.append(filters["to"])
    where = " WHERE " + " AND ".join(clauses) if clauses else ""
    total_row = db.query_one(
        "SELECT COUNT(*) AS total FROM TRANSACTION_AUDIT a "
        "LEFT JOIN BANK_TRANSACTION t ON t.transaction_id = a.transaction_id "
        "LEFT JOIN STAFF s ON s.staff_id = a.staff_id" + where,
        params,
    )
    total = int(total_row["total"] if total_row else 0)
    entries = db.query_all(
        "SELECT a.audit_id, a.action_time, a.action_type, a.old_status, "
        "a.new_status, a.action_details, t.reference_number, s.staff_name "
        "FROM TRANSACTION_AUDIT a "
        "LEFT JOIN BANK_TRANSACTION t ON t.transaction_id = a.transaction_id "
        "LEFT JOIN STAFF s ON s.staff_id = a.staff_id"
        + where
        + " ORDER BY a.action_time DESC, a.audit_id DESC LIMIT %s OFFSET %s",
        (*params, page_size, (page - 1) * page_size),
    )
    return {
        "entries": entries,
        "page": page,
        "pages": max(1, (total + page_size - 1) // page_size),
        "total": total,
        "page_size": page_size,
    }
