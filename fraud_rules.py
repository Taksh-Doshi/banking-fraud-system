"""Thin Python wrappers for database-owned transaction and fraud behavior."""

from __future__ import annotations

from decimal import Decimal
from typing import Any

import db


def evaluate_transaction(
    transaction_id: int, staff_id: int | None = None
) -> None:
    db.call_proc("sp_evaluate_fraud_rules", (transaction_id,), staff_id=staff_id)


def run_weekly_analysis(staff_id: int | None = None) -> int:
    result = db.call_proc("sp_weekly_analysis", (0,), staff_id=staff_id)
    return int(result[0] or 0)


def create_manual_flag(
    transaction_id: int,
    staff_id: int,
    reason: str,
    severity: str,
) -> int:
    flag_id, _ = db.execute(
        "INSERT INTO FRAUD_FLAG "
        "(transaction_id, rule_id, rule_name, rule_description, rule_type, "
        "flag_source, reason, severity, created_by_staff_id) "
        "VALUES (%s, NULL, 'MANUAL_REVIEW', 'Manually created staff review.', "
        "'MANUAL', 'MANUAL', %s, %s, %s)",
        (transaction_id, reason, severity, staff_id),
        staff_id=staff_id,
    )
    return flag_id


def make_transaction(
    transaction_type: str,
    from_account_id: int | None,
    to_account_id: int | None,
    amount: Decimal,
    staff_id: int | None = None,
) -> dict[str, Any]:
    result = db.call_proc(
        "sp_make_transaction",
        (transaction_type, from_account_id, to_account_id, amount, 0, None, None),
        staff_id=staff_id,
    )
    return {
        "transaction_id": int(result[4]),
        "result": result[5],
        "message": result[6],
    }


def reverse_transaction(transaction_id: int, staff_id: int) -> dict[str, Any]:
    result = db.call_proc(
        "sp_reverse_transaction",
        (transaction_id, staff_id, None, None),
        staff_id=staff_id,
    )
    return {"result": result[2], "message": result[3]}
