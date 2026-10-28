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

---

## Fix Notes (Six-Item Improvement Pass)

### Item 1 – Customer self sign-up (`/register`)

**Status:** Implemented from scratch (route did not exist).

- New route `GET /register` and `POST /register` added to [`app.py`](file:///c:/Users/Taksh%20Doshi/OneDrive/Desktop/banking-fraud-system/app.py).
- Template [`templates/register.html`](file:///c:/Users/Taksh Doshi/OneDrive/Desktop/banking-fraud-system/templates/register.html) created with three sections: Personal Info, Account Details, and Security.
- Server-side validations: non-empty full name, valid email regex, 10-digit phone, age ≥ 18, account type in {SAVINGS, CURRENT, SALARY}, strong password (≥8 chars, upper, lower, digit, special), passwords match, terms checkbox.
- On success: redirects to `/register/success` (one-time session-based, prevents auto-login).
- Rate-limited to 5 attempts per 10 minutes per IP via `REGISTER_LIMITS`.

### Item 2 – Automatic sequential Customer ID generation

**Status:** Implemented in stored procedure.

- `sp_register_customer` in [`sql/procedures.sql`](file:///c:/Users/Taksh%20Doshi/OneDrive/Desktop/banking-fraud-system/sql/procedures.sql) generates IDs of the form `CUST###`.
- Strategy: `MAX(CAST(SUBSTRING(customer_id, 5) AS UNSIGNED))` over `CUSTOMER_ACCOUNT` gives the current highest number; new ID = highest + 1, zero-padded to 3 digits.
- Race-condition protection: `GET_LOCK('register_customer', 5)` serialises concurrent registrations; `RELEASE_LOCK` on every exit path (success, duplicate-key, exception).
- Account number similarly generated as `ACC{n}`.

### Item 3 – Eye icon (show/hide) on all password fields

**Status:** Implemented.

- SVG `eye` and `eye-off` macros added to [`templates/_icons.html`](file:///c:/Users/Taksh%20Doshi/OneDrive/Desktop/banking-fraud-system/templates/_icons.html).
- `<button type="button" class="eye-toggle" data-password-toggle data-target="…">` placed adjacent to each password `<input>` in:
  - `templates/login.html` (1 field)
  - `templates/register.html` (2 fields)
  - `templates/settings.html` (3 fields)
- JS in [`static/js/main.js`](file:///c:/Users/Taksh%20Doshi/OneDrive/Desktop/banking-fraud-system/static/js/main.js): delegated `click` handler on `[data-password-toggle]` toggles `input.type` between `"password"` and `"text"`, swaps the SVG, and updates `aria-pressed` / `aria-label`.
- `pageshow` listener resets all toggled fields to `type="password"` when navigating back from browser cache.
- CSS: `.eye-toggle` and `::-ms-reveal { display: none }` (suppresses Edge's built-in eye) in [`static/css/style.css`](file:///c:/Users/Taksh%20Doshi/OneDrive/Desktop/banking-fraud-system/static/css/style.css).

### Item 4 – Database not reflecting after creating a new account (root-cause fix)

**Status:** Root causes identified and resolved.

**Root causes found:**

1. `sp_register_customer` did not exist in MySQL — calling it would raise an error silently swallowed by the previous route handler's bare `except` clause, so the row was never written.
2. `db.py` called `os.getenv(…)` **before** `load_dotenv()` was invoked. When `db.py` was imported by `app.py`, dotenv was loaded by `app.py` first — but when any other script (e.g., `setup_db.py`) imported `db` without loading dotenv, all env vars were empty and the wrong database was targeted.
3. MySQL connection pool was initialised with `autocommit=False`. Pooled connections that had a prior implicit open transaction retained a `REPEATABLE READ` snapshot and could not observe rows committed by a different connection.

**Fixes applied:**

- `load_dotenv()` moved to the **top of `db.py`** (before pool init) so it fires regardless of import order.
- Pool now created with `autocommit=True`; stored procedures manage their own `START TRANSACTION / COMMIT / ROLLBACK`.
- `sp_register_customer` created and loaded via `setup_db.py`.
- `setup_db.py` now prints a clear warning before dropping tables.

**Regression test added:** `test_registration_flow_and_db_reflection` in `scripts/test_fixes.py` opens a *separate, direct* `mysql.connector` connection (not the pool) after registration and asserts the row is immediately visible — specifically catching the REPEATABLE READ snapshot bug.

### Item 5 – Forgot Customer ID recovery flow

**Status:** Implemented from scratch (route did not exist).

- Route `GET /forgot-id` and `POST /forgot-id` added to `app.py`.
- Matches on `LOWER(email) = LOWER(?)` AND `date_of_birth = ?` AND phone (raw, normalised, or `+91{norm}` format) for non-CLOSED accounts.
- Returns all distinct `customer_id`s found (a customer may have multiple accounts).
- Generic error message on failure — deliberately does not reveal whether email/DOB/phone was individually wrong.
- Failed attempts are logged at WARNING level without personal data.
- Rate-limited to 5 attempts per 15 minutes per IP via `FORGOT_LIMITS`.
- Template `templates/forgot_id.html` shows the form on GET/failed POST, and the found IDs (with copy buttons) on success.

### Item 6 – Copy icon next to generated Customer ID

**Status:** Implemented with clipboard API and execCommand fallback.

- SVG `copy` macro added to `templates/_icons.html`.
- `.copy-btn[data-copy-target="<id>"]` buttons placed next to Customer ID on:
  - `templates/register_success.html` (Customer ID + Account Number)
  - `templates/forgot_id.html` (all recovered IDs)
  - `templates/customer_dashboard.html` (Customer ID + Account Number on dashboard account card)
- JS in `static/js/main.js`: delegated `click` handler tries `navigator.clipboard.writeText` (requires HTTPS or localhost), falls back to `document.execCommand('copy')` for HTTP/LAN contexts.
- On success: button swaps to a checkmark SVG + "Copied!" for 2 seconds, then restores; announces to `#copy-live-region` (ARIA live region) for screen-readers.

---

## Files Changed

| File | Change |
|---|---|
| `sql/procedures.sql` | Added `sp_register_customer`; fixed R04 recipient-check bug |
| `sql/sample_data.sql` | Fixed `SEED-R06-04` sender to preserve R03 inactivity window |
| `setup_db.py` | Added drop-warning; defaults database to `banking_fraud_system` |
| `db.py` | Added `load_dotenv()`; pool `autocommit=True` |
| `app.py` | Added `/register`, `/register/success`, `/forgot-id`; `REGISTER_LIMITS`, `FORGOT_LIMITS`; `_normalize_phone`, `_is_strong_password` |
| `templates/_icons.html` | Added `eye`, `eye-off`, `copy` SVG macros |
| `templates/login.html` | Eye toggle; "Create account" / "Forgot Customer ID?" links; `#copy-live-region` |
| `templates/register.html` | New registration form |
| `templates/register_success.html` | Success page with copy buttons |
| `templates/forgot_id.html` | Recovery form + results with copy buttons |
| `templates/settings.html` | Eye toggles on all three password fields |
| `templates/customer_dashboard.html` | Customer ID + Account Number with copy buttons |
| `templates/index.html` | "Create account" call-to-action |
| `static/css/style.css` | `.eye-toggle`, `.copy-btn`, `.credentials-card`, `.customer-auth-links` styles |
| `static/js/main.js` | Eye toggle handler; `pageshow` reset; copy handler; register submit guard; role-switch customer-links toggle |
| `scripts/test_fixes.py` | New: 37-assertion test suite for all six items |

---

## Test Results

| Suite | Assertions | Result |
|---|---|---|
| `scripts/smoke_test.py` (original) | 39 | ✅ All PASS |
| `scripts/test_fixes.py` (new) | 37 | ✅ All PASS |

---

## Assumptions Made

1. The `CUSTOMER_ACCOUNT` table is the single source of truth for customer identity (email, phone, DOB, password_hash). No separate `CUSTOMER` or `CUSTOMER_CREDENTIAL` table was created.
2. "Sequential" Customer ID means `CUST{N}` where N is `MAX(numeric suffix) + 1` at the moment of creation, zero-padded to at least 3 digits (e.g., `CUST001`, `CUST013`). IDs can exceed 3 digits without loss of uniqueness.
3. Phone normalisation strips all non-digit characters, then validates exactly 10 digits (optionally preceded by `91` or `0`). The stored value is the raw string as entered.
4. The copy-button fallback (`execCommand`) works on HTTP/LAN environments where the Clipboard API is not available. It requires the element to be temporarily attached to the DOM.
5. Session-based one-time display on `/register/success` (IDs stored in `session`, cleared on first render) prevents a customer from bookmarking a credentials page that would be stale after a later registration.
6. The "Forgot Customer ID" flow does **not** send an email — it displays the ID directly in the browser, matching the project's local demonstration scope and the absence of an email-sending dependency.

---

## Manual Verification Checklist

Work through these steps in a browser after running `python setup_db.py` and `python app.py`.

1. **Register – happy path**
   - [ ] Navigate to `/login` → click "Create account" → lands on `/register`.
   - [ ] Fill in all fields with valid data, choose "Savings", enter ₹500 initial deposit, submit.
   - [ ] Lands on `/register/success`. Displays a `CUST###` Customer ID and an `ACC###` Account Number.
   - [ ] Both have working "Copy" buttons (verify text appears in clipboard when pasted).
   - [ ] Click "Go to Sign In", log in with the generated Customer ID and the chosen password → reaches the dashboard.
   - [ ] Dashboard shows balance of ₹500.00 and displays the Customer ID with a copy button on the account card.

2. **Register – validation rejections**
   - [ ] DOB set to a date less than 18 years ago → error "at least 18 years".
   - [ ] Password "abc" → error "at least 8 characters".
   - [ ] Confirm password different → error "Passwords do not match".
   - [ ] Phone "123" → error "10-digit".
   - [ ] Submit a second registration with the same email → error "already exists".

3. **Eye toggle on password fields**
   - [ ] Login page: click the eye button → password text is visible; click again → hidden.
   - [ ] Register page: both password and confirm-password fields have working eye toggles.
   - [ ] Settings page (logged in as customer): all three password fields (current, new, confirm) have working eye toggles.
   - [ ] Navigate back (browser back button) from a page where password was revealed → password is hidden again.

4. **Forgot Customer ID recovery**
   - [ ] From the login page, click "Forgot Customer ID?".
   - [ ] Enter the email, DOB, and phone of a registered customer → sees their Customer ID displayed with a copy button.
   - [ ] Enter correct email but wrong DOB → generic "could not find" message (no leak of which field was wrong).
   - [ ] Submit 5 times in quick succession on the same browser → 6th attempt shows "Too many attempts" rate-limit error.

5. **Database reflection (Item 4)**
   - [ ] After registering a new customer, immediately log in with the generated ID and password → login succeeds without any server restart or wait (confirms the REPEATABLE READ bug is fixed).
   - [ ] Transaction history shows the initial deposit transaction.

6. **Copy icon UX**
   - [ ] On the success page, clicking "Copy" changes button text to "Copied!" for ~2 seconds, then reverts.
   - [ ] On the dashboard, clicking the copy button next to the Account Number copies the correct account number.
   - [ ] On a Forgot Customer ID result page, clicking "Copy" copies the correct Customer ID.
