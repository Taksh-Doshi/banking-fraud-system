"""End-to-end checks against a configured MySQL database loaded with sample data."""

from __future__ import annotations

import re
import sys
from decimal import Decimal
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import app as web_app  # noqa: E402
import db  # noqa: E402
from mysql.connector import Error  # noqa: E402


PASSWORD = "Demo@123"


def csrf(response: Any) -> str:
    match = re.search(
        rb'name="csrf_token"\s+value="([^"]+)"',
        response.data,
    )
    if match is None:
        raise AssertionError("Expected a CSRF token in the rendered form.")
    return match.group(1).decode("ascii")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)
    print(f"PASS {message}")


def expect_constraint_failure(label: str, sql: str, params: tuple[Any, ...]) -> None:
    try:
        with db.connection_context() as connection:
            cursor = connection.cursor()
            try:
                cursor.execute(sql, params)
            finally:
                cursor.close()
    except Error:
        print(f"PASS database rejects {label}")
        return
    raise AssertionError(f"Database accepted invalid data: {label}")


def expect_success(label: str, sql: str, params: tuple[Any, ...]) -> None:
    with db.connection_context() as connection:
        cursor = connection.cursor()
        try:
            cursor.execute(sql, params)
        finally:
            cursor.close()
    print(f"PASS database accepts {label}")


def verify_constraints(transaction_id: int, flag_id: int) -> None:
    account = db.query_one(
        "SELECT customer_id, full_name, password_hash, account_type "
        "FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1001'"
    )
    assert account
    expect_constraint_failure(
        "duplicate account_number",
        "INSERT INTO CUSTOMER_ACCOUNT "
        "(customer_id, full_name, password_hash, account_number, account_type) "
        "VALUES (%s, %s, %s, %s, %s)",
        (
            account["customer_id"],
            account["full_name"],
            account["password_hash"],
            "ACC1001",
            account["account_type"],
        ),
    )
    expect_constraint_failure(
        "MANUAL flag without creator",
        "INSERT INTO FRAUD_FLAG "
        "(transaction_id, rule_name, rule_type, flag_source, reason, severity) "
        "VALUES (%s, 'SMOKE_MANUAL', 'MANUAL', 'MANUAL', 'smoke check', 'LOW')",
        (transaction_id,),
    )
    staff = db.query_one(
        "SELECT staff_id FROM STAFF WHERE email = 'maya.rao@fraudbank.test'"
    )
    assert staff
    expect_constraint_failure(
        "AUTOMATIC flag with staff creator",
        "INSERT INTO FRAUD_FLAG "
        "(transaction_id, rule_name, rule_type, flag_source, reason, severity, "
        "created_by_staff_id) "
        "VALUES (%s, 'SMOKE_AUTOMATIC', 'AMOUNT', 'AUTOMATIC', "
        "'smoke check', 'LOW', %s)",
        (transaction_id, staff["staff_id"]),
    )
    expect_constraint_failure(
        "duplicate (transaction_id, rule_id)",
        "INSERT INTO FRAUD_FLAG "
        "(transaction_id, rule_id, rule_name, rule_type, flag_source, reason, severity) "
        "SELECT transaction_id, rule_id, 'SMOKE_DUPLICATE', 'AMOUNT', "
        "'AUTOMATIC', 'smoke check', 'LOW' FROM FRAUD_FLAG WHERE flag_id = %s",
        (flag_id,),
    )
    expect_constraint_failure(
        "RESOLVED investigation without outcome",
        "INSERT INTO INVESTIGATION (flag_id, investigation_status) "
        "VALUES (%s, 'RESOLVED')",
        (flag_id,),
    )
    expect_constraint_failure(
        "invalid outcome text",
        "INSERT INTO INVESTIGATION (flag_id, investigation_status, outcome) "
        "VALUES (%s, 'OPEN', 'banana')",
        (flag_id,),
    )
    expect_constraint_failure(
        "invalid staff role",
        "INSERT INTO STAFF (staff_name, email, password_hash, role) "
        "VALUES ('Smoke Test', 'smoke.invalid@fraudbank.test', 'x', 'JANITOR')",
        (),
    )
    expect_success(
        "two MANUAL flags on one transaction with NULL rule IDs",
        "INSERT INTO FRAUD_FLAG "
        "(transaction_id, rule_name, rule_type, flag_source, reason, severity, "
        "created_by_staff_id) "
        "VALUES (%s, 'SMOKE_MANUAL_A', 'MANUAL', 'MANUAL', 'smoke check A', 'LOW', %s), "
        "(%s, 'SMOKE_MANUAL_B', 'MANUAL', 'MANUAL', 'smoke check B', 'LOW', %s)",
        (transaction_id, staff["staff_id"], transaction_id, staff["staff_id"]),
    )
    expect_success(
        "two investigations on one flag",
        "INSERT INTO INVESTIGATION (flag_id, investigation_status) "
        "VALUES (%s, 'OPEN'), (%s, 'OPEN')",
        (flag_id, flag_id),
    )


