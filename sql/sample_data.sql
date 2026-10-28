SET @now = NOW();

-- Deterministic demonstration data. Re-run only after schema.sql.
SET @demo_hash =
    'pbkdf2:sha256:600000$DemoSeedSalt01$1b9df8ce94d4dfd2eff9369d64e11157c9a2f6e265e6877627c9f331a07fd999';

INSERT INTO CUSTOMER_ACCOUNT
    (customer_id, full_name, email, phone, address, password_hash,
     account_number, account_type, balance, account_status, opened_at)
VALUES
    ('CUST001', 'Aarav Sharma', 'aarav.sharma@example.test', '+91-9876501001',
     '12 Linking Road, Mumbai, Maharashtra', @demo_hash, 'ACC1001', 'SAVINGS',
     625000.00, 'ACTIVE', @now - INTERVAL 3 YEAR),
    ('CUST001', 'Aarav Sharma', 'aarav.sharma@example.test', '+91-9876501001',
     '12 Linking Road, Mumbai, Maharashtra', @demo_hash, 'ACC1011', 'CURRENT',
     180000.00, 'ACTIVE', @now - INTERVAL 2 YEAR),
    ('CUST002', 'Diya Patel', 'diya.patel@example.test', '+91-9876501002',
     '44 CG Road, Ahmedabad, Gujarat', @demo_hash, 'ACC1002', 'CURRENT',
     115000.00, 'ACTIVE', @now - INTERVAL 4 YEAR),
    ('CUST003', 'Rohan Mehta', 'rohan.mehta@example.test', '+91-9876501003',
     '8 FC Road, Pune, Maharashtra', @demo_hash, 'ACC1003', 'SAVINGS',
     225000.00, 'ACTIVE', @now - INTERVAL 5 YEAR),
    ('CUST004', 'Sneha Iyer', 'sneha.iyer@example.test', '+91-9876501004',
     '19 T Nagar, Chennai, Tamil Nadu', @demo_hash, 'ACC1004', 'SALARY',
     310000.00, 'ACTIVE', @now - INTERVAL 3 YEAR),
    ('CUST005', 'Karan Singh', 'karan.singh@example.test', '+91-9876501005',
     '27 Sector 17, Chandigarh', @demo_hash, 'ACC1005', 'SAVINGS',
     450000.00, 'ACTIVE', @now - INTERVAL 6 YEAR),
    ('CUST006', 'Neha Kulkarni', 'neha.kulkarni@example.test', '+91-9876501006',
     '31 Baner Road, Pune, Maharashtra', @demo_hash, 'ACC1006', 'SAVINGS',
     275000.00, 'ACTIVE', @now - INTERVAL 4 YEAR),
    ('CUST007', 'Vikram Joshi', 'vikram.joshi@example.test', '+91-9876501007',
     '6 Indiranagar, Bengaluru, Karnataka', @demo_hash, 'ACC1007', 'CURRENT',
     340000.00, 'ACTIVE', @now - INTERVAL 2 YEAR),
    ('CUST008', 'Pooja Nair', 'pooja.nair@example.test', '+91-9876501008',
     '53 Kakkanad, Kochi, Kerala', @demo_hash, 'ACC1008', 'SAVINGS',
     195000.00, 'ACTIVE', @now - INTERVAL 3 YEAR),
    ('CUST009', 'Imran Qureshi', 'imran.qureshi@example.test', '+91-9876501009',
     '22 Park Street, Kolkata, West Bengal', @demo_hash, 'ACC1009', 'SAVINGS',
     285000.00, 'ACTIVE', @now - INTERVAL 5 YEAR),
    ('CUST010', 'Anjali Deshmukh', 'anjali.deshmukh@example.test', '+91-9876501010',
     '17 Civil Lines, Nagpur, Maharashtra', @demo_hash, 'ACC1010', 'CURRENT',
     390000.00, 'ACTIVE', @now - INTERVAL 4 YEAR),
    ('CUST011', 'Meera Shah', 'meera.shah@example.test', '+91-9876501011',
     '9 Alkapuri, Vadodara, Gujarat', @demo_hash, 'ACC1012', 'SAVINGS',
     95000.00, 'ACTIVE', @now - INTERVAL 2 YEAR),
    ('CUST012', 'Dev Menon', 'dev.menon@example.test', '+91-9876501012',
     '15 MG Road, Thiruvananthapuram, Kerala', @demo_hash, 'ACC1013', 'SAVINGS',
     125000.00, 'ACTIVE', @now - INTERVAL 3 YEAR),
    ('CUST013', 'Isha Rao', 'isha.rao@example.test', '+91-9876501013',
     '21 Banjara Hills, Hyderabad, Telangana', @demo_hash, 'ACC1014', 'CURRENT',
     165000.00, 'ACTIVE', @now - INTERVAL 2 YEAR);

