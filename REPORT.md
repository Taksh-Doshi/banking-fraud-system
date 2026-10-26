# Implementation Report

## Delivered

- **Phase 1 – Schema:** Applied the approved table reset, password hash,
  constraints, and index changes in `sql/schema.sql`. Static structure
  validation found the required 16 / 6 / 8 / 13 / 8 / 8 column counts and eight
  foreign keys.
- **Phase 2 – Database logic:** Added rerunnable views, four stored procedures,
  and six audit/status triggers in `sql/procedures.sql`. Fraud rules use
  transaction timestamps as their reference and implement R01–R07 with
  deduplication where specified.
- **Phase 3 – Sample data:** Added deterministic accounts, staff, transaction
  history, seven automatic-rule scenarios, manual flag, and investigation
  states in `sql/sample_data.sql`. The final query reports each rule and
  manual-flag requirement.
- **Phase 4 – Reports:** Added twelve read-only report queries in
  `sql/reports.sql`; the staff reports page reads these definitions.
- **Phase 5 – Bootstrap:** Added `setup_db.py` with a delimiter-aware SQL
  parser, ordered loading, `--no-sample`, and row/flag summaries.
- **Phase 6 – Backend:** Implemented a MySQL pool, query helpers, procedure
  wrappers, CSRF checks, customer/staff authentication and permissions,
  customer transaction flows, staff review routes, audit filtering,
  reporting, and error pages.
- **Phase 7 – Frontend:** Ported the design stylesheet without its external
  font/Tailwind imports and added Jinja pages/macros, theme switching, account
  switching, and a transaction-confirmation dialog populated from form fields.
- **Phase 8 – Smoke checks:** Added `scripts/smoke_test.py` for authenticated
  flows, balance changes, auditing, authorization, rule outcomes, reversal,
  constraint enforcement, and seeded scenarios.
- **Phase 9 – Documentation:** Updated `README.md` and added
  `docs/DBMS_CONCEPTS.md`.

## Verification actually performed

- `python -m py_compile app.py db.py fraud_rules.py audit.py setup_db.py` and
  the smoke test script compile successfully.
- SQL parser dry-run split all scripts into statements: schema (14),
  procedures (26), sample data (64), and reports (12). This validates statement
  splitting, not MySQL syntax or execution.
- Flask test client rendered `/` and `/login` (200) and the error route (404).
  All 22 registered Jinja templates parse.
- Static SQL checks confirmed requested schema column counts and eight
  foreign keys.
- `git diff --check` passed.

## Not verified

- MySQL execution was **not verified**. The local database connection attempt
  was rejected with MySQL error 1045 (access denied); Docker's local engine was
  also unavailable. Consequently I could not run `setup_db.py` twice, execute
  stored procedures/triggers, run the DB constraint checks, or run
  `scripts/smoke_test.py` against MySQL. SQL parser success is not a substitute
  for running MySQL 8.0.16+.
- Authenticated templates were parsed but not rendered against a live MySQL
  instance, and browser/mobile behavior was not manually verified.
- The contents of the workspace's pre-existing `design-reference/` folder
  remain untouched.

## Assumptions and limitations

- Existing `MYSQL_*` and `FLASK_SECRET_KEY` names are accepted as local
  compatibility aliases; new setup guidance uses `DB_*` and `SECRET_KEY`.
- `ACC1012`–`ACC1014` and `CUST011`–`CUST013` are extra active demo recipient
  accounts used to demonstrate recipient-network rules; no extra frozen
  account was added.
- For R07, the seeded cluster is placed at the next available 02:10–03:25
  clock window when setup runs after 04:00. It may therefore be a few hours in
  the future so the scenario remains testable regardless of setup time.
- The flowchart's “Ask customer to confirm” step is not implemented because
  the approved schema has no state or fields for customer confirmation. This
  is future work.
- This is a local DBMS mini-project, not production banking software.

## Commands to run locally

1. Configure MySQL 8.0.16+ and fill in `.env`.
2. Run `python setup_db.py` twice. Both runs should create the schema, database
   logic, and deterministic sample records.
3. Confirm the summary includes flags for `R01` through `R07` and a `MANUAL`
   flag; each sample verification row should have `requirement_met = 1`.
4. Run `python scripts/smoke_test.py`; it should report each database and
   application assertion as PASS.
5. Run `python app.py`, then sign in with any documented demo credential.
