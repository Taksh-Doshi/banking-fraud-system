from __future__ import annotations

import hmac
import logging
import os
import re
import secrets
from decimal import Decimal, InvalidOperation
from functools import wraps
from pathlib import Path
from typing import Any, Callable, TypeVar
from urllib.parse import urlsplit

from dotenv import load_dotenv
from flask import (
    Flask,
    abort,
    flash,
    g,
    jsonify,
    redirect,
    render_template,
    request,
    session,
    url_for,
)
from werkzeug.security import check_password_hash, generate_password_hash

import audit
import db
import fraud_rules


ROOT = Path(__file__).resolve().parent
load_dotenv(ROOT / ".env")
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
secret_key = os.getenv("SECRET_KEY") or os.getenv("FLASK_SECRET_KEY")
if not secret_key:
    raise RuntimeError("Set SECRET_KEY in .env before starting the application.")
app.config.update(
    SECRET_KEY=secret_key,
    SESSION_COOKIE_HTTPONLY=True,
    SESSION_COOKIE_SAMESITE="Lax",
    SESSION_COOKIE_SECURE=os.getenv("COOKIE_SECURE", "false").lower() == "true",
)

F = TypeVar("F", bound=Callable[..., Any])
STAFF_ROLES = {"ANALYST", "INVESTIGATOR", "MANAGER", "ADMIN"}
MANAGERS = {"MANAGER", "ADMIN"}
OUTCOMES = {"CONFIRMED_FRAUD", "LEGITIMATE", "INCONCLUSIVE"}


def _csrf_token() -> str:
    token = session.get("_csrf_token")
    if token is None:
        token = secrets.token_urlsafe(32)
        session["_csrf_token"] = token
    return token


@app.before_request
def enforce_csrf() -> None:
    if request.method == "POST":
        supplied = request.form.get("csrf_token", "")
        expected = session.get("_csrf_token", "")
        if not supplied or not expected or not hmac.compare_digest(supplied, expected):
            abort(400, description="The form expired. Reload the page and try again.")


@app.before_request
def load_session_user() -> None:
    role = session.get("role")
    if role == "CUSTOMER" and session.get("customer_id"):
        user = db.query_one(
            "SELECT customer_account_id, customer_id, full_name, email, phone, "
            "address, password_hash, account_number, account_type, balance, account_status "
            "FROM CUSTOMER_ACCOUNT WHERE customer_account_id = %s "
            "AND customer_id = %s",
            (session.get("active_account_id"), session["customer_id"]),
        )
        if user is None or user["account_status"] == "CLOSED":
            session.clear()
            return
        g.user = user
        g.switcher_accounts = db.query_all(
            "SELECT customer_account_id, account_number, account_type "
            "FROM CUSTOMER_ACCOUNT WHERE customer_id = %s "
            "AND account_status <> 'CLOSED' ORDER BY account_number",
            (session["customer_id"],),
        )
    elif role == "STAFF" and session.get("staff_id"):
        user = db.query_one(
            "SELECT staff_id, staff_name, email, role, staff_status "
            "FROM STAFF WHERE staff_id = %s",
            (session["staff_id"],),
        )
        if user is None or user["staff_status"] != "ACTIVE":
            session.clear()
            return
        g.user = user
    if not hasattr(g, "switcher_accounts"):
        g.switcher_accounts = []


@app.context_processor
def inject_template_context() -> dict[str, Any]:
    return {
        "csrf_token": _csrf_token,
        "current_user": getattr(g, "user", None),
        "current_role": session.get("role"),
        "switcher_accounts": getattr(g, "switcher_accounts", []),
    }


def _safe_next(value: str | None) -> str | None:
    if not value:
        return None
    target = urlsplit(value)
    if target.scheme or target.netloc or not value.startswith("/") or value.startswith("//"):
        return None
    return value


def _format_inr(value: Any) -> str:
    try:
        amount = Decimal(str(value or 0)).quantize(Decimal("0.01"))
    except (InvalidOperation, ValueError):
        amount = Decimal("0.00")
    sign = "-" if amount < 0 else ""
    whole, fraction = f"{abs(amount):.2f}".split(".")
    if len(whole) > 3:
        last_three = whole[-3:]
        preceding = whole[:-3]
        groups = []
        while preceding:
            groups.append(preceding[-2:])
            preceding = preceding[:-2]
        whole = ",".join(reversed(groups)) + "," + last_three
    return f"{sign}₹{whole}.{fraction}"


