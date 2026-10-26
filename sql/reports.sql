-- REPORT: flags_by_rule | Flags by rule | Counts active and closed flags by detector rule.
SELECT rule_id, rule_name, COUNT(*) AS flag_count,
       SUM(flag_status IN ('OPEN', 'UNDER_INVESTIGATION')) AS open_count
FROM FRAUD_FLAG
GROUP BY rule_id, rule_name
ORDER BY flag_count DESC, rule_id;

-- REPORT: top_flagged_accounts | Most flagged accounts | Ranks accounts appearing in flagged transactions.
SELECT account_number, full_name, COUNT(DISTINCT flag_id) AS flag_count,
       SUM(transaction_amount) AS flagged_amount
FROM (
    SELECT f.flag_id, a.account_number, a.full_name, t.amount AS transaction_amount
    FROM FRAUD_FLAG f
    JOIN BANK_TRANSACTION t ON t.transaction_id = f.transaction_id
    JOIN CUSTOMER_ACCOUNT a
      ON a.customer_account_id IN (t.from_account_id, t.to_account_id)
) AS flagged_accounts
GROUP BY account_number, full_name
ORDER BY flag_count DESC, flagged_amount DESC
LIMIT 10;

-- REPORT: weekly_trend_lag | Weekly activity trend | Compares account activity with its prior recorded week.
WITH weekly AS (
    SELECT account_id, account_number, activity_week, txn_count, total_amount,
           LAG(txn_count) OVER (PARTITION BY account_id ORDER BY activity_week) AS prior_week_count
    FROM v_weekly_account_activity
)
SELECT account_id, account_number, activity_week, txn_count, prior_week_count,
       CASE WHEN prior_week_count IS NULL OR prior_week_count = 0 THEN NULL
            ELSE ROUND((txn_count - prior_week_count) * 100.0 / prior_week_count, 2)
       END AS percent_change,
       total_amount
FROM weekly
ORDER BY activity_week DESC, account_number;

-- REPORT: spike_accounts | Weekly activity spikes | Finds weeks above three times each account's average count.
WITH weekly AS (
    SELECT account_id, account_number, activity_week, txn_count,
           AVG(txn_count) OVER (PARTITION BY account_id) AS average_weekly_count
    FROM v_weekly_account_activity
)
SELECT account_id, account_number, activity_week, txn_count,
       ROUND(average_weekly_count, 2) AS average_weekly_count
FROM weekly
GROUP BY account_id, account_number, activity_week, txn_count, average_weekly_count
HAVING txn_count > 3 * average_weekly_count
ORDER BY txn_count DESC;

-- REPORT: investigation_outcomes | Investigation outcomes | Shows case counts and mean time to resolution.
SELECT outcome, COUNT(*) AS investigation_count,
       ROUND(AVG(TIMESTAMPDIFF(HOUR, opened_at, resolved_at)), 2)
           AS average_resolution_hours
FROM INVESTIGATION
GROUP BY outcome
ORDER BY investigation_count DESC;

-- REPORT: staff_workload | Staff case workload | Includes staff with no assigned investigations.
SELECT s.staff_id, s.staff_name, s.role,
       COUNT(i.investigation_id) AS assigned_cases,
       SUM(i.investigation_status IN ('OPEN', 'IN_PROGRESS')) AS active_cases
FROM STAFF s
LEFT JOIN INVESTIGATION i ON i.assigned_staff_id = s.staff_id
GROUP BY s.staff_id, s.staff_name, s.role
ORDER BY assigned_cases DESC, s.staff_name;

-- REPORT: stale_unassigned_flags | Stale unassigned flags | Open flags older than 24 hours without an investigation.
SELECT f.flag_id, f.rule_id, f.rule_name, f.severity, f.flagged_at,
       t.reference_number, t.amount
FROM FRAUD_FLAG f
JOIN BANK_TRANSACTION t ON t.transaction_id = f.transaction_id
WHERE f.flag_status = 'OPEN'
  AND f.flagged_at < NOW() - INTERVAL 24 HOUR
  AND NOT EXISTS (
      SELECT 1 FROM INVESTIGATION i WHERE i.flag_id = f.flag_id
  )