INSERT INTO STAFF
    (staff_name, email, password_hash, role, staff_status)
VALUES
    ('Maya Rao', 'maya.rao@fraudbank.test', @demo_hash, 'ANALYST', 'ACTIVE'),
    ('Arjun Kulkarni', 'arjun.kulkarni@fraudbank.test', @demo_hash,
     'INVESTIGATOR', 'ACTIVE'),
    ('Sana Khan', 'sana.khan@fraudbank.test', @demo_hash,
     'INVESTIGATOR', 'ACTIVE'),
    ('Rahul Verma', 'rahul.verma@fraudbank.test', @demo_hash,
     'MANAGER', 'ACTIVE'),
    ('System Admin', 'admin@fraudbank.test', @demo_hash, 'ADMIN', 'ACTIVE'),
    ('Inactive Staff', 'inactive@fraudbank.test', @demo_hash,
     'ANALYST', 'INACTIVE');

SET @acc1 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1001');
SET @acc2 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1002');
SET @acc3 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1003');
SET @acc4 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1004');
SET @acc5 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1005');
SET @acc6 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1006');
SET @acc7 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1007');
SET @acc8 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1008');
SET @acc9 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1009');
SET @acc10 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1010');
SET @acc11 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1011');
SET @acc12 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1012');
SET @acc13 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1013');
SET @acc14 = (SELECT customer_account_id FROM CUSTOMER_ACCOUNT WHERE account_number = 'ACC1014');
SET @maya = (SELECT staff_id FROM STAFF WHERE email = 'maya.rao@fraudbank.test');
SET @arjun = (SELECT staff_id FROM STAFF WHERE email = 'arjun.kulkarni@fraudbank.test');
SET @sana = (SELECT staff_id FROM STAFF WHERE email = 'sana.khan@fraudbank.test');
SET @rahul = (SELECT staff_id FROM STAFF WHERE email = 'rahul.verma@fraudbank.test');
SET @app_staff_id = NULL;

-- Ordinary activity for account ACC1001, then the R01 high-value transfer.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('DEPOSIT', 85000.00, @now - INTERVAL 6 DAY, 'COMPLETED',
     'SEED-A01-SALARY', NULL, @acc1),
    ('TRANSFER', 12000.00, @now - INTERVAL 4 DAY, 'COMPLETED',
     'SEED-A01-TRANSFER', @acc1, @acc2),
    ('TRANSFER', 350000.00, @now - INTERVAL 3 HOUR, 'COMPLETED',
     'SEED-R01-TRANSFER', @acc1, @acc9);

-- ACC1002 has 8 transactions in each of the four baseline weeks.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL SELECT n + 1 FROM seq WHERE n < 32
)
SELECT 'WITHDRAWAL', 2500.00,
       @now - INTERVAL (8 + FLOOR((n - 1) / 8) * 7 + MOD(n - 1, 8)) DAY,
       'COMPLETED', CONCAT('SEED-R02-BASE-', LPAD(n, 4, '0')),
       @acc2, NULL
FROM seq;

-- 35 recent withdrawals total approximately 150,000 and trigger R02.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL SELECT n + 1 FROM seq WHERE n < 35
)
SELECT 'WITHDRAWAL', 4285.71,
       @now - INTERVAL (21 + MOD(n, 35)) MINUTE,
       'COMPLETED', CONCAT('SEED-R02-RECENT-', LPAD(n, 4, '0')),
       @acc2, NULL
FROM seq;
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('WITHDRAWAL', 1500.00, @now - INTERVAL 20 MINUTE, 'COMPLETED',
     'SEED-R02-FINAL', @acc2, NULL);

-- ACC1003 was dormant for 45 days before four clustered transfers.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('WITHDRAWAL', 1000.00, @now - INTERVAL 45 DAY, 'COMPLETED',
     'SEED-R03-DORMANT', @acc3, NULL),
    ('TRANSFER', 30000.00, @now - INTERVAL 50 MINUTE, 'COMPLETED',
     'SEED-R03-01', @acc3, @acc11),
    ('TRANSFER', 30000.00, @now - INTERVAL 35 MINUTE, 'COMPLETED',
     'SEED-R03-02', @acc3, @acc12),
    ('TRANSFER', 30000.00, @now - INTERVAL 20 MINUTE, 'COMPLETED',
     'SEED-R03-03', @acc3, @acc13),
    ('TRANSFER', 30000.00, @now - INTERVAL 10 MINUTE, 'COMPLETED',
     'SEED-R03-04', @acc3, @acc12);