app.jinja_env.filters["inr"] = _format_inr


def customer_required(view: F) -> F:
    @wraps(view)
    def wrapped(*args: Any, **kwargs: Any) -> Any:
        if session.get("role") != "CUSTOMER" or getattr(g, "user", None) is None:
            return redirect(url_for("login", next=request.full_path))
        return view(*args, **kwargs)

    return wrapped  # type: ignore[return-value]


def staff_required(*roles: str) -> Callable[[F], F]:
    allowed = set(roles) if roles else STAFF_ROLES

    def decorator(view: F) -> F:
        @wraps(view)
        def wrapped(*args: Any, **kwargs: Any) -> Any:
            if session.get("role") != "STAFF" or getattr(g, "user", None) is None:
                return redirect(url_for("login", role="staff", next=request.full_path))
            if g.user["role"] not in STAFF_ROLES or g.user["role"] not in allowed:
                abort(403)
            return view(*args, **kwargs)

        return wrapped  # type: ignore[return-value]

    return decorator


def _page(title: str, rows: list[dict[str, Any]], page: int, page_size: int) -> dict[str, Any]:
    total = rows[0]["total_rows"] if rows else 0
    return {
        "rows": rows,
        "page": page,
        "page_size": page_size,
        "total": total,
        "pages": max(1, (total + page_size - 1) // page_size),
    }


def _valid_amount(raw: str) -> Decimal:
    try:
        amount = Decimal(raw)
    except (InvalidOperation, ValueError):
        raise ValueError("Enter a valid amount.") from None
    if (
        not amount.is_finite()
        or amount <= 0
        or amount > Decimal("9999999999999.99")
        or amount.as_tuple().exponent < -2
    ):
        raise ValueError(
            "Enter an amount within the supported range and with no more than two decimal places."
        )
    return amount


def _owns_transaction(transaction_id: int) -> dict[str, Any] | None:
    return db.query_one(
        "SELECT h.* FROM v_transaction_history h "
        "JOIN CUSTOMER_ACCOUNT a ON a.customer_account_id = %s "
        "WHERE h.transaction_id = %s "
        "AND (h.from_account_id = a.customer_account_id "
        "OR h.to_account_id = a.customer_account_id)",
        (g.user["customer_account_id"], transaction_id),
    )


@app.route("/")
def index() -> str:
    return render_template("index.html")


@app.route("/login", methods=["GET", "POST"])
def login() -> Any:
    role_hint = request.args.get("role", request.form.get("role", "customer"))
    next_url = _safe_next(request.args.get("next") or request.form.get("next"))
    if request.method == "POST":
        identifier = request.form.get("identifier", "").strip()
        password = request.form.get("password", "")
        if role_hint == "staff":
            user = db.query_one(
                "SELECT staff_id, staff_name, email, role, staff_status, password_hash "
                "FROM STAFF WHERE email = %s",
                (identifier,),
            )
            if (
                user
                and user["staff_status"] == "ACTIVE"
                and check_password_hash(user["password_hash"], password)
            ):
                session.clear()
                session["role"] = "STAFF"
                session["staff_id"] = user["staff_id"]
                session["staff_role"] = user["role"]
                flash("Welcome back.", "success")
                return redirect(next_url or url_for("staff_dashboard"))
        else:
            accounts = db.query_all(
                "SELECT customer_account_id, customer_id, full_name, account_status, "
                "password_hash FROM CUSTOMER_ACCOUNT WHERE customer_id = %s",
                (identifier,),
            )
            active_accounts = [
                account for account in accounts if account["account_status"] != "CLOSED"
            ]
            if active_accounts and check_password_hash(
                active_accounts[0]["password_hash"], password
            ):
                session.clear()
                session["role"] = "CUSTOMER"
                session["customer_id"] = identifier
                session["account_ids"] = [
                    account["customer_account_id"] for account in active_accounts
                ]
                session["active_account_id"] = active_accounts[0]["customer_account_id"]
                flash("Welcome back.", "success")
                return redirect(next_url or url_for("customer_dashboard"))
        flash("The supplied credentials could not be verified.", "error")
    return render_template("login.html", role_hint=role_hint, next_url=next_url or "")


@app.post("/logout")
def logout() -> Any:
    session.clear()
    flash("You have been signed out.", "success")
    return redirect(url_for("index"))


@app.post("/account/switch")
@customer_required
def switch_account() -> Any:
    account_id = request.form.get("account_id", type=int)
    account = db.query_one(
        "SELECT customer_account_id FROM CUSTOMER_ACCOUNT "
        "WHERE customer_account_id = %s AND customer_id = %s "
        "AND account_status <> 'CLOSED'",
        (account_id, session["customer_id"]),
    )
    if account is None:
        abort(403)
    session["active_account_id"] = account_id
    return redirect(request.referrer or url_for("customer_dashboard"))


@app.get("/customer")
@customer_required
def customer_dashboard() -> str:
    account_id = g.user["customer_account_id"]
    recent = db.query_all(
        "SELECT * FROM v_transaction_history "
        "WHERE from_account_id = %s OR to_account_id = %s "
        "ORDER BY transaction_time DESC LIMIT 5",
        (account_id, account_id),
    )
    totals = db.query_one(
        "SELECT COALESCE(SUM(CASE WHEN to_account_id = %s THEN amount ELSE 0 END),0) "
        "AS money_in, COALESCE(SUM(CASE WHEN from_account_id = %s THEN amount ELSE 0 END),0) "
        "AS money_out FROM BANK_TRANSACTION WHERE transaction_time >= NOW() - INTERVAL 30 DAY "
        "AND transaction_status <> 'FAILED' AND (from_account_id = %s OR to_account_id = %s)",
        (account_id, account_id, account_id, account_id),
    )
    accounts = db.query_all(
        "SELECT customer_account_id, account_number, account_type, balance, account_status "
        "FROM CUSTOMER_ACCOUNT WHERE customer_id = %s AND account_status <> 'CLOSED' "
        "ORDER BY customer_account_id",
        (session["customer_id"],),
    )
    return render_template(
        "customer_dashboard.html", recent=recent, totals=totals, accounts=accounts
    )


@app.route("/customer/transactions/new", methods=["GET", "POST"])
@customer_required
def new_transaction() -> Any:
    account_id = g.user["customer_account_id"]
    if request.method == "POST":
        txn_type = request.form.get("transaction_type", "").upper()
        recipient = request.form.get("recipient", "").strip()
        try:
            amount = _valid_amount(request.form.get("amount", ""))
            if txn_type not in {"DEPOSIT", "WITHDRAWAL", "TRANSFER"}:
                raise ValueError("Select a valid transaction type.")
            to_id = account_id if txn_type == "DEPOSIT" else None
            from_id = account_id if txn_type in {"WITHDRAWAL", "TRANSFER"} else None
            if txn_type == "TRANSFER":
                target = db.query_one(
                    "SELECT customer_account_id FROM CUSTOMER_ACCOUNT "
                    "WHERE account_number = %s AND account_status = 'ACTIVE'",
                    (recipient,),
                )
                if target is None:
                    raise ValueError("No active destination account matches that number.")
                to_id = target["customer_account_id"]
            result = fraud_rules.make_transaction(
                txn_type, from_id, to_id, amount
            )
            flash(result["message"], "success" if result["result"] != "FAILED" else "error")
            return redirect(url_for("transaction_detail", transaction_id=result["transaction_id"]))
        except ValueError as error:
            flash(str(error), "error")
        except Exception:
            logger.exception("Customer transaction failed")
            flash("The transaction could not be processed. Please try again.", "error")
    return render_template("transaction_form.html")


@app.get("/customer/transactions")
@customer_required
def transaction_history() -> str:
    account_id = g.user["customer_account_id"]
    page = max(request.args.get("page", 1, type=int), 1)
    page_size = 20
    clauses = ["(from_account_id = %s OR to_account_id = %s)"]
    params: list[Any] = [account_id, account_id]
    for key, column in (
        ("type", "transaction_type"),
        ("status", "transaction_status"),
    ):
        value = request.args.get(key, "").strip().upper()
        if value:
            clauses.append(column + " = %s")
            params.append(value)
    for key, operator in (("from", ">="), ("to", "<=")):
        value = request.args.get(key, "").strip()
        if value:
            if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
                flash("Use YYYY-MM-DD for date filters.", "error")
            else:
                clauses.append("DATE(transaction_time) " + operator + " %s")
                params.append(value)
    where = " AND ".join(clauses)
    count = db.query_one(
        "SELECT COUNT(*) AS total FROM v_transaction_history WHERE " + where, params
    )
    rows = db.query_all(
        "SELECT * FROM v_transaction_history WHERE " + where +
        " ORDER BY transaction_time DESC LIMIT %s OFFSET %s",
        (*params, page_size, (page - 1) * page_size),
    )
    return render_template(
        "transaction_history.html",
        transactions=rows,
        page=page,
        pages=max(1, (count["total"] + page_size - 1) // page_size),
        filters=request.args,
    )


@app.get("/customer/transactions/<int:transaction_id>")
@customer_required
def transaction_detail(transaction_id: int) -> Any:
    transaction = _owns_transaction(transaction_id)
    if transaction is None:
        abort(404)
    return render_template("transaction_detail.html", transaction=transaction)


@app.route("/customer/settings", methods=["GET", "POST"])
@customer_required
def customer_settings() -> Any:
    if request.method == "POST":
        action = request.form.get("action", "profile")
        if action == "profile":
            db.execute(
                "UPDATE CUSTOMER_ACCOUNT SET email = %s, phone = %s, address = %s "
                "WHERE customer_id = %s",
                (
                    request.form.get("email", "").strip() or None,
                    request.form.get("phone", "").strip() or None,
                    request.form.get("address", "").strip() or None,
                    session["customer_id"],
                ),
            )
            flash("Your profile was updated.", "success")
        else:
            current = request.form.get("current_password", "")
            new_password = request.form.get("new_password", "")
            if not check_password_hash(g.user["password_hash"], current):
                flash("Current password is incorrect.", "error")
            elif len(new_password) < 10:
                flash("Choose a password with at least 10 characters.", "error")
            else:
                hashed = generate_password_hash(new_password)
                db.execute(
                    "UPDATE CUSTOMER_ACCOUNT SET password_hash = %s WHERE customer_id = %s",
                    (hashed, session["customer_id"]),
                )
                flash("Your password was changed.", "success")
        return redirect(url_for("customer_settings"))
    return render_template("settings.html")


@app.get("/staff")
@staff_required()
def staff_dashboard() -> str:
    metrics = db.query_one(
        "SELECT "
        "(SELECT COUNT(*) FROM FRAUD_FLAG WHERE flag_status = 'OPEN' AND severity = 'CRITICAL') AS critical_flags, "
        "(SELECT COUNT(*) FROM FRAUD_FLAG WHERE flag_status = 'OPEN' AND severity = 'HIGH') AS high_flags, "
        "(SELECT COUNT(*) FROM FRAUD_FLAG WHERE flag_status = 'OPEN' AND severity = 'MEDIUM') AS medium_flags, "
        "(SELECT COUNT(*) FROM FRAUD_FLAG WHERE flag_status = 'OPEN' AND severity = 'LOW') AS low_flags, "
        "(SELECT COUNT(*) FROM BANK_TRANSACTION WHERE transaction_status = 'UNDER_REVIEW') AS under_review, "
        "(SELECT COUNT(*) FROM INVESTIGATION WHERE investigation_status IN ('OPEN','IN_PROGRESS')) AS open_investigations, "
        "(SELECT COUNT(*) FROM BANK_TRANSACTION WHERE DATE(transaction_time) = CURRENT_DATE()) AS todays_transactions"
    )
    latest = db.query_all(
        "SELECT * FROM v_flag_detail ORDER BY flagged_at DESC LIMIT 8"
    )
    return render_template("staff_dashboard.html", metrics=metrics, flags=latest)


@app.get("/staff/flags")
@staff_required()
def staff_flags() -> str:
    filters = {
        key: request.args.get(key, "").strip()
        for key in ("status", "severity", "source")
    }
    where, params = [], []
    for key, column in (
        ("status", "flag_status"),
        ("severity", "severity"),
        ("source", "flag_source"),
    ):
        if filters[key]:
            where.append(column + " = %s")
            params.append(filters[key].upper())
    if request.args.get("q", "").strip():
        search = f"%{request.args['q'].strip()}%"
        where.append("(reference_number LIKE %s OR rule_name LIKE %s OR reason LIKE %s)")
        params.extend((search, search, search))
    clause = " WHERE " + " AND ".join(where) if where else ""
    page = max(request.args.get("page", 1, type=int), 1)
    page_size = 20
    count = db.query_one(
        "SELECT COUNT(*) AS total FROM v_flag_detail" + clause, params
    )
    flags = db.query_all(
        "SELECT * FROM v_flag_detail" + clause + " ORDER BY flagged_at DESC "
        "LIMIT %s OFFSET %s",
        (*params, page_size, (page - 1) * page_size),
    )
    return render_template(
        "fraud_flags.html",
        flags=flags,
        filters=filters,
        query=request.args.get("q", ""),
        page=page,
        pages=max(1, (count["total"] + page_size - 1) // page_size),
    )


@app.get("/staff/flags/<int:flag_id>")
@staff_required()
def staff_flag_detail(flag_id: int) -> Any:
    flag = db.query_one("SELECT * FROM v_flag_detail WHERE flag_id = %s", (flag_id,))
    if flag is None:
        abort(404)
    account_id = flag["from_account_id"] or flag["to_account_id"]
    recent = db.query_all(
        "SELECT * FROM v_transaction_history WHERE from_account_id = %s OR to_account_id = %s "
        "ORDER BY transaction_time DESC LIMIT 10",
        (account_id, account_id),
    )
    investigations = db.query_all(
        "SELECT i.*, s.staff_name FROM INVESTIGATION i "
        "LEFT JOIN STAFF s ON s.staff_id = i.assigned_staff_id "
        "WHERE flag_id = %s ORDER BY opened_at DESC",
        (flag_id,),
    )
    investigators = db.query_all(
        "SELECT staff_id, staff_name FROM STAFF WHERE staff_status = 'ACTIVE' "
        "ORDER BY staff_name"
    )
    return render_template(
        "flag_detail.html",
        flag=flag,
        recent=recent,
        investigations=investigations,
        investigators=investigators,
    )


@app.route("/staff/flags/manual", methods=["GET", "POST"])
@staff_required("ANALYST", "MANAGER", "ADMIN")
def create_manual_flag() -> Any:
    if request.method == "POST":
        reference = request.form.get("reference_number", "").strip()
        reason = request.form.get("reason", "").strip()
        severity = request.form.get("severity", "").upper()
        txn = db.query_one(
            "SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = %s",
            (reference,),
        )
        if txn is None:
            flash("No transaction matches that reference number.", "error")
        elif not reason or severity not in {"LOW", "MEDIUM", "HIGH", "CRITICAL"}:
            flash("Enter a reason and choose a valid severity.", "error")
        else:
            db.execute(
                "INSERT INTO FRAUD_FLAG "
                "(transaction_id, rule_id, rule_name, rule_description, rule_type, "
                "flag_source, reason, severity, created_by_staff_id) "
                "VALUES (%s, NULL, 'MANUAL_REVIEW', 'Manually created staff review.', "
                "'MANUAL', 'MANUAL', %s, %s, %s)",
                (txn["transaction_id"], reason, severity, g.user["staff_id"]),
                staff_id=g.user["staff_id"],
            )
            flash("Manual fraud flag created.", "success")
            return redirect(url_for("staff_flags"))
    return render_template("manual_flag.html")


@app.post("/staff/flags/<int:flag_id>/investigate")
@staff_required("INVESTIGATOR", "MANAGER", "ADMIN")
def open_investigation(flag_id: int) -> Any:
    flag = db.query_one("SELECT flag_id FROM FRAUD_FLAG WHERE flag_id = %s", (flag_id,))
    if flag is None:
        abort(404)
    assigned = g.user["staff_id"]
    case = db.query_one(
        "SELECT investigation_id, assigned_staff_id FROM INVESTIGATION "
        "WHERE flag_id = %s AND investigation_status IN ('OPEN','IN_PROGRESS') "
        "AND (assigned_staff_id = %s OR assigned_staff_id IS NULL) "
        "ORDER BY (assigned_staff_id = %s) DESC, opened_at LIMIT 1",
        (flag_id, assigned, assigned),
    )
    if case and case["assigned_staff_id"] is None:
        db.execute(
            "UPDATE INVESTIGATION SET assigned_staff_id = %s, "
            "investigation_status = 'IN_PROGRESS' WHERE investigation_id = %s",
            (assigned, case["investigation_id"]),
            staff_id=assigned,
        )
        investigation_id = case["investigation_id"]
    elif case:
        investigation_id = case["investigation_id"]
    else:
        investigation_id, _ = db.execute(
            "INSERT INTO INVESTIGATION "
            "(flag_id, assigned_staff_id, investigation_status) "
            "VALUES (%s, %s, 'IN_PROGRESS')",
            (flag_id, assigned),
            staff_id=assigned,
        )
    flash("Investigation opened and assigned to you.", "success")
    return redirect(
        url_for("investigation_detail", investigation_id=investigation_id)
    )


@app.get("/staff/investigations")
@staff_required()
def staff_investigations() -> str:
    params: list[Any] = []
    where = ""
    if g.user["role"] == "INVESTIGATOR":
        where = "WHERE i.assigned_staff_id = %s OR i.assigned_staff_id IS NULL"
        params.append(g.user["staff_id"])
    investigations = db.query_all(
        "SELECT i.*, f.rule_name, f.severity, t.reference_number, t.amount, "
        "s.staff_name FROM INVESTIGATION i "
        "JOIN FRAUD_FLAG f ON f.flag_id = i.flag_id "
        "JOIN BANK_TRANSACTION t ON t.transaction_id = f.transaction_id "
        "LEFT JOIN STAFF s ON s.staff_id = i.assigned_staff_id "
        + where
        + " ORDER BY i.opened_at DESC",
        params,
    )
    return render_template("investigations.html", investigations=investigations)


@app.route("/staff/investigations/<int:investigation_id>", methods=["GET", "POST"])
@staff_required()
def investigation_detail(investigation_id: int) -> Any:
    investigation = db.query_one(
        "SELECT i.*, f.rule_name, f.severity, f.flag_status, f.transaction_id, "
        "t.reference_number, t.amount, t.transaction_status, "
        "t.from_account_id, t.to_account_id, s.staff_name "
        "FROM INVESTIGATION i JOIN FRAUD_FLAG f ON f.flag_id = i.flag_id "
        "JOIN BANK_TRANSACTION t ON t.transaction_id = f.transaction_id "
        "LEFT JOIN STAFF s ON s.staff_id = i.assigned_staff_id "
        "WHERE i.investigation_id = %s",
        (investigation_id,),
    )
    if investigation is None:
        abort(404)
    if request.method == "POST" and g.user["role"] not in (
        "INVESTIGATOR",
        "MANAGER",
        "ADMIN",
    ):
        abort(403)
    is_manager = g.user["role"] in MANAGERS
    is_owner = investigation["assigned_staff_id"] == g.user["staff_id"]
    if g.user["role"] == "INVESTIGATOR" and not (
        is_owner or investigation["assigned_staff_id"] is None
    ):
        abort(403)
    investigators = db.query_all(
        "SELECT staff_id, staff_name FROM STAFF WHERE staff_status = 'ACTIVE' "
        "ORDER BY staff_name"
    )
    if request.method == "POST":
        status = request.form.get("investigation_status", "").upper()
        outcome = request.form.get("outcome", "").upper() or None
        assignee = request.form.get("assigned_staff_id", type=int)
        if status not in {"OPEN", "IN_PROGRESS", "RESOLVED", "CLOSED"}:
            flash("Choose a valid investigation status.", "error")
        elif outcome is not None and outcome not in OUTCOMES:
            flash("Choose a valid investigation outcome.", "error")
        elif status in {"RESOLVED", "CLOSED"} and not outcome:
            flash("An outcome is required before resolving or closing a case.", "error")
        elif not is_manager and assignee not in (None, g.user["staff_id"]):
            abort(403)
        else:
            selected_assignee = (
                assignee if is_manager else g.user["staff_id"]
            )
            db.execute(
                "UPDATE INVESTIGATION SET investigation_status = %s, findings = %s, "
                "outcome = %s, assigned_staff_id = %s, "
                "resolved_at = CASE WHEN %s IN ('RESOLVED', 'CLOSED') "
                "THEN COALESCE(resolved_at, NOW()) ELSE NULL END "
                "WHERE investigation_id = %s",
                (
                    status,
                    request.form.get("findings", "").strip() or None,
                    outcome,
                    selected_assignee,
                    status,
                    investigation_id,
                ),
                staff_id=g.user["staff_id"],
            )
            flash("Investigation updated.", "success")
            return redirect(url_for("investigation_detail", investigation_id=investigation_id))
    return render_template(
        "investigation_detail.html",
        investigation=investigation,
        investigators=investigators,
        is_manager=is_manager,
    )


@app.post("/staff/transactions/<int:transaction_id>/reverse")
@staff_required("INVESTIGATOR", "MANAGER", "ADMIN")
def reverse_transaction(transaction_id: int) -> Any:
    flag = db.query_one(
        "SELECT flag_id FROM FRAUD_FLAG WHERE transaction_id = %s "
        "ORDER BY flagged_at DESC LIMIT 1",
        (transaction_id,),
    )
    result = fraud_rules.reverse_transaction(transaction_id, g.user["staff_id"])
    flash(result["message"], "success" if result["result"] != "FAILED" else "error")
    if request.referrer:
        return redirect(request.referrer)
    if flag:
        return redirect(url_for("staff_flag_detail", flag_id=flag["flag_id"]))
    return redirect(url_for("staff_dashboard"))


@app.get("/staff/audit")
@staff_required()
def staff_audit() -> str:
    filters = {
        key: request.args.get(key, "").strip()
        for key in ("reference", "staff", "action", "from", "to")
    }
    page = max(request.args.get("page", 1, type=int), 1)
    result = audit.search(filters, page=page, page_size=20)
    return render_template("audit_log.html", **result, filters=filters)


@app.get("/staff/customers")
@staff_required()
def staff_customers() -> str:
    query = request.args.get("q", "").strip()
    like = f"%{query}%"
    customers = db.query_all(
        "SELECT customer_id, full_name, COUNT(*) AS account_count, "
        "SUM(account_status = 'FROZEN') AS frozen_accounts, "
        "GROUP_CONCAT(account_number ORDER BY account_number SEPARATOR ', ') AS accounts "
        "FROM CUSTOMER_ACCOUNT WHERE customer_id LIKE %s OR full_name LIKE %s "
        "GROUP BY customer_id, full_name ORDER BY full_name",
        (like, like),
    )
    return render_template("customers.html", customers=customers, query=query)


@app.get("/staff/customers/<customer_id>")
@staff_required()
def staff_customer_detail(customer_id: str) -> Any:
    accounts = db.query_all(
        "SELECT * FROM CUSTOMER_ACCOUNT WHERE customer_id = %s ORDER BY account_number",
        (customer_id,),
    )
    if not accounts:
        abort(404)
    account_ids = [account["customer_account_id"] for account in accounts]
    placeholders = ",".join(["%s"] * len(account_ids))
    activity = db.query_all(
        "SELECT * FROM v_transaction_history WHERE from_account_id IN "
        "(" + placeholders + ") OR to_account_id IN (" + placeholders + ") "
        "ORDER BY transaction_time DESC LIMIT 30",
        (*account_ids, *account_ids),
    )
    flags = db.query_all(
        "SELECT DISTINCT f.*, t.reference_number FROM FRAUD_FLAG f "
        "JOIN BANK_TRANSACTION t ON t.transaction_id = f.transaction_id "
        "WHERE t.from_account_id IN (" + placeholders + ") "
        "OR t.to_account_id IN (" + placeholders + ") "
        "ORDER BY f.flagged_at DESC LIMIT 30",
        (*account_ids, *account_ids),
    )
    return render_template(
        "customer_detail.html",
        customer=accounts[0],
        accounts=accounts,
        activity=activity,
        flags=flags,
        can_manage=g.user["role"] in MANAGERS,
    )


@app.post("/staff/accounts/<int:account_id>/status")
@staff_required("MANAGER", "ADMIN")
def set_account_status(account_id: int) -> Any:
    status = request.form.get("status", "").upper()
    if status not in {"ACTIVE", "FROZEN"}:
        abort(400)
    db.execute(
        "UPDATE CUSTOMER_ACCOUNT SET account_status = %s WHERE customer_account_id = %s",
        (status, account_id),
        staff_id=g.user["staff_id"],
    )
    flash(f"Account status changed to {status.lower()}.", "success")
    return redirect(request.referrer or url_for("staff_customers"))


def _load_report_definitions() -> list[dict[str, str]]:
    content = (ROOT / "sql" / "reports.sql").read_text(encoding="utf-8")
    matches = re.findall(
        r"(?m)^-- REPORT:\s*([^|]+)\|\s*([^|]+)\|\s*(.*?)\s*\n(.*?);",
        content,
        re.DOTALL,
    )
    reports = []
    for key, title, description, sql_text in matches:
        query = re.sub(r"(?m)^\s*--.*$", "", sql_text).strip()
        if not query.upper().startswith(("SELECT", "WITH")):
            raise ValueError(f"Report {key.strip()} is not read-only.")
        reports.append(
            {
                "key": key.strip(),
                "title": title.strip(),
                "description": description.strip(),
                "sql": query,
            }
        )
    return reports


@app.get("/staff/reports")
@staff_required()
def staff_reports() -> Any:
    reports = _load_report_definitions()
    selected_key = request.args.get("report", reports[0]["key"] if reports else "")
    selected = next((item for item in reports if item["key"] == selected_key), None)
    rows = db.query_all(selected["sql"]) if selected else []
    return render_template(
        "reports.html", reports=reports, selected=selected, rows=rows
    )


@app.route("/staff/weekly-analysis", methods=["GET", "POST"])
@staff_required("MANAGER", "ADMIN")
def weekly_analysis() -> Any:
    new_flags = None
    if request.method == "POST":
        result = db.call_proc(
            "sp_weekly_analysis", (0,), staff_id=g.user["staff_id"]
        )
        new_flags = result[0]
        flash(f"Weekly analysis complete: {new_flags} new flags.", "success")
    recent_flags = db.query_all(
        "SELECT * FROM v_flag_detail WHERE flagged_at >= NOW() - INTERVAL 10 MINUTE "
        "ORDER BY flagged_at DESC"
    )
    return render_template(
        "weekly_analysis.html", new_flags=new_flags, flags=recent_flags
    )


@app.route("/staff/settings", methods=["GET", "POST"])
@staff_required()
def staff_settings() -> Any:
    if request.method == "POST":
        current = request.form.get("current_password", "")
        new_password = request.form.get("new_password", "")
        record = db.query_one(
            "SELECT password_hash FROM STAFF WHERE staff_id = %s",
            (g.user["staff_id"],),
        )
        if record is None or not check_password_hash(record["password_hash"], current):
            flash("Current password is incorrect.", "error")
        elif len(new_password) < 10:
            flash("Choose a password with at least 10 characters.", "error")
        else:
            db.execute(
                "UPDATE STAFF SET password_hash = %s WHERE staff_id = %s",
                (generate_password_hash(new_password), g.user["staff_id"]),
                staff_id=g.user["staff_id"],
            )
            flash("Your password was changed.", "success")
        return redirect(url_for("staff_settings"))
    return render_template("settings.html", staff_settings=True)


@app.errorhandler(400)
def bad_request(error: Any) -> tuple[str, int]:
    return render_template("error.html", code=400, message=getattr(error, "description", "Bad request")), 400


@app.errorhandler(403)
def forbidden(error: Any) -> tuple[str, int]:
    return render_template("error.html", code=403, message="You do not have permission to view this page."), 403


@app.errorhandler(404)
def not_found(error: Any) -> tuple[str, int]:
    return render_template("error.html", code=404, message="The requested page could not be found."), 404


@app.errorhandler(500)
def server_error(error: Any) -> tuple[str, int]:
    logger.error("Unhandled application error", exc_info=error)
    return render_template("error.html", code=500, message="An unexpected error occurred."), 500


if __name__ == "__main__":
    app.run(
        host=os.getenv("APP_HOST", "127.0.0.1"),
        port=int(os.getenv("APP_PORT", "5000")),
        debug=os.getenv("FLASK_DEBUG", "false").lower() == "true",
    )
