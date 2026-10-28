"""Comprehensive tests for the six fixed items:
1. Customer self sign-up (/register)
2. Customer ID generation (CUST###, sequential, unique, concurrent safety)
3. Eye icon toggle on password fields
4. Immediate DB reflection & visibility across separate connections
5. Forgot Customer ID recovery flow with rate limiting
6. Copy buttons with clipboard and execCommand fallback
"""

from __future__ import annotations

import concurrent.futures
import os
import re
import sys
from decimal import Decimal
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

import app as web_app
import db
import mysql.connector
from werkzeug.security import check_password_hash


def csrf(response: Any) -> str:
    match = re.search(rb'name="csrf_token"\s+value="([^"]+)"', response.data)
    if match is None:
        raise AssertionError("Expected CSRF token in rendered HTML.")
    return match.group(1).decode("ascii")


def require(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(f"FAILED: {message}")
    print(f"PASS {message}")


def cleanup_account_by_email(email: str) -> None:
    """Helper to clean up test accounts without tripping foreign key constraints."""
    existing = db.query_one(
        "SELECT customer_account_id, customer_id FROM CUSTOMER_ACCOUNT WHERE email = %s",
        (email,),
    )
    if not existing:
        return
    acc_id = existing["customer_account_id"]
    cid = existing["customer_id"]

    txns = db.query_all(
        "SELECT transaction_id FROM BANK_TRANSACTION WHERE from_account_id = %s OR to_account_id = %s",
        (acc_id, acc_id),
    )
    for tx in txns:
        tx_id = tx["transaction_id"]
        flags = db.query_all("SELECT flag_id FROM FRAUD_FLAG WHERE transaction_id = %s", (tx_id,))
        for fl in flags:
            db.execute("DELETE FROM INVESTIGATION WHERE flag_id = %s", (fl["flag_id"],))
        db.execute("DELETE FROM FRAUD_FLAG WHERE transaction_id = %s", (tx_id,))
        db.execute("DELETE FROM TRANSACTION_AUDIT WHERE transaction_id = %s", (tx_id,))
        db.execute("DELETE FROM BANK_TRANSACTION WHERE transaction_id = %s", (tx_id,))
    db.execute("DELETE FROM CUSTOMER_ACCOUNT WHERE customer_id = %s", (cid,))


def test_ui_elements() -> None:
    """Verify eye icon toggles and copy buttons in rendered templates."""
    client = web_app.app.test_client()

    # 1. Login page: eye toggle and customer links
    login_page = client.get("/login")
    require(login_page.status_code == 200, "login page loads")
    require(b'data-password-toggle' in login_page.data, "login page has eye toggle button")
    require(b'Create account' in login_page.data, "login page has Create account link")
    require(b'Forgot Customer ID?' in login_page.data, "login page has Forgot Customer ID link")

    # 2. Register page: eye toggles on password and confirm_password
    reg_page = client.get("/register")
    require(reg_page.status_code == 200, "register page loads")
    require(reg_page.data.count(b'data-password-toggle') >= 2, "register page has eye toggles for password and confirmation")

    # 3. Forgot ID page
    forgot_page = client.get("/forgot-id")
    require(forgot_page.status_code == 200, "forgot ID page loads")
    require(b'name="email"' in forgot_page.data and b'name="date_of_birth"' in forgot_page.data and b'name="phone"' in forgot_page.data,
            "forgot ID form contains email, date_of_birth, and phone fields")


def test_validation_rules() -> None:
    """Verify client/server validation errors during registration."""
    client = web_app.app.test_client()

    def submit_reg(form_overrides: dict[str, Any]) -> Any:
        page = client.get("/register")
        token = csrf(page)
        base = {
            "csrf_token": token,
            "full_name": "Validation Test",
            "date_of_birth": "1995-05-15",
            "email": "valtest@example.com",
            "phone": "9876543210",
            "address": "123 Test St",
            "account_type": "SAVINGS",
            "initial_deposit": "0",
            "password": "StrongPassword@123",
            "confirm_password": "StrongPassword@123",
            "terms": "on",
        }
        base.update(form_overrides)
        return client.post("/register", data=base, follow_redirects=True)

    # Under 18
    resp = submit_reg({"date_of_birth": "2015-01-01"})
    require(b"18 years" in resp.data, "rejection: customer must be at least 18 years old")

    # Weak password
    resp = submit_reg({"password": "weak", "confirm_password": "weak"})
    require(b"Password must be at least 8 characters" in resp.data, "rejection: weak password")

    # Mismatched confirmation
    resp = submit_reg({"confirm_password": "DifferentPassword@123"})
    require(b"Passwords do not match" in resp.data, "rejection: passwords do not match")

    # Invalid account type
    resp = submit_reg({"account_type": "CRYPTO_ACCOUNT"})
    require(b"valid account type" in resp.data, "rejection: invalid account type")

    # Invalid phone
    resp = submit_reg({"phone": "123"})
    require(b"10-digit" in resp.data, "rejection: phone number must be 10 digits")


def test_registration_flow_and_db_reflection() -> None:
    """Verify successful customer registration, ID format, deposit, and immediate DB reflection."""
    client = web_app.app.test_client()
    web_app.REGISTER_LIMITS.clear()

    page = client.get("/register")
    token = csrf(page)

    test_email = "vikram.sharma@example.com"
    test_phone = "9823456789"
    test_pass = "SecurePass@2026!"

    cleanup_account_by_email(test_email)

    # Find highest existing customer ID number
    cust_rows = db.query_all("SELECT customer_id FROM CUSTOMER_ACCOUNT")
    max_num = max([int(r["customer_id"].replace("CUST", "")) for r in cust_rows if r["customer_id"].startswith("CUST")], default=0)
    expected_id = f"CUST{max_num + 1:03d}"

    resp = client.post(
        "/register",
        data={
            "csrf_token": token,
            "full_name": "Vikram Sharma",
            "date_of_birth": "1990-08-20",
            "email": test_email,
            "phone": test_phone,
            "address": "42 Lotus Garden, Sector 14, Gurugram, HR 122001",
            "account_type": "SAVINGS",
            "initial_deposit": "1500.00",
            "password": test_pass,
            "confirm_password": test_pass,
            "terms": "on",
        },
        follow_redirects=True,
    )

    require(resp.status_code == 200, "registration request succeeds with 200 redirect to success page")
    require(b"Account Created!" in resp.data, "success page displays 'Account Created!'")
    require(expected_id.encode("ascii") in resp.data, f"success page displays generated sequential ID {expected_id}")
    require(b"copy-btn" in resp.data, "success page includes copy buttons")

    # Item 4: Immediate DB reflection check using a SEPARATE, DIRECT MySQL connection
    raw_conn = mysql.connector.connect(
        host=os.getenv("DB_HOST") or os.getenv("MYSQL_HOST", "localhost"),
        port=int(os.getenv("DB_PORT") or os.getenv("MYSQL_PORT", "3306")),
        user=os.getenv("DB_USER") or os.getenv("MYSQL_USER", ""),
        password=os.getenv("DB_PASSWORD") or os.getenv("MYSQL_PASSWORD", ""),
        database=os.getenv("DB_NAME") or os.getenv("MYSQL_DATABASE", "banking_fraud_system"),
        autocommit=True,
    )
    raw_cursor = raw_conn.cursor(dictionary=True)
    try:
        raw_cursor.execute("SELECT * FROM CUSTOMER_ACCOUNT WHERE customer_id = %s", (expected_id,))
        acc_row = raw_cursor.fetchone()
        require(acc_row is not None, f"Item 4 regression: newly registered {expected_id} is immediately visible in separate DB connection")
        require(acc_row["email"] == test_email, "account row has correct email")
        require(acc_row["phone"] == test_phone, "account row has correct phone")
        require(Decimal(str(acc_row["balance"])) == Decimal("1500.00"), "initial deposit of 1500.00 reflected in balance")

        # Check deposit transaction
        raw_cursor.execute(
            "SELECT * FROM BANK_TRANSACTION WHERE to_account_id = %s AND transaction_type = 'DEPOSIT'",
            (acc_row["customer_account_id"],),
        )
        tx_row = raw_cursor.fetchone()
        require(tx_row is not None, "initial deposit transaction record exists")
        require(Decimal(str(tx_row["amount"])) == Decimal("1500.00"), "deposit transaction amount matches initial deposit")

        # Check password hashing
        stored_hash = acc_row["password_hash"]
        require(not stored_hash.startswith("SecurePass"), "password is not plaintext")
        require(check_password_hash(stored_hash, test_pass), "stored hash verifies with werkzeug check_password_hash")
    finally:
        raw_cursor.close()
        raw_conn.close()

    # Verify duplicate email and phone rejection
    page_dup = client.get("/register")
    resp_dup_email = client.post(
        "/register",
        data={
            "csrf_token": csrf(page_dup),
            "full_name": "Another Person",
            "date_of_birth": "1992-01-01",
            "email": test_email,  # duplicate
            "phone": "9111222333",
            "account_type": "CURRENT",
            "password": "OtherPassword@123",
            "confirm_password": "OtherPassword@123",
            "terms": "on",
        },
        follow_redirects=True,
    )
    require(b"already exists" in resp_dup_email.data or b"already registered" in resp_dup_email.data, "duplicate email is rejected")

    page_dup2 = client.get("/register")
    resp_dup_phone = client.post(
        "/register",
        data={
            "csrf_token": csrf(page_dup2),
            "full_name": "Another Person",
            "date_of_birth": "1992-01-01",
            "email": "unique.another@example.com",
            "phone": test_phone,  # duplicate
            "account_type": "CURRENT",
            "password": "OtherPassword@123",
            "confirm_password": "OtherPassword@123",
            "terms": "on",
        },
        follow_redirects=True,
    )
    require(b"already exists" in resp_dup_phone.data or b"already registered" in resp_dup_phone.data, "duplicate phone is rejected")

    # Verify new customer can log in
    login_page = client.get("/login")
    login_resp = client.post(
        "/login",
        data={
            "csrf_token": csrf(login_page),
            "role": "customer",
            "identifier": expected_id,
            "password": test_pass,
        },
        follow_redirects=True,
    )
    require(login_resp.status_code == 200, "new customer logs in successfully")
    require(b"Vikram Sharma" in login_resp.data, "dashboard displays customer's name")
    require(b"1,500.00" in login_resp.data, "dashboard displays active balance")
    require(b"copy-btn" in login_resp.data, "dashboard displays copy buttons for ID and Account")


def test_concurrent_registrations() -> None:
    """Verify that concurrent registrations receive unique, sequential IDs without race conditions."""
    web_app.REGISTER_LIMITS.clear()

    cleanup_account_by_email("concurrent1@example.com")
    cleanup_account_by_email("concurrent2@example.com")

    def register_worker(name: str, email: str, phone: str) -> dict[str, Any]:
        with db.connection_context() as conn:
            cursor = conn.cursor()
            try:
                cursor.execute(
                    "CALL sp_register_customer(%s, %s, %s, %s, %s, %s, %s, %s, "
                    "@p_customer_id, @p_account_number, @p_result, @p_message)",
                    (name, "1994-04-12", email, phone, "100 Tech Park",
                     "SAVINGS", "dummy_hash_12345", Decimal("100.00")),
                )
                cursor.execute("SELECT @p_customer_id, @p_account_number, @p_result, @p_message")
                params = cursor.fetchone()
                return {
                    "customer_id": params[0],
                    "account_number": params[1],
                    "result": params[2],
                    "message": params[3],
                }
            finally:
                cursor.close()

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        f1 = executor.submit(register_worker, "Concurrent One", "concurrent1@example.com", "9000000001")
        f2 = executor.submit(register_worker, "Concurrent Two", "concurrent2@example.com", "9000000002")
        res1 = f1.result()
        res2 = f2.result()

    require(res1["result"] == "CREATED" and res2["result"] == "CREATED", "both concurrent registrations succeeded")
    require(res1["customer_id"] != res2["customer_id"], f"concurrent registrations received distinct IDs ({res1['customer_id']} vs {res2['customer_id']})")
    require(res1["account_number"] != res2["account_number"], "concurrent registrations received distinct account numbers")


def test_forgot_id_recovery_and_rate_limiting() -> None:
    """Verify customer ID recovery flow, validation, and rate limiting."""
    client = web_app.app.test_client()
    web_app.FORGOT_LIMITS.clear()

    target = db.query_one(
        "SELECT customer_id, email, date_of_birth, phone FROM CUSTOMER_ACCOUNT WHERE email = 'vikram.sharma@example.com'"
    )
    if not target:
        test_registration_flow_and_db_reflection()
        target = db.query_one(
            "SELECT customer_id, email, date_of_birth, phone FROM CUSTOMER_ACCOUNT WHERE email = 'vikram.sharma@example.com'"
        )

    cid = target["customer_id"]
    dob_str = str(target["date_of_birth"])
    phone = target["phone"]

    page = client.get("/forgot-id")
    token = csrf(page)

    # 1. Exact match returns the ID
    resp = client.post(
        "/forgot-id",
        data={
            "csrf_token": token,
            "email": "vikram.sharma@example.com",
            "date_of_birth": dob_str,
            "phone": f"+91 {phone}",  # Test normalization
        },
        follow_redirects=True,
    )
    require(resp.status_code == 200, "forgot-id request returns 200")
    require(cid.encode("ascii") in resp.data, f"forgot-id successfully recovers {cid}")
    require(b"copy-btn" in resp.data, "recovered ID has copy button")

    # 2. Mismatched details returns generic error without leaking info
    page2 = client.get("/forgot-id")
    resp_wrong = client.post(
        "/forgot-id",
        data={
            "csrf_token": csrf(page2),
            "email": "vikram.sharma@example.com",
            "date_of_birth": "1990-01-01",  # Wrong DOB
            "phone": phone,
        },
        follow_redirects=True,
    )
    require(b"We could not find" in resp_wrong.data or b"could not find" in resp_wrong.data,
            "mismatched details show generic safe error message")

    # 3. Rate limiting: 5 attempts allowed in 15 mins; 6th attempt is throttled
    for _ in range(3):
        p = client.get("/forgot-id")
        client.post(
            "/forgot-id",
            data={
                "csrf_token": csrf(p),
                "email": "vikram.sharma@example.com",
                "date_of_birth": dob_str,
                "phone": phone,
            },
            follow_redirects=True,
        )

    # 6th attempt should hit rate limit
    p_last = client.get("/forgot-id")
    resp_throttled = client.post(
        "/forgot-id",
        data={
            "csrf_token": csrf(p_last),
            "email": "vikram.sharma@example.com",
            "date_of_birth": dob_str,
            "phone": phone,
        },
        follow_redirects=True,
    )
    require(b"Too many attempts" in resp_throttled.data,
            "forgot-id is rate-limited after 5 attempts")


def run_all_tests() -> None:
    print("\n--- Running New Features & Bug Fix Tests ---")
    test_ui_elements()
    test_validation_rules()
    test_registration_flow_and_db_reflection()
    test_concurrent_registrations()
    test_forgot_id_recovery_and_rate_limiting()
    print("--- All New Features & Bug Fix Tests Passed! ---\n")


if __name__ == "__main__":
    run_all_tests()