-- Prior confirmed-fraud recipient history activates R04.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('TRANSFER', 60000.00, @now - INTERVAL 20 DAY, 'COMPLETED',
     'SEED-R04-OLD', @acc8, @acc7);
SET @old_flag_txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R04-OLD');
INSERT INTO FRAUD_FLAG
    (transaction_id, rule_id, rule_name, rule_description, rule_type,
     threshold_value, flag_source, reason, severity, flagged_at)
VALUES
    (@old_flag_txn, 'LEGACY_RISK', 'LEGACY_CONFIRMED',
     'Seeded confirmed fraud history for recipient-network analysis.',
     'NETWORK', 0, 'AUTOMATIC', 'Prior confirmed fraud activity.', 'HIGH',
     @now - INTERVAL 20 DAY);
SET @old_flag_id = (SELECT flag_id FROM FRAUD_FLAG WHERE transaction_id = @old_flag_txn);
INSERT INTO INVESTIGATION
    (flag_id, assigned_staff_id, investigation_status, findings, outcome,
     opened_at, resolved_at)
VALUES
    (@old_flag_id, @arjun, 'IN_PROGRESS', 'Reviewing historical recipient activity.',
     NULL, @now - INTERVAL 20 DAY, NULL);
UPDATE INVESTIGATION
SET investigation_status = 'RESOLVED', outcome = 'CONFIRMED_FRAUD',
    resolved_at = @now - INTERVAL 19 DAY
WHERE flag_id = @old_flag_id;
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('TRANSFER', 20000.00, @now - INTERVAL 1 HOUR, 'COMPLETED',
     'SEED-R04-TRANSFER', @acc4, @acc7);

-- One manual flag for the customer's reported 45,000 withdrawal.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('WITHDRAWAL', 45000.00, @now - INTERVAL 2 DAY, 'COMPLETED',
     'SEED-MANUAL-WD', @acc5, NULL);
SET @manual_txn_id = (
    SELECT transaction_id FROM BANK_TRANSACTION
    WHERE reference_number = 'SEED-MANUAL-WD'
);
INSERT INTO FRAUD_FLAG
    (transaction_id, rule_id, rule_name, rule_description, rule_type,
     threshold_value, flag_source, reason, severity, created_by_staff_id,
     flagged_at)
VALUES
    (@manual_txn_id, NULL, 'MANUAL_REVIEW',
     'Customer-reported suspicious ATM withdrawal.', 'MANUAL', NULL,
     'MANUAL', 'Customer reported unfamiliar ATM withdrawal', 'MEDIUM',
     @maya, @now - INTERVAL 1 DAY);
SET @manual_flag_id = (
    SELECT flag_id FROM FRAUD_FLAG WHERE transaction_id = @manual_txn_id
);
INSERT INTO INVESTIGATION
    (flag_id, assigned_staff_id, investigation_status, findings, opened_at)
VALUES
    (@manual_flag_id, @arjun, 'IN_PROGRESS',
     'Customer report received; ATM transaction details are being reviewed.',
     @now - INTERVAL 20 HOUR);

-- Twelve transactions just under the review threshold; the last one triggers R05.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL SELECT n + 1 FROM seq WHERE n < 12
)
SELECT 'TRANSFER', 9900.00,
       @now - INTERVAL (20 - n) HOUR,
       'COMPLETED', CONCAT('SEED-R05-', LPAD(n, 2, '0')),
       @acc5, @acc9
FROM seq;

-- Older high-value flag history and INCONCLUSIVE investigation for ACC1010.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('TRANSFER', 60000.00, @now - INTERVAL 10 DAY, 'COMPLETED',
     'SEED-R06-OLD', @acc8, @acc10);
SET @old_r06_txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R06-OLD');
CALL sp_evaluate_fraud_rules(@old_r06_txn);
SET @old_r06_flag_id = (
    SELECT flag_id FROM FRAUD_FLAG
    WHERE transaction_id = @old_r06_txn AND rule_id = 'R01'
);
INSERT INTO INVESTIGATION
    (flag_id, assigned_staff_id, investigation_status, findings, outcome,
     opened_at, resolved_at)
VALUES
    (@old_r06_flag_id, @sana, 'IN_PROGRESS',
     'Historical high-value transaction reviewed.',
     NULL, @now - INTERVAL 10 DAY, NULL);
UPDATE INVESTIGATION
SET investigation_status = 'RESOLVED', outcome = 'INCONCLUSIVE',
    resolved_at = @now - INTERVAL 9 DAY
WHERE flag_id = @old_r06_flag_id;