def login(client: Any, identifier: str, role: str) -> Any:
    page = client.get(f"/login?role={role}")
    response = client.post(
        "/login",
        data={
            "csrf_token": csrf(page),
            "role": role,
            "identifier": identifier,
            "password": PASSWORD,
            "next": "",
        },
        follow_redirects=True,
    )
    return response


def make_transaction(
    client: Any, txn_type: str, amount: str, recipient: str = ""
) -> Any:
    page = client.get(f"/customer/transactions/new?type={txn_type}")
    return client.post(
        "/customer/transactions/new",
        data={
            "csrf_token": csrf(page),
            "transaction_type": txn_type,
            "amount": amount,
            "recipient": recipient,
        },
        follow_redirects=True,
    )


def main() -> int:
    web_app.app.config.update(TESTING=True)
    customer = web_app.app.test_client()
    staff = web_app.app.test_client()

    response = login(customer, "CUST001", "customer")
    require(response.status_code == 200 and b"Dashboard" in response.data,
            "customer login succeeds")

    wrong = web_app.app.test_client()
    page = wrong.get("/login")
    wrong_response = wrong.post(
        "/login",
        data={
            "csrf_token": csrf(page),
            "role": "customer",
            "identifier": "CUST001",
            "password": "wrong-password",
        },
        follow_redirects=True,
    )
    unknown_user = web_app.app.test_client()
    unknown_page = unknown_user.get("/login")
    unknown_response = unknown_user.post(
        "/login",
        data={
            "csrf_token": csrf(unknown_page),
            "role": "customer",
            "identifier": "NO_SUCH_CUSTOMER",
            "password": PASSWORD,
        },
        follow_redirects=True,
    )
    require(
        b"could not be verified" in wrong_response.data
        and b"could not be verified" in unknown_response.data,
        "wrong customer password returns a generic error",
    )

    inactive = web_app.app.test_client()
    inactive_response = login(inactive, "inactive@fraudbank.test", "staff")
    require(b"could not be verified" in inactive_response.data,
            "inactive staff login is refused")

    account = db.query_one(
        "SELECT customer_account_id, balance FROM CUSTOMER_ACCOUNT "
        "WHERE account_number = 'ACC1001'"
    )
    recipient = db.query_one(
        "SELECT customer_account_id, balance FROM CUSTOMER_ACCOUNT "
        "WHERE account_number = 'ACC1002'"
    )
    assert account and recipient
    account_id = int(account["customer_account_id"])
    recipient_id = int(recipient["customer_account_id"])

    before = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    deposit = make_transaction(customer, "DEPOSIT", "100.00")
    after_deposit = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    require(after_deposit == before + Decimal("100.00"),
            "deposit raises the account balance")

    make_transaction(customer, "WITHDRAWAL", "25.00")
    after_withdrawal = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    require(after_withdrawal == after_deposit - Decimal("25.00"),
            "withdrawal lowers the account balance")

    stable_balance = after_withdrawal
    overdraw = make_transaction(customer, "WITHDRAWAL", "999999999.00")
    after_overdraw = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    failed_txn = db.query_one(
        "SELECT transaction_id FROM BANK_TRANSACTION "
        "WHERE transaction_type = 'WITHDRAWAL' AND from_account_id = %s "
        "AND transaction_status = 'FAILED' ORDER BY transaction_id DESC LIMIT 1",
        (account_id,),
    )
    rejected = db.query_one(
        "SELECT audit_id FROM TRANSACTION_AUDIT WHERE transaction_id = %s "
        "AND action_type = 'TRANSACTION_REJECTED'",
        (failed_txn["transaction_id"],) if failed_txn else (-1,),
    )
    require(
        after_overdraw == stable_balance
        and failed_txn is not None
        and rejected is not None
        and b"Failed" in overdraw.data,
        "overdraw records a failed transaction and rejection audit without changing balance",
    )

    from_before = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    to_before = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (recipient_id,),
    )["balance"]))
    transfer = make_transaction(customer, "TRANSFER", "5000.00", "ACC1002")
    transfer_row = db.query_one(
        "SELECT transaction_id FROM BANK_TRANSACTION WHERE from_account_id = %s "
        "AND to_account_id = %s ORDER BY transaction_id DESC LIMIT 1",
        (account_id, recipient_id),
    )
    from_after = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    to_after = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (recipient_id,),
    )["balance"]))
    require(
        transfer.status_code == 200
        and from_after == from_before - Decimal("5000.00")
        and to_after == to_before + Decimal("5000.00"),
        "transfer moves balances atomically",
    )

    missing_csrf = customer.post("/logout", data={})
    require(missing_csrf.status_code == 400, "POST without CSRF token is rejected")
    foreign_txn = db.query_one(
        "SELECT transaction_id FROM BANK_TRANSACTION WHERE from_account_id = %s "
        "ORDER BY transaction_id LIMIT 1",
        (recipient_id,),
    )
    assert foreign_txn is not None
    foreign_page = customer.get(
        f"/customer/transactions/{foreign_txn['transaction_id']}"
    )
    require(foreign_page.status_code == 404,
            "customer cannot access another customer's transaction")

    # Create and investigate a manual flag as separate staff roles.
    assert transfer_row is not None
    analyst_login = login(staff, "maya.rao@fraudbank.test", "staff")
    require(analyst_login.status_code == 200, "analyst login succeeds")
    token_page = staff.get("/staff/flags/manual")
    manual_response = staff.post(
        "/staff/flags/manual",
        data={
            "csrf_token": csrf(token_page),
            "reference_number": db.query_one(
                "SELECT reference_number FROM BANK_TRANSACTION WHERE transaction_id = %s",
                (transfer_row["transaction_id"],),
            )["reference_number"],
            "reason": "Smoke test manual review",
            "severity": "MEDIUM",
        },
        follow_redirects=True,
    )
    manual_flag = db.query_one(
        "SELECT flag_id FROM FRAUD_FLAG WHERE transaction_id = %s "
        "AND flag_source = 'MANUAL' ORDER BY flag_id DESC LIMIT 1",
        (transfer_row["transaction_id"],),
    )
    require(manual_flag is not None and manual_response.status_code == 200,
            "analyst creates a manual flag")

    investigator = web_app.app.test_client()
    investigator_login = login(
        investigator, "arjun.kulkarni@fraudbank.test", "staff"
    )
    require(investigator_login.status_code == 200, "investigator login succeeds")
    analyst_update = staff.post(
        "/staff/investigations/1",
        data={"csrf_token": csrf(staff.get("/staff/flags"))},
    )
    require(analyst_update.status_code == 403,
            "analyst cannot resolve an investigation")

    manual_open = investigator.post(
        f"/staff/flags/{manual_flag['flag_id']}/investigate",
        data={"csrf_token": csrf(investigator.get("/staff/flags"))},
        follow_redirects=True,
    )
    investigation = db.query_one(
        "SELECT investigation_id FROM INVESTIGATION WHERE flag_id = %s "
        "ORDER BY investigation_id DESC LIMIT 1",
        (manual_flag["flag_id"],),
    )
    require(investigation is not None and manual_open.status_code == 200,
            "investigator opens a case")
    investigation_id = int(investigation["investigation_id"])

    detail = investigator.get(f"/staff/investigations/{investigation_id}")
    invalid_resolution = investigator.post(
        f"/staff/investigations/{investigation_id}",
        data={
            "csrf_token": csrf(detail),
            "investigation_status": "RESOLVED",
            "outcome": "",
            "findings": "",
        },
    )
    require(
        invalid_resolution.status_code == 200
        and b"outcome is required" in invalid_resolution.data.lower(),
        "resolution without outcome is rejected with a friendly validation message",
    )
    detail = investigator.get(f"/staff/investigations/{investigation_id}")
    resolved = investigator.post(
        f"/staff/investigations/{investigation_id}",
        data={
            "csrf_token": csrf(detail),
            "investigation_status": "RESOLVED",
            "outcome": "LEGITIMATE",
            "findings": "Smoke-tested legitimate outcome.",
        },
        follow_redirects=True,
    )
    completed = db.query_one(
        "SELECT transaction_status FROM BANK_TRANSACTION WHERE transaction_id = %s",
        (transfer_row["transaction_id"],),
    )
    flag_state = db.query_one(
        "SELECT flag_status FROM FRAUD_FLAG WHERE flag_id = %s",
        (manual_flag["flag_id"],),
    )
    require(
        resolved.status_code == 200
        and completed["transaction_status"] == "COMPLETED"
        and flag_state["flag_status"] == "FALSE_POSITIVE",
        "legitimate resolution closes the flag and returns a clear transaction to completed",
    )

    # High amount transfer is flagged by R01, confirmed, and reversed.
    sender_before_reverse = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    receiver_before_reverse = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1014'"
    )["balance"]))
    make_transaction(customer, "TRANSFER", "60000.00", "ACC1014")
    high_txn = db.query_one(
        "SELECT transaction_id, transaction_status FROM BANK_TRANSACTION "
        "WHERE from_account_id = %s AND to_account_id = "
        "(SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1014') "
        "ORDER BY transaction_id DESC LIMIT 1",
        (account_id,),
    )
    assert high_txn
    high_flag = db.query_one(
        "SELECT flag_id FROM FRAUD_FLAG WHERE transaction_id = %s AND rule_id = 'R01'",
        (high_txn["transaction_id"],),
    )
    require(
        high_flag is not None and high_txn["transaction_status"] == "UNDER_REVIEW",
        "60000 transfer creates R01 flag and places transaction under review",
    )
    require(
        db.query_one(
            "SELECT audit_id FROM TRANSACTION_AUDIT WHERE transaction_id = %s "
            "AND action_type = 'FLAG_CREATED'",
            (high_txn["transaction_id"],),
        )
        is not None
        and db.query_one(
            "SELECT audit_id FROM TRANSACTION_AUDIT WHERE transaction_id = %s "
            "AND action_type = 'STATUS_CHANGED'",
            (high_txn["transaction_id"],),
        )
        is not None,
        "flag and transaction status changes create audit records",
    )
    high_open = investigator.post(
        f"/staff/flags/{high_flag['flag_id']}/investigate",
        data={"csrf_token": csrf(investigator.get("/staff/flags"))},
    )
    high_investigation = db.query_one(
        "SELECT investigation_id FROM INVESTIGATION WHERE flag_id = %s "
        "ORDER BY investigation_id DESC LIMIT 1",
        (high_flag["flag_id"],),
    )
    require(high_open.status_code == 302 and high_investigation is not None,
            "investigator opens R01 case")
    detail = investigator.get(
        f"/staff/investigations/{high_investigation['investigation_id']}"
    )
    investigator.post(
        f"/staff/investigations/{high_investigation['investigation_id']}",
        data={
            "csrf_token": csrf(detail),
            "investigation_status": "RESOLVED",
            "outcome": "CONFIRMED_FRAUD",
            "findings": "Smoke-tested confirmed fraud outcome.",
        },
    )
    reverse_page = investigator.get(
        f"/staff/investigations/{high_investigation['investigation_id']}"
    )
    reversed_response = investigator.post(
        f"/staff/transactions/{high_txn['transaction_id']}/reverse",
        data={"csrf_token": csrf(reverse_page)},
        follow_redirects=True,
    )
    sender_after_reverse = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s",
        (account_id,),
    )["balance"]))
    receiver_after_reverse = Decimal(str(db.query_one(
        "SELECT balance FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1014'"
    )["balance"]))
    reversed_txn = db.query_one(
        "SELECT transaction_status FROM BANK_TRANSACTION WHERE transaction_id = %s",
        (high_txn["transaction_id"],),
    )
    require(
        reversed_response.status_code == 200
        and reversed_txn["transaction_status"] == "REVERSED"
        and sender_after_reverse == sender_before_reverse
        and receiver_after_reverse == receiver_before_reverse,
        "confirmed fraud reversal restores both balances",
    )

    verify_constraints(int(high_txn["transaction_id"]), int(high_flag["flag_id"]))

    manager = web_app.app.test_client()
    manager_login = login(manager, "rahul.verma@fraudbank.test", "staff")
    require(manager_login.status_code == 200, "manager login succeeds")
    page = manager.get("/staff/weekly-analysis")
    weekly = manager.post(
        "/staff/weekly-analysis",
        data={"csrf_token": csrf(page)},
        follow_redirects=True,
    )
    require(weekly.status_code == 200, "weekly analysis procedure runs")

    for rule_id in ("R01", "R02", "R03", "R04", "R05", "R06", "R07"):
        count = db.query_one(
            "SELECT COUNT(*) AS total FROM FRAUD_FLAG WHERE rule_id = %s",
            (rule_id,),
        )
        require(int(count["total"]) >= 1, f"seed data includes scenario {rule_id}")

    require(deposit.status_code == 200, "deposit result page renders")
    print("Smoke test completed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
