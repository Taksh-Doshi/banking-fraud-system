# DBMS Concepts Viva Guide

This project uses MySQL as the source of truth for account state, transaction
processing, fraud detection, case status synchronization, and audit events.
Python routes validate web input and call database routines; the application
does not independently calculate account balances or fraud outcomes.

## Concepts mapped to the implementation

| Concept | File and object | How it is used |
|---|---|---|
| Primary keys | `sql/schema.sql`: each table's `*_id BIGINT AUTO_INCREMENT PRIMARY KEY` | Identifies each row and provides stable references. |
| Foreign keys | `sql/schema.sql`: `fk_transaction_from_account`, `fk_transaction_to_account`, `fk_flag_transaction`, `fk_flag_created_by`, both `fk_investigation_*`, and both `fk_audit_*` | Enforces referential integrity across accounts, transactions, staff, flags, investigations, and audit records. There are eight FKs. |
| `NOT NULL` | `sql/schema.sql`: transaction type/amount, account number/password hash, flag reason and other required attributes | Prevents incomplete required records. |
| `DEFAULT` | `sql/schema.sql`: account status/balance, transaction status/time, flag source/severity/status, investigation status, and audit time | Supplies standard initial values while allowing explicit values where necessary. |
| `CHECK` | `sql/schema.sql`: account balance/type/status, staff role/status, transaction amount/type/status/accounts, flag source/creator/severity/status, investigation status/outcome/closed state | Enforces domain and multi-column rules in MySQL 8.0.16+. |
| `UNIQUE` | `uq_account_number`, `uq_flag_txn_rule`, and unique staff email / transaction reference numbers | Prevents duplicate account identifiers, rule flags for the same transaction, staff login emails, and transaction references. Nullable `rule_id` allows multiple manual flags because MySQL permits multiple NULL values in a unique key. |
| Indexes | `sql/schema.sql`: `idx_customer_id`, status/time indexes, `idx_txn_from_time`, `idx_txn_to_time`, flag/investigation/audit indexes | Accelerates common search/filter patterns. Composite account/time indexes have the account FK column first and support its FK lookup while also helping account history queries. |
| Transactions / ACID | `sp_make_transaction`, `sp_reverse_transaction` in `sql/procedures.sql`; connection transaction handling in `db.py` | A balance change, transaction status change, flagging and reversal are performed transactionally and committed together; exceptions roll back. |
| Row locking | `sp_make_transaction`, `sp_reverse_transaction` | Locks affected account rows with `SELECT ... FOR UPDATE` in ascending account ID order to prevent concurrent balance races and reduce deadlocks. |
| Stored procedures | `sp_make_transaction`, `sp_evaluate_fraud_rules`, `sp_weekly_analysis`, `sp_reverse_transaction` | Encapsulate transfer/withdrawal/deposit behavior, seven fraud rules, weekly re-evaluation, and confirmed-fraud reversals. |
| Triggers | `trg_txn_ai`, `trg_txn_au`, `trg_flag_ai`, `trg_flag_au`, `trg_inv_ai`, `trg_inv_au` | Automatically create audit events and synchronize related transaction, flag, and investigation states. |
| Views | `v_transaction_history`, `v_flag_detail`, `v_weekly_account_activity` | Present joined transaction history, current flag/case details, and account-level weekly activity for reports and pages. |
| Joins | Views, `sql/reports.sql` | Joins connect transactions to accounts and flags to staff/investigations; outer joins preserve rows without an optional staff assignment. |
| Subqueries | `v_flag_detail`, `sql/reports.sql` | Selects the latest investigation, checks earlier fraud history, and finds stale flags without an investigation. |
| CTEs | `sql/reports.sql`: `weekly_trend_lag`, `spike_accounts` | Names intermediate weekly activity relations to make the report query easier to understand. |
| Window functions | `sql/reports.sql`: `LAG` and `AVG(...) OVER (PARTITION BY account_id)` | Compares a week's count to the prior week and to the account's own weekly average without collapsing rows. |
| Audit trail | `TRANSACTION_AUDIT` plus triggers/procedures | Captures transaction creation/status, flag creation/status, investigation updates, rejections, and reversals. `@app_staff_id` attributes staff-originated changes. |
| Delimiter parsing | `setup_db.py:parse_sql_script` | Executes one SQL statement at a time while respecting custom delimiters around routines and triggers. |

## Functional dependencies and normalization

### `CUSTOMER_ACCOUNT`

The primary key and unique account number give the following dependencies:

- `customer_account_id → customer_id, full_name, date_of_birth, email, phone, address, password_hash, account_number, account_type, balance, account_status, opened_at, holder_role, start_date, end_date`
- `account_number → customer_account_id` and, by extension, every other account attribute.
- The intended customer-level dependency is `customer_id → full_name, date_of_birth, email, phone, address, password_hash`.

The last dependency explains the intentional redundancy: a customer with more
than one account repeats person/contact attributes and password hash in each
account row. Because the table uses a single-column primary key, it has no
partial-key dependency and is in 2NF. Customer attributes depending on
`customer_id` rather than directly on the account key create a transitive
dependency and a 3NF trade-off.

### `FRAUD_FLAG`

- `flag_id → transaction_id, rule_id, rule_name, rule_description, rule_type, threshold_value, flag_source, reason, severity, flag_status, created_by_staff_id, flagged_at`
- For non-NULL automatic rules, `(transaction_id, rule_id) → flag_id` by `uq_flag_txn_rule`.
- For rule-based flags, `rule_id → rule_name, rule_description, rule_type, threshold_value` is the intended dependency, but rule metadata is stored with each flag. `rule_id` deliberately has no FK because there is no rule catalog table and manual flags use a NULL rule ID.

This keeps the six-table schema self-contained, at the cost of repeated rule
metadata and transitive dependencies.

### More normalized alternative

A fully normalized design could add a `CUSTOMER` table keyed by
`customer_id`; `CUSTOMER_ACCOUNT` would then retain only account-specific
attributes and a customer FK. A `FRAUD_RULE` catalog keyed by `rule_id` could
hold rule name, description, type, and threshold; `FRAUD_FLAG` would hold only
the rule FK plus flag-specific reason/severity/state. Password hashes would
normally belong to a customer identity/authentication record (and staff would
have a separate identity credential record), rather than be copied into each
account row. These changes are intentionally outside the approved six-table
schema.

## Important design details

- The `ON UPDATE RESTRICT` action on `fk_flag_created_by` is deliberate. MySQL
  error 3823 prohibits a check-constrained FK column when its FK uses
  `ON UPDATE CASCADE`; staff IDs are stable identifiers, so cascading updates
  are not required.
- Transaction and flag IDs are never made from presentation labels. All
  references are generated by MySQL and rendered from query results.
- Failed business transactions are recorded as `FAILED` and create a
  `TRANSACTION_REJECTED` audit event without changing balances.
- The report SQL is read-only and each report starts with a `SELECT` or `WITH`
  statement; the Flask report page loads the definitions from that file.