-- Five distinct senders deliver funds to the previously flagged ACC1010.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('TRANSFER', 8000.00, @now - INTERVAL 5 HOUR, 'COMPLETED',
     'SEED-R06-01', @acc6, @acc10),
    ('TRANSFER', 8000.00, @now - INTERVAL 4 HOUR, 'COMPLETED',
     'SEED-R06-02', @acc8, @acc10),
    ('TRANSFER', 8000.00, @now - INTERVAL 3 HOUR, 'COMPLETED',
     'SEED-R06-03', @acc9, @acc10),
    ('TRANSFER', 8000.00, @now - INTERVAL 2 HOUR, 'COMPLETED',
     'SEED-R06-04', @acc5, @acc10),
    ('TRANSFER', 8000.00, @now - INTERVAL 1 HOUR, 'COMPLETED',
     'SEED-R06-05', @acc4, @acc10);

-- Daytime baseline activity and three night transfers activate R07.
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
WITH RECURSIVE seq(n) AS (
    SELECT 1
    UNION ALL SELECT n + 1 FROM seq WHERE n < 15
)
SELECT 'WITHDRAWAL', 1200.00,
       TIMESTAMP(DATE(@now - INTERVAL (n + 1) DAY), '10:00:00'),
       'COMPLETED', CONCAT('SEED-R07-DAY-', LPAD(n, 2, '0')),
       @acc6, NULL
FROM seq;
SET @r07_day = DATE(@now + INTERVAL (HOUR(@now) >= 4) DAY);
INSERT INTO BANK_TRANSACTION
    (transaction_type, amount, transaction_time, transaction_status,
     reference_number, from_account_id, to_account_id)
VALUES
    ('TRANSFER', 15000.00,
     TIMESTAMP(@r07_day, '02:10:00'),
     'COMPLETED', 'SEED-R07-NIGHT-01', @acc6, @acc14),
    ('TRANSFER', 15000.00,
     TIMESTAMP(@r07_day, '02:40:00'),
     'COMPLETED', 'SEED-R07-NIGHT-02', @acc6, @acc14),
    ('TRANSFER', 15000.00,
     TIMESTAMP(@r07_day, '03:25:00'),
     'COMPLETED', 'SEED-R07-NIGHT-03', @acc6, @acc14);

-- Evaluate each final scenario transaction through the database rule procedure.
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R01-TRANSFER');
CALL sp_evaluate_fraud_rules(@txn);
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R02-FINAL');
CALL sp_evaluate_fraud_rules(@txn);
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R03-04');
CALL sp_evaluate_fraud_rules(@txn);
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R04-TRANSFER');
CALL sp_evaluate_fraud_rules(@txn);
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R05-12');
CALL sp_evaluate_fraud_rules(@txn);
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R06-05');
CALL sp_evaluate_fraud_rules(@txn);
SET @txn = (SELECT transaction_id FROM BANK_TRANSACTION WHERE reference_number = 'SEED-R07-NIGHT-03');
CALL sp_evaluate_fraud_rules(@txn);

-- Add varied non-final case states for the investigation screens.
SET @r02_flag_id = (SELECT flag_id FROM FRAUD_FLAG WHERE rule_id = 'R02' LIMIT 1);
INSERT INTO INVESTIGATION
    (flag_id, assigned_staff_id, investigation_status, findings, opened_at)
VALUES
    (@r02_flag_id, NULL, 'OPEN', 'Awaiting initial analyst review.',
     @now - INTERVAL 30 MINUTE);
SET @r04_flag_id = (SELECT flag_id FROM FRAUD_FLAG WHERE rule_id = 'R04' LIMIT 1);
INSERT INTO INVESTIGATION
    (flag_id, assigned_staff_id, investigation_status, findings, opened_at)
VALUES
    (@r04_flag_id, @rahul, 'IN_PROGRESS',
     'Additional account activity is being reviewed.',
     @now - INTERVAL 2 HOUR);

WITH expected_rules AS (
    SELECT 'R01' AS rule_id UNION ALL SELECT 'R02' UNION ALL
    SELECT 'R03' UNION ALL SELECT 'R04' UNION ALL SELECT 'R05' UNION ALL
    SELECT 'R06' UNION ALL SELECT 'R07'
)
SELECT expected.rule_id, COUNT(f.flag_id) AS flag_count,
       COUNT(f.flag_id) >= 1 AS requirement_met
FROM expected_rules AS expected
LEFT JOIN FRAUD_FLAG AS f ON f.rule_id = expected.rule_id
GROUP BY expected.rule_id
UNION ALL
SELECT 'MANUAL', COUNT(*), COUNT(*) >= 1
FROM FRAUD_FLAG
WHERE flag_source = 'MANUAL' AND rule_id IS NULL
ORDER BY rule_id;
