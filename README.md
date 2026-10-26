# Banking Transaction & Fraud Flag Management System

A database-first demonstration banking application built with Flask, Jinja,
MySQL 8, Connector/Python, and plain CSS/JavaScript. It supports customer
transactions, rule-based fraud flags, investigations, transaction audit, and
database-driven reports. It does not move real money.

## Prerequisites

- Python 3.10 or later.
- MySQL Server 8.0.16 or later (enforced `CHECK` constraints are required).
- A MySQL account allowed to create/use the configured database, tables,
  views, triggers, and stored procedures.

> **Warning:** `sql/schema.sql` drops and recreates all six application tables.
> Run setup only against a disposable development database; it deletes existing
> application data in the configured database.

## Setup

### Windows PowerShell

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements.txt
Copy-Item .env.example .env
# Edit .env with your local MySQL credentials and a long random SECRET_KEY.
python setup_db.py
python app.py
```

If PowerShell prevents script activation, use Command Prompt and
`.\.venv\Scripts\activate.bat`.

### macOS / Linux

```sh
python3 -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements.txt
cp .env.example .env
# Edit .env with your local MySQL credentials and a long random SECRET_KEY.
python setup_db.py
python app.py
```

Set `SECRET_KEY`, `DB_HOST`, `DB_PORT`, `DB_USER`, `DB_PASSWORD`, and `DB_NAME`
in `.env`. The database user must have permission to create the configured
database. To rebuild the schema and stored logic without loading demo data, run
`python setup_db.py --no-sample`. Never commit `.env`.

Open the local address printed by Flask (by default
`http://127.0.0.1:5000/`). For database-backed workflow validation after setup,
run:

```sh
python scripts/smoke_test.py
```

## Demo credentials

All listed demo accounts use `Demo@123`. Customer login uses the customer ID;
staff login uses the email address.

| User type | Login |
|---|---|
| Customers | `CUST001` through `CUST010` |
| Analyst | `maya.rao@fraudbank.test` |
| Investigator | `arjun.kulkarni@fraudbank.test` |
| Investigator | `sana.khan@fraudbank.test` |
| Manager | `rahul.verma@fraudbank.test` |
| Admin | `admin@fraudbank.test` |
| Inactive staff (login refused) | `inactive@fraudbank.test` |

The deterministic seed also includes three recipient-only customers
(`CUST011`–`CUST013`) for network and dormant-account scenarios; they share the
demo password. Customer `CUST001` has two accounts to demonstrate account
switching.

## Demo script

The seed script inserts historical activity relative to its run time and calls
the rule procedure to create the following scenario flags. The staff portal's
Fraud flags, Investigations, and Reports pages show the seeded results.

1. **R01 – High amount:** send at least ₹50,000 in one transfer. A ₹2,00,000+
   transfer is HIGH severity.
2. **Manual review:** as Maya Rao, flag a transaction by its reference; the
   seeded ₹45,000 ATM withdrawal demonstrates this flow. As an investigator,
   open the case and record findings/outcome.
3. **R02 – Weekly spike:** the detector compares the last seven days with four
   prior weeks; its baseline and spike are seeded for `ACC1002`.
4. **R03 – Dormant reactivation:** after at least 21 days idle, make three
   outgoing transactions within an hour totalling ₹25,000 or more. The seeded
   history for `ACC1003` demonstrates four transfers to new accounts.
5. **R04 – Flagged recipient:** transfer to an account with earlier active flag
   history. The seeded confirmed-fraud history for `ACC1007` demonstrates it.
6. **R05 – Structuring:** make at least five outgoing transactions of ₹9,000–
   ₹9,999.99 in 24 hours. The seeded 12 transfers from `ACC1005` demonstrate
   deduplication to one flag.
7. **R06 – Fan-in:** send funds to a recipient with prior flag history after
   four or more distinct customers have sent funds in 24 hours. The seeded
   five-customer fan-in to `ACC1010` demonstrates it.
8. **R07 – Odd hours:** make three night transactions (00:00–04:59) in six hours
   after a daytime-only history of at least 10 transactions in 30 days. The
   seeded `ACC1006` activity demonstrates the rule.

The application stores the rule logic and balance updates in MySQL; procedures,
triggers, and views are documented in [docs/DBMS_CONCEPTS.md](docs/DBMS_CONCEPTS.md).

## Project structure

```text
app.py                    Flask routes, authentication, authorization, CSRF
db.py                     MySQL connection pool and query/procedure helpers
fraud_rules.py            Thin wrappers for stored fraud procedures
audit.py                  Audit-log query and filters
setup_db.py               Re-runnable database bootstrap
sql/schema.sql            Six core tables and enforced constraints
sql/procedures.sql        Views, transaction/fraud procedures, and triggers
sql/sample_data.sql       Deterministic demonstration accounts and scenarios
sql/reports.sql           Read-only report queries parsed by the Reports page
scripts/smoke_test.py     Database-backed end-to-end smoke test
templates/                Jinja pages and reusable macros
static/css/style.css      Responsive design-reference styling
static/js/main.js         Theme, login-role, and transaction confirmation UI
docs/DBMS_CONCEPTS.md     Viva/reference notes for database concepts
REPORT.md                 Implementation notes and actual verification status
```

## Limitations

- The flowchart's “Ask customer to confirm” branch is not implemented because
  the approved schema has no customer-confirmation state or data model.
- The schema intentionally stores some customer and rule descriptions
  redundantly for this mini-project; see the normalization discussion in the
  DBMS concepts guide.
- This is a local learning/demo system, not a production banking service.