ORDER BY f.flagged_at;

-- REPORT: txns_by_hour | Transactions by hour | Compares daytime and night transaction counts.
SELECT HOUR(transaction_time) AS transaction_hour,
       SUM(HOUR(transaction_time) BETWEEN 6 AND 21) AS daytime_count,
       SUM(HOUR(transaction_time) BETWEEN 0 AND 5
           OR HOUR(transaction_time) BETWEEN 22 AND 23) AS night_count,
       COUNT(*) AS total_count
FROM BANK_TRANSACTION
GROUP BY HOUR(transaction_time)
ORDER BY transaction_hour;

-- REPORT: daily_totals_30d | Daily transaction totals | Aggregates amount by type over the last 30 days.
SELECT DATE(transaction_time) AS transaction_day,
       SUM(CASE WHEN transaction_type = 'DEPOSIT' THEN amount ELSE 0 END) AS deposits,
       SUM(CASE WHEN transaction_type = 'WITHDRAWAL' THEN amount ELSE 0 END) AS withdrawals,
       SUM(CASE WHEN transaction_type = 'TRANSFER' THEN amount ELSE 0 END) AS transfers
FROM BANK_TRANSACTION
WHERE transaction_time >= NOW() - INTERVAL 30 DAY
  AND transaction_status <> 'FAILED'
GROUP BY DATE(transaction_time)
ORDER BY transaction_day DESC;

-- REPORT: fan_in_recipients | Fan-in recipients | Lists recipients paid by four or more distinct customers.
SELECT a.account_number, a.full_name,
       COUNT(DISTINCT sender.customer_id) AS distinct_senders,
       COUNT(*) AS transfer_count,
       SUM(t.amount) AS received_amount
FROM BANK_TRANSACTION t
JOIN CUSTOMER_ACCOUNT a ON a.customer_account_id = t.to_account_id
JOIN CUSTOMER_ACCOUNT sender ON sender.customer_account_id = t.from_account_id
WHERE t.transaction_type = 'TRANSFER'
  AND t.transaction_status <> 'FAILED'
  AND t.transaction_time >= NOW() - INTERVAL 30 DAY
GROUP BY a.account_number, a.full_name
HAVING COUNT(DISTINCT sender.customer_id) >= 4
ORDER BY distinct_senders DESC, received_amount DESC;

-- REPORT: rule_precision | Rule outcome rates | Compares confirmed-fraud and legitimate outcomes per rule.
SELECT f.rule_id, f.rule_name,
       COUNT(DISTINCT f.flag_id) AS investigated_flags,
       COUNT(DISTINCT CASE WHEN i.outcome = 'CONFIRMED_FRAUD' THEN f.flag_id END)
           AS confirmed_flags,
       COUNT(DISTINCT CASE WHEN i.outcome = 'LEGITIMATE' THEN f.flag_id END)
           AS legitimate_flags,
       ROUND(
           COUNT(DISTINCT CASE WHEN i.outcome = 'CONFIRMED_FRAUD' THEN f.flag_id END)
           * 100.0 / NULLIF(COUNT(DISTINCT CASE
               WHEN i.outcome IN ('CONFIRMED_FRAUD', 'LEGITIMATE') THEN f.flag_id
           END), 0), 2
       ) AS confirmed_rate_percent
FROM FRAUD_FLAG f
LEFT JOIN INVESTIGATION i ON i.flag_id = f.flag_id
WHERE f.rule_id IS NOT NULL
GROUP BY f.rule_id, f.rule_name
ORDER BY f.rule_id;

-- REPORT: recent_audit | Recent audit activity | Shows the latest 50 actions with staff identities.
SELECT a.audit_id, a.action_time, a.action_type, a.old_status, a.new_status,
       a.action_details, t.reference_number, s.staff_name
FROM TRANSACTION_AUDIT a
LEFT JOIN BANK_TRANSACTION t ON t.transaction_id = a.transaction_id
LEFT JOIN STAFF s ON s.staff_id = a.staff_id
ORDER BY a.action_time DESC, a.audit_id DESC
LIMIT 50;
