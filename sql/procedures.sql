-- ============================================================
-- DATABASE VIEWS, PROCEDURES AND TRIGGERS
-- ============================================================

DROP VIEW IF EXISTS v_transaction_history;
CREATE VIEW v_transaction_history AS
SELECT
    t.transaction_id, t.transaction_type, t.amount, t.transaction_time,
    t.transaction_status, t.reference_number,
    t.from_account_id, fa.account_number AS from_account_number,
    fa.full_name AS from_name,
    t.to_account_id, ta.account_number AS to_account_number,
    ta.full_name AS to_name
FROM BANK_TRANSACTION AS t
LEFT JOIN CUSTOMER_ACCOUNT AS fa
    ON fa.customer_account_id = t.from_account_id
LEFT JOIN CUSTOMER_ACCOUNT AS ta
    ON ta.customer_account_id = t.to_account_id;

DROP VIEW IF EXISTS v_flag_detail;
CREATE VIEW v_flag_detail AS
SELECT
    f.flag_id, f.transaction_id, f.rule_id, f.rule_name,
    f.rule_description, f.rule_type, f.threshold_value, f.flag_source,
    f.reason, f.severity, f.flag_status, f.created_by_staff_id,
    s.staff_name AS creator_name, f.flagged_at,
    t.reference_number, t.transaction_type, t.amount,
    t.transaction_time, t.transaction_status,
    t.from_account_id, t.to_account_id,
    fa.account_number AS from_account_number, fa.full_name AS from_name,
    ta.account_number AS to_account_number, ta.full_name AS to_name,
    i.investigation_id, i.investigation_status, i.assigned_staff_id,
    assigned.staff_name AS assigned_staff_name
FROM FRAUD_FLAG AS f
JOIN BANK_TRANSACTION AS t ON t.transaction_id = f.transaction_id
LEFT JOIN STAFF AS s ON s.staff_id = f.created_by_staff_id
LEFT JOIN CUSTOMER_ACCOUNT AS fa
    ON fa.customer_account_id = t.from_account_id
LEFT JOIN CUSTOMER_ACCOUNT AS ta
    ON ta.customer_account_id = t.to_account_id
LEFT JOIN INVESTIGATION AS i
    ON i.investigation_id = (
        SELECT i2.investigation_id
        FROM INVESTIGATION AS i2
        WHERE i2.flag_id = f.flag_id
        ORDER BY i2.opened_at DESC, i2.investigation_id DESC
        LIMIT 1
    )
LEFT JOIN STAFF AS assigned ON assigned.staff_id = i.assigned_staff_id;

DROP VIEW IF EXISTS v_weekly_account_activity;
CREATE VIEW v_weekly_account_activity AS
SELECT
    a.customer_account_id AS account_id,
    a.account_number,
    a.customer_id,
    YEARWEEK(t.transaction_time, 1) AS activity_week,
    COUNT(*) AS txn_count,
    SUM(t.amount) AS total_amount
FROM CUSTOMER_ACCOUNT AS a
JOIN BANK_TRANSACTION AS t
    ON (t.from_account_id = a.customer_account_id
        AND t.transaction_type IN ('WITHDRAWAL', 'TRANSFER'))
    OR (t.to_account_id = a.customer_account_id
        AND t.transaction_type = 'DEPOSIT')
WHERE t.transaction_status IN ('COMPLETED', 'UNDER_REVIEW', 'REVERSED')
GROUP BY a.customer_account_id, a.account_number, a.customer_id,
         YEARWEEK(t.transaction_time, 1);

DELIMITER //

DROP PROCEDURE IF EXISTS sp_evaluate_fraud_rules//
CREATE PROCEDURE sp_evaluate_fraud_rules(IN p_txn_id BIGINT)
BEGIN
    -- Rule thresholds and deduplication intervals are days unless noted.
    DECLARE c_r01_amount DECIMAL(15,2) DEFAULT 50000.00;
    DECLARE c_r01_high DECIMAL(15,2) DEFAULT 200000.00;
    DECLARE c_r02_multiplier DECIMAL(5,2) DEFAULT 3.00;
    DECLARE c_r03_window_minutes INT DEFAULT 60;
    DECLARE c_r03_min_count INT DEFAULT 3;
    DECLARE c_r03_min_total DECIMAL(15,2) DEFAULT 25000.00;
    DECLARE c_r05_min_count INT DEFAULT 5;
    DECLARE c_r06_min_senders INT DEFAULT 4;
    DECLARE c_r07_night_count INT DEFAULT 3;

    DECLARE v_type VARCHAR(20);
    DECLARE v_time DATETIME;
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_from BIGINT;
    DECLARE v_to BIGINT;
    DECLARE v_subject BIGINT;
    DECLARE v_count INT DEFAULT 0;
    DECLARE v_distinct INT DEFAULT 0;
    DECLARE v_total DECIMAL(15,2) DEFAULT 0;
    DECLARE v_avg DECIMAL(15,2) DEFAULT 0;
    DECLARE v_high_conflict INT DEFAULT 0;
    DECLARE v_exists INT DEFAULT 0;
    DECLARE v_night_count INT DEFAULT 0;
    DECLARE v_day_count INT DEFAULT 0;
    DECLARE v_previous DATETIME;
    DECLARE v_severity VARCHAR(20);
    DECLARE v_reason TEXT;
    DECLARE CONTINUE HANDLER FOR 1062 BEGIN END;

    SELECT transaction_type, transaction_time, amount,
           from_account_id, to_account_id
      INTO v_type, v_time, v_amount, v_from, v_to
    FROM BANK_TRANSACTION
    WHERE transaction_id = p_txn_id;

    SET v_subject = IF(v_type = 'DEPOSIT', v_to, v_from);

    IF v_amount >= c_r01_amount THEN
        SET v_severity = IF(v_amount >= c_r01_high, 'HIGH', 'MEDIUM');
        SET v_reason = CONCAT('Transaction amount ', FORMAT(v_amount, 2),
                              ' is at or above the ', FORMAT(c_r01_amount, 2),
                              ' high-amount threshold.');
        INSERT INTO FRAUD_FLAG
            (transaction_id, rule_id, rule_name, rule_description, rule_type,
             threshold_value, flag_source, reason, severity)
        VALUES
            (p_txn_id, 'R01', 'HIGH_AMOUNT',
             'A transaction exceeds the configured high-amount threshold.',
             'AMOUNT', c_r01_amount, 'AUTOMATIC', v_reason, v_severity);
    END IF;

    SELECT COUNT(*) INTO v_count
    FROM BANK_TRANSACTION
    WHERE transaction_time > v_time - INTERVAL 7 DAY
      AND transaction_time <= v_time
      AND transaction_status <> 'FAILED'
      AND (
          (v_type = 'DEPOSIT' AND to_account_id = v_subject)
          OR (v_type <> 'DEPOSIT' AND from_account_id = v_subject)
      );
    SELECT COUNT(*) / 4 INTO v_avg
    FROM BANK_TRANSACTION
    WHERE transaction_time > v_time - INTERVAL 35 DAY
      AND transaction_time <= v_time - INTERVAL 7 DAY
      AND transaction_status <> 'FAILED'
      AND (
          (v_type = 'DEPOSIT' AND to_account_id = v_subject)
          OR (v_type <> 'DEPOSIT' AND from_account_id = v_subject)
      );
    SELECT COUNT(*) INTO v_exists
    FROM FRAUD_FLAG f
    JOIN BANK_TRANSACTION prior_tx ON prior_tx.transaction_id = f.transaction_id
    WHERE f.rule_id = 'R02'
      AND prior_tx.transaction_time > v_time - INTERVAL 7 DAY
      AND (
          (v_type = 'DEPOSIT' AND prior_tx.to_account_id = v_subject)
          OR (v_type <> 'DEPOSIT' AND prior_tx.from_account_id = v_subject)
      );
    IF v_count >= 10 AND v_count >= c_r02_multiplier * GREATEST(v_avg, 1)
       AND v_exists = 0 THEN
        SET v_reason = CONCAT(v_count, ' transactions in the last 7 days vs ',
                              FORMAT(v_avg, 2),
                              ' average transactions per prior week.');
        INSERT INTO FRAUD_FLAG
            (transaction_id, rule_id, rule_name, rule_description, rule_type,
             threshold_value, flag_source, reason, severity)
        VALUES
            (p_txn_id, 'R02', 'WEEKLY_SPIKE',
             'Recent transaction volume is at least three times baseline.',
             'VELOCITY', c_r02_multiplier, 'AUTOMATIC', v_reason, 'HIGH');
    END IF;

    IF v_type IN ('WITHDRAWAL', 'TRANSFER') THEN
        SELECT COUNT(*), COALESCE(SUM(amount), 0) INTO v_count, v_total
        FROM BANK_TRANSACTION
        WHERE from_account_id = v_subject
          AND transaction_type IN ('WITHDRAWAL', 'TRANSFER')
          AND transaction_status <> 'FAILED'
          AND transaction_time > v_time - INTERVAL 60 MINUTE
          AND transaction_time <= v_time;
        SELECT MAX(transaction_time) INTO v_previous
        FROM BANK_TRANSACTION
        WHERE from_account_id = v_subject
          AND transaction_time <= v_time - INTERVAL 60 MINUTE
          AND transaction_status <> 'FAILED';
        SELECT COUNT(*) INTO v_exists
        FROM FRAUD_FLAG f
        JOIN BANK_TRANSACTION prior_tx ON prior_tx.transaction_id = f.transaction_id
        WHERE f.rule_id = 'R03'
          AND prior_tx.from_account_id = v_subject
          AND prior_tx.transaction_time > v_time - INTERVAL 1 DAY;
        IF (v_previous IS NULL OR v_previous <= v_time - INTERVAL 21 DAY)
           AND v_count >= c_r03_min_count
           AND v_total >= c_r03_min_total AND v_exists = 0 THEN
            SET v_reason = CONCAT(v_count, ' outgoing transactions totalling ',
                                  FORMAT(v_total, 2),
                                  ' in the last hour after account inactivity.');
            INSERT INTO FRAUD_FLAG
                (transaction_id, rule_id, rule_name, rule_description, rule_type,
                 threshold_value, flag_source, reason, severity)
            VALUES
                (p_txn_id, 'R03', 'DORMANT_REACTIVATION',
                 'A dormant account resumed with clustered outgoing transfers.',
                 'BEHAVIOUR', c_r03_min_total, 'AUTOMATIC', v_reason, 'HIGH');
        END IF;
    END IF;

    IF v_type = 'TRANSFER' THEN
        SELECT COUNT(*), MAX(f.severity = 'CRITICAL' OR f.severity = 'HIGH')
          INTO v_count, v_high_conflict
        FROM BANK_TRANSACTION old_tx
        JOIN FRAUD_FLAG f ON f.transaction_id = old_tx.transaction_id
        WHERE old_tx.to_account_id = v_to
          AND old_tx.transaction_time < v_time
          AND f.flag_status IN ('OPEN', 'UNDER_INVESTIGATION', 'CONFIRMED');
        IF v_count > 0 THEN
            SET v_severity = IF(v_high_conflict > 0, 'HIGH', 'MEDIUM');
            SET v_reason = CONCAT('Recipient account participated in ',
                                  v_count, ' earlier actively flagged transaction(s).');
            INSERT INTO FRAUD_FLAG
                (transaction_id, rule_id, rule_name, rule_description, rule_type,
                 threshold_value, flag_source, reason, severity)
            VALUES
                (p_txn_id, 'R04', 'FLAGGED_RECIPIENT',
                 'The recipient has earlier active fraud-flag history.',
                 'NETWORK', 0, 'AUTOMATIC', v_reason, v_severity);
        END IF;
    END IF;

    IF v_type IN ('WITHDRAWAL', 'TRANSFER') THEN
        SELECT COUNT(*) INTO v_count
        FROM BANK_TRANSACTION
        WHERE from_account_id = v_subject
          AND transaction_type IN ('WITHDRAWAL', 'TRANSFER')
          AND transaction_status <> 'FAILED'
          AND amount >= 9000 AND amount < 10000
          AND transaction_time > v_time - INTERVAL 24 HOUR
          AND transaction_time <= v_time;
        SELECT COUNT(*) INTO v_exists
        FROM FRAUD_FLAG f
        JOIN BANK_TRANSACTION old_tx ON old_tx.transaction_id = f.transaction_id
        WHERE f.rule_id = 'R05' AND old_tx.from_account_id = v_subject
          AND old_tx.transaction_time > v_time - INTERVAL 1 DAY;
        IF v_count >= c_r05_min_count AND v_exists = 0 THEN
            SET v_reason = CONCAT(v_count,
                ' outgoing transactions between 9000.00 and 9999.99 in 24 hours.');
            INSERT INTO FRAUD_FLAG
                (transaction_id, rule_id, rule_name, rule_description, rule_type,
                 threshold_value, flag_source, reason, severity)
            VALUES
                (p_txn_id, 'R05', 'STRUCTURING',
                 'Multiple transactions are just below the review threshold.',
                 'PATTERN', 10000, 'AUTOMATIC', v_reason, 'HIGH');
        END IF;
    END IF;

    IF v_type = 'TRANSFER' THEN
        SELECT COUNT(DISTINCT sender.customer_id) INTO v_distinct
        FROM BANK_TRANSACTION fan
        JOIN CUSTOMER_ACCOUNT sender
            ON sender.customer_account_id = fan.from_account_id
        WHERE fan.to_account_id = v_to
          AND fan.transaction_type = 'TRANSFER'
          AND fan.transaction_status <> 'FAILED'
          AND fan.transaction_time > v_time - INTERVAL 24 HOUR
          AND fan.transaction_time <= v_time;
        SELECT COUNT(*) INTO v_exists
        FROM FRAUD_FLAG f
        JOIN BANK_TRANSACTION old_tx ON old_tx.transaction_id = f.transaction_id
        WHERE (old_tx.from_account_id = v_to OR old_tx.to_account_id = v_to)
          AND old_tx.transaction_time < v_time;
        SELECT COUNT(*) INTO v_count
        FROM FRAUD_FLAG f
        JOIN BANK_TRANSACTION old_tx ON old_tx.transaction_id = f.transaction_id
        WHERE f.rule_id = 'R06'
          AND old_tx.to_account_id = v_to
          AND old_tx.transaction_time > v_time - INTERVAL 1 DAY;
        IF v_distinct >= c_r06_min_senders AND v_exists > 0 AND v_count = 0 THEN
            SET v_reason = CONCAT(v_distinct,
                ' distinct customer accounts sent to a recipient with prior flag history.');
            INSERT INTO FRAUD_FLAG
                (transaction_id, rule_id, rule_name, rule_description, rule_type,
                 threshold_value, flag_source, reason, severity)
            VALUES
                (p_txn_id, 'R06', 'FAN_IN',
                 'Many distinct customers sent funds to a previously flagged recipient.',
                 'NETWORK', c_r06_min_senders, 'AUTOMATIC', v_reason, 'HIGH');
        END IF;
    END IF;

    IF HOUR(v_time) BETWEEN 0 AND 4
       AND v_type IN ('WITHDRAWAL', 'TRANSFER') THEN
        SELECT COUNT(*),
               SUM(HOUR(transaction_time) BETWEEN 0 AND 4)
          INTO v_day_count, v_night_count
        FROM BANK_TRANSACTION
        WHERE from_account_id = v_subject
          AND transaction_time > v_time - INTERVAL 30 DAY
          AND transaction_time <= v_time - INTERVAL 6 HOUR
          AND transaction_status <> 'FAILED';
        SELECT COUNT(*) INTO v_count
        FROM BANK_TRANSACTION
        WHERE from_account_id = v_subject
          AND transaction_time > v_time - INTERVAL 6 HOUR
          AND transaction_time <= v_time
          AND HOUR(transaction_time) BETWEEN 0 AND 4
          AND transaction_status <> 'FAILED';
        SELECT COUNT(*) INTO v_exists
        FROM FRAUD_FLAG f
        JOIN BANK_TRANSACTION old_tx ON old_tx.transaction_id = f.transaction_id
        WHERE f.rule_id = 'R07' AND old_tx.from_account_id = v_subject
          AND old_tx.transaction_time > v_time - INTERVAL 1 DAY;
        IF v_day_count >= 10 AND v_night_count = 0
           AND v_count >= c_r07_night_count AND v_exists = 0 THEN
            SET v_reason = CONCAT(v_count,
                ' night transactions in 6 hours; prior 30-day activity was ',
                v_day_count, ' transactions with none during night hours.');
            INSERT INTO FRAUD_FLAG
                (transaction_id, rule_id, rule_name, rule_description, rule_type,
                 threshold_value, flag_source, reason, severity)
            VALUES
                (p_txn_id, 'R07', 'ODD_HOURS',
                 'Night activity is unusual compared with the account history.',
                 'BEHAVIOUR', c_r07_night_count, 'AUTOMATIC', v_reason, 'MEDIUM');
        END IF;
    END IF;
END//

DROP PROCEDURE IF EXISTS sp_make_transaction//
CREATE PROCEDURE sp_make_transaction(
    IN p_type VARCHAR(20),
    IN p_from_account_id BIGINT,
    IN p_to_account_id BIGINT,
    IN p_amount DECIMAL(15,2),
    OUT p_txn_id BIGINT,
    OUT p_result VARCHAR(25),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);
    DECLARE v_from_balance DECIMAL(15,2) DEFAULT NULL;
    DECLARE v_to_balance DECIMAL(15,2) DEFAULT NULL;
    DECLARE v_first_id BIGINT;
    DECLARE v_second_id BIGINT;
    DECLARE v_reason VARCHAR(255) DEFAULT NULL;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SET v_first_id = LEAST(COALESCE(p_from_account_id, p_to_account_id),
                           COALESCE(p_to_account_id, p_from_account_id));
    SET v_second_id = NULLIF(GREATEST(COALESCE(p_from_account_id, p_to_account_id),
                                      COALESCE(p_to_account_id, p_from_account_id)),
                             v_first_id);
    IF v_first_id IS NOT NULL THEN
        SELECT customer_account_id INTO @locked_account
        FROM CUSTOMER_ACCOUNT WHERE customer_account_id = v_first_id FOR UPDATE;
    END IF;
    IF v_second_id IS NOT NULL THEN
        SELECT customer_account_id INTO @locked_account
        FROM CUSTOMER_ACCOUNT WHERE customer_account_id = v_second_id FOR UPDATE;
    END IF;

    IF p_type NOT IN ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER') THEN
        SET v_reason = 'Select a valid transaction type.';
    ELSEIF p_amount IS NULL OR p_amount <= 0 THEN
        SET v_reason = 'Enter an amount greater than zero.';
    ELSEIF p_type IN ('WITHDRAWAL', 'TRANSFER') THEN
        SELECT account_status, balance INTO v_status, v_from_balance
        FROM CUSTOMER_ACCOUNT WHERE customer_account_id = p_from_account_id;
        IF v_status IS NULL THEN
            SET v_reason = 'The source account was not found.';
        ELSEIF v_status <> 'ACTIVE' THEN
            SET v_reason = 'The source account is not active.';
        ELSEIF v_from_balance < p_amount THEN
            SET v_reason = 'There are insufficient funds for this transaction.';
        END IF;
    END IF;

    IF v_reason IS NULL AND p_type IN ('DEPOSIT', 'TRANSFER') THEN
        SELECT account_status INTO v_status
        FROM CUSTOMER_ACCOUNT WHERE customer_account_id = p_to_account_id;
        IF v_status IS NULL THEN
            SET v_reason = 'The destination account was not found.';
        ELSEIF v_status <> 'ACTIVE' THEN
            SET v_reason = 'The destination account is not active.';
        END IF;
    END IF;

    IF p_type = 'TRANSFER' AND p_from_account_id = p_to_account_id THEN
        SET v_reason = 'Choose a different destination account.';
    END IF;

    IF v_reason IS NOT NULL THEN
        SET @failed_from = IF(p_type = 'DEPOSIT', NULL, p_from_account_id);
        SET @failed_to = IF(p_type = 'WITHDRAWAL', NULL, p_to_account_id);
        INSERT INTO BANK_TRANSACTION
            (transaction_type, amount, transaction_status, reference_number,
             from_account_id, to_account_id)
        VALUES
            (p_type, GREATEST(COALESCE(p_amount, 0), 0.01), 'FAILED',
             CONCAT('TXN', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'),
                    LPAD(UUID_SHORT() % 100000, 5, '0')),
             @failed_from, @failed_to);
        SET p_txn_id = LAST_INSERT_ID();
        INSERT INTO TRANSACTION_AUDIT
            (transaction_id, staff_id, action_type, new_status, action_details)
        VALUES
            (p_txn_id, @app_staff_id, 'TRANSACTION_REJECTED', 'FAILED', v_reason);
        SET p_result = 'FAILED';
        SET p_message = v_reason;
        COMMIT;
    ELSE
        INSERT INTO BANK_TRANSACTION
            (transaction_type, amount, transaction_status, reference_number,
             from_account_id, to_account_id)
        VALUES
            (p_type, p_amount, 'PENDING',
             CONCAT('TXN', DATE_FORMAT(NOW(), '%Y%m%d%H%i%s'),
                    LPAD(UUID_SHORT() % 100000, 5, '0')),
             IF(p_type = 'DEPOSIT', NULL, p_from_account_id),
             IF(p_type = 'WITHDRAWAL', NULL, p_to_account_id));
        SET p_txn_id = LAST_INSERT_ID();
        IF p_type IN ('WITHDRAWAL', 'TRANSFER') THEN
            UPDATE CUSTOMER_ACCOUNT
            SET balance = balance - p_amount
            WHERE customer_account_id = p_from_account_id;
        END IF;
        IF p_type IN ('DEPOSIT', 'TRANSFER') THEN
            UPDATE CUSTOMER_ACCOUNT
            SET balance = balance + p_amount
            WHERE customer_account_id = p_to_account_id;
        END IF;
        UPDATE BANK_TRANSACTION
        SET transaction_status = 'COMPLETED'
        WHERE transaction_id = p_txn_id;
        CALL sp_evaluate_fraud_rules(p_txn_id);
        SELECT transaction_status INTO p_result
        FROM BANK_TRANSACTION WHERE transaction_id = p_txn_id;
        SET p_message = IF(p_result = 'UNDER_REVIEW',
            'Transaction completed and is under review.',
            'Transaction completed successfully.');
        COMMIT;
    END IF;
END//

DROP PROCEDURE IF EXISTS sp_weekly_analysis//
CREATE PROCEDURE sp_weekly_analysis(OUT p_new_flags INT)
BEGIN
    DECLARE v_done BOOLEAN DEFAULT FALSE;
    DECLARE v_txn_id BIGINT;
    DECLARE v_before INT DEFAULT 0;
    DECLARE v_after INT DEFAULT 0;
    DECLARE txn_cursor CURSOR FOR
        SELECT transaction_id FROM BANK_TRANSACTION
        WHERE transaction_time >= NOW() - INTERVAL 7 DAY
          AND transaction_time <= NOW()
        ORDER BY transaction_id;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_done = TRUE;
    DECLARE CONTINUE HANDLER FOR 1062 BEGIN END;

    SET p_new_flags = 0;
    OPEN txn_cursor;
    read_loop: LOOP
        FETCH txn_cursor INTO v_txn_id;
        IF v_done THEN
            LEAVE read_loop;
        END IF;
        SELECT COUNT(*) INTO v_before
        FROM FRAUD_FLAG WHERE transaction_id = v_txn_id;
        CALL sp_evaluate_fraud_rules(v_txn_id);
        SELECT COUNT(*) INTO v_after
        FROM FRAUD_FLAG WHERE transaction_id = v_txn_id;
        SET p_new_flags = p_new_flags + GREATEST(v_after - v_before, 0);
    END LOOP;
    CLOSE txn_cursor;
END//

DROP PROCEDURE IF EXISTS sp_reverse_transaction//
CREATE PROCEDURE sp_reverse_transaction(
    IN p_txn_id BIGINT,
    IN p_staff_id BIGINT,
    OUT p_result VARCHAR(25),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(25);
    DECLARE v_type VARCHAR(20);
    DECLARE v_amount DECIMAL(15,2);
    DECLARE v_from BIGINT;
    DECLARE v_to BIGINT;
    DECLARE v_from_balance DECIMAL(15,2);
    DECLARE v_to_balance DECIMAL(15,2);
    DECLARE v_flag_count INT DEFAULT 0;
    DECLARE v_first BIGINT;
    DECLARE v_second BIGINT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
    SELECT transaction_status, transaction_type, amount,
           from_account_id, to_account_id
      INTO v_status, v_type, v_amount, v_from, v_to
    FROM BANK_TRANSACTION WHERE transaction_id = p_txn_id FOR UPDATE;

    SELECT COUNT(*) INTO v_flag_count
    FROM FRAUD_FLAG
    WHERE transaction_id = p_txn_id AND flag_status = 'CONFIRMED';
    IF v_status NOT IN ('COMPLETED', 'UNDER_REVIEW') OR v_flag_count = 0 THEN
        SET p_result = 'FAILED';
        SET p_message = 'Only completed or under-review transactions with a confirmed flag can be reversed.';
        ROLLBACK;
    ELSE
        SET v_first = LEAST(COALESCE(v_from, v_to), COALESCE(v_to, v_from));
        SET v_second = NULLIF(GREATEST(COALESCE(v_from, v_to),
                                       COALESCE(v_to, v_from)), v_first);
        IF v_first IS NOT NULL THEN
            SELECT customer_account_id INTO @locked_account
            FROM CUSTOMER_ACCOUNT WHERE customer_account_id = v_first FOR UPDATE;
        END IF;
        IF v_second IS NOT NULL THEN
            SELECT customer_account_id INTO @locked_account
            FROM CUSTOMER_ACCOUNT WHERE customer_account_id = v_second FOR UPDATE;
        END IF;
        IF v_type IN ('DEPOSIT', 'TRANSFER') THEN
            SELECT balance INTO v_to_balance
            FROM CUSTOMER_ACCOUNT WHERE customer_account_id = v_to;
        END IF;
        IF v_type IN ('WITHDRAWAL', 'TRANSFER') THEN
            SELECT balance INTO v_from_balance
            FROM CUSTOMER_ACCOUNT WHERE customer_account_id = v_from;
        END IF;

        IF (v_type IN ('DEPOSIT', 'TRANSFER') AND v_to_balance < v_amount) THEN
            SET p_result = 'FAILED';
            SET p_message = 'The receiving account no longer has enough funds to reverse this transaction.';
            ROLLBACK;
        ELSE
            IF v_type IN ('DEPOSIT', 'TRANSFER') THEN
                UPDATE CUSTOMER_ACCOUNT SET balance = balance - v_amount
                WHERE customer_account_id = v_to;
            END IF;
            IF v_type IN ('WITHDRAWAL', 'TRANSFER') THEN
                UPDATE CUSTOMER_ACCOUNT SET balance = balance + v_amount
                WHERE customer_account_id = v_from;
            END IF;
            UPDATE BANK_TRANSACTION SET transaction_status = 'REVERSED'
            WHERE transaction_id = p_txn_id;
            INSERT INTO TRANSACTION_AUDIT
                (transaction_id, staff_id, action_type, old_status,
                 new_status, action_details)
            VALUES
                (p_txn_id, p_staff_id, 'TRANSACTION_REVERSED',
                 v_status, 'REVERSED', 'Reversed after confirmed fraud review.');
            SET p_result = 'REVERSED';
            SET p_message = 'Transaction reversed successfully.';
            COMMIT;
        END IF;
    END IF;
END//

DROP TRIGGER IF EXISTS trg_txn_ai//
CREATE TRIGGER trg_txn_ai AFTER INSERT ON BANK_TRANSACTION
FOR EACH ROW
BEGIN
    INSERT INTO TRANSACTION_AUDIT
        (transaction_id, staff_id, action_type, new_status,
         action_details, action_time)
    VALUES
        (NEW.transaction_id, @app_staff_id, 'TRANSACTION_CREATED',
         NEW.transaction_status,
         CONCAT('type=', NEW.transaction_type, '; amount=', NEW.amount,
                '; reference=', NEW.reference_number),
         NEW.transaction_time);
END//

DROP TRIGGER IF EXISTS trg_txn_au//
CREATE TRIGGER trg_txn_au AFTER UPDATE ON BANK_TRANSACTION
FOR EACH ROW
BEGIN
    IF OLD.transaction_status <> NEW.transaction_status THEN
        INSERT INTO TRANSACTION_AUDIT
            (transaction_id, staff_id, action_type, old_status, new_status,
             action_details, action_time)
        VALUES
            (NEW.transaction_id, @app_staff_id, 'STATUS_CHANGED',
             OLD.transaction_status, NEW.transaction_status,
             'Transaction status changed.', NOW());
    END IF;
END//

DROP TRIGGER IF EXISTS trg_flag_ai//
CREATE TRIGGER trg_flag_ai AFTER INSERT ON FRAUD_FLAG
FOR EACH ROW
BEGIN
    INSERT INTO TRANSACTION_AUDIT
        (transaction_id, staff_id, action_type, new_status,
         action_details, action_time)
    VALUES
        (NEW.transaction_id, NEW.created_by_staff_id, 'FLAG_CREATED',
         NEW.flag_status,
         CONCAT('rule=', NEW.rule_name, '; severity=', NEW.severity,
                '; source=', NEW.flag_source),
         NEW.flagged_at);
    IF (SELECT transaction_status FROM BANK_TRANSACTION
        WHERE transaction_id = NEW.transaction_id) = 'COMPLETED' THEN
        UPDATE BANK_TRANSACTION
        SET transaction_status = 'UNDER_REVIEW'
        WHERE transaction_id = NEW.transaction_id;
    END IF;
END//

DROP TRIGGER IF EXISTS trg_flag_au//
CREATE TRIGGER trg_flag_au AFTER UPDATE ON FRAUD_FLAG
FOR EACH ROW
BEGIN
    IF OLD.flag_status <> NEW.flag_status THEN
        INSERT INTO TRANSACTION_AUDIT
            (transaction_id, staff_id, action_type, old_status, new_status,
             action_details, action_time)
        VALUES
            (NEW.transaction_id, @app_staff_id, 'FLAG_STATUS_CHANGED',
             OLD.flag_status, NEW.flag_status, 'Fraud flag status changed.',
             NOW());
    END IF;
END//

DROP TRIGGER IF EXISTS trg_inv_ai//
CREATE TRIGGER trg_inv_ai AFTER INSERT ON INVESTIGATION
FOR EACH ROW
BEGIN
    DECLARE v_transaction_id BIGINT;
    SELECT transaction_id INTO v_transaction_id
    FROM FRAUD_FLAG WHERE flag_id = NEW.flag_id;
    INSERT INTO TRANSACTION_AUDIT
        (transaction_id, staff_id, action_type, new_status,
         action_details, action_time)
    VALUES
        (v_transaction_id, @app_staff_id, 'INVESTIGATION_OPENED',
         NEW.investigation_status,
         CONCAT('investigation_id=', NEW.investigation_id), NEW.opened_at);
    UPDATE FRAUD_FLAG SET flag_status = 'UNDER_INVESTIGATION'
    WHERE flag_id = NEW.flag_id
      AND flag_status IN ('OPEN', 'UNDER_INVESTIGATION');
END//

DROP TRIGGER IF EXISTS trg_inv_au//
CREATE TRIGGER trg_inv_au AFTER UPDATE ON INVESTIGATION
FOR EACH ROW
BEGIN
    DECLARE v_transaction_id BIGINT;
    IF OLD.investigation_status <> NEW.investigation_status
       OR NOT (OLD.outcome <=> NEW.outcome)
       OR NOT (OLD.assigned_staff_id <=> NEW.assigned_staff_id) THEN
        SELECT transaction_id INTO v_transaction_id
        FROM FRAUD_FLAG WHERE flag_id = NEW.flag_id;
        INSERT INTO TRANSACTION_AUDIT
            (transaction_id, staff_id, action_type, old_status, new_status,
             action_details)
        VALUES
            (v_transaction_id, @app_staff_id, 'INVESTIGATION_UPDATED',
             OLD.investigation_status, NEW.investigation_status,
             CONCAT('outcome=', COALESCE(NEW.outcome, 'NULL')));
    END IF;

    IF NEW.investigation_status IN ('RESOLVED', 'CLOSED')
       AND NEW.outcome IS NOT NULL THEN
        UPDATE FRAUD_FLAG
        SET flag_status = CASE NEW.outcome
            WHEN 'CONFIRMED_FRAUD' THEN 'CONFIRMED'
            WHEN 'LEGITIMATE' THEN 'FALSE_POSITIVE'
            WHEN 'INCONCLUSIVE' THEN 'CLOSED'
        END
        WHERE flag_id = NEW.flag_id;

        IF NEW.outcome = 'LEGITIMATE' THEN
            UPDATE BANK_TRANSACTION t
            JOIN FRAUD_FLAG current_flag
                ON current_flag.transaction_id = t.transaction_id
            SET t.transaction_status = 'COMPLETED'
            WHERE current_flag.flag_id = NEW.flag_id
              AND t.transaction_status = 'UNDER_REVIEW'
              AND NOT EXISTS (
                  SELECT 1
                  FROM FRAUD_FLAG other_flag
                  WHERE other_flag.transaction_id = t.transaction_id
                    AND other_flag.flag_id <> NEW.flag_id
                    AND other_flag.flag_status IN
                        ('OPEN', 'UNDER_INVESTIGATION', 'CONFIRMED')
              );
        END IF;
    END IF;
END//

DELIMITER ;

DELIMITER //

DELIMITER //

DROP PROCEDURE IF EXISTS sp_register_customer//
CREATE PROCEDURE sp_register_customer(
    IN p_full_name VARCHAR(120),
    IN p_date_of_birth DATE,
    IN p_email VARCHAR(150),
    IN p_phone VARCHAR(20),
    IN p_address VARCHAR(255),
    IN p_account_type VARCHAR(30),
    IN p_password_hash VARCHAR(255),
    IN p_initial_deposit DECIMAL(15,2),
    OUT p_customer_id VARCHAR(30),
    OUT p_account_number VARCHAR(30),
    OUT p_result VARCHAR(30),
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_lock_acquired INT DEFAULT 0;
    DECLARE v_max_cust_num INT DEFAULT 0;
    DECLARE v_next_cust_num INT DEFAULT 0;
    DECLARE v_max_acc_num INT DEFAULT 0;
    DECLARE v_next_acc_num INT DEFAULT 0;
    DECLARE v_existing_count INT DEFAULT 0;
    DECLARE v_new_account_id BIGINT DEFAULT NULL;
    DECLARE v_dep_txn_id BIGINT DEFAULT NULL;
    DECLARE v_dep_result VARCHAR(25) DEFAULT NULL;
    DECLARE v_dep_message VARCHAR(255) DEFAULT NULL;
    DECLARE v_dup_key TINYINT DEFAULT 0;

    DECLARE CONTINUE HANDLER FOR 1062
    BEGIN
        SET v_dup_key = 1;
    END;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        IF v_lock_acquired = 1 THEN
            DO RELEASE_LOCK('register_customer');
        END IF;
        RESIGNAL;
    END;

    SET p_customer_id = NULL;
    SET p_account_number = NULL;
    SET p_result = 'FAILED';

    -- Basic business validations
    IF p_full_name IS NULL OR TRIM(p_full_name) = '' THEN
        SET p_message = 'Full name is required.';
    ELSEIF p_email IS NULL OR TRIM(p_email) = '' THEN
        SET p_message = 'Email is required.';
    ELSEIF p_password_hash IS NULL OR TRIM(p_password_hash) = '' THEN
        SET p_message = 'Password is required.';
    ELSEIF p_account_type NOT IN ('SAVINGS', 'CURRENT', 'SALARY') THEN
        SET p_message = 'Invalid account type. Choose SAVINGS, CURRENT, or SALARY.';
    ELSEIF p_date_of_birth IS NULL THEN
        SET p_message = 'Date of birth is required.';
    ELSEIF p_date_of_birth > CURDATE() THEN
        SET p_message = 'Date of birth cannot be in the future.';
    ELSEIF p_date_of_birth > CURDATE() - INTERVAL 18 YEAR THEN
        SET p_message = 'Applicant must be at least 18 years old.';
    ELSEIF p_initial_deposit IS NOT NULL AND p_initial_deposit < 0 THEN
        SET p_message = 'Initial deposit cannot be negative.';
    ELSE
        -- Acquire serialized lock (5 second timeout)
        SELECT GET_LOCK('register_customer', 5) INTO v_lock_acquired;
        IF v_lock_acquired <> 1 THEN
            SET p_message = 'Could not acquire registration lock. Please try again.';
        ELSE
            -- Check for duplicate email
            SELECT COUNT(*) INTO v_existing_count
            FROM CUSTOMER_ACCOUNT
            WHERE LOWER(email) = LOWER(TRIM(p_email));

            IF v_existing_count > 0 THEN
                SET p_message = 'An account with this email already exists.';
                DO RELEASE_LOCK('register_customer');
                SET v_lock_acquired = 0;
            ELSE
                -- Check for duplicate phone if provided
                IF p_phone IS NOT NULL AND TRIM(p_phone) <> '' THEN
                    SELECT COUNT(*) INTO v_existing_count
                    FROM CUSTOMER_ACCOUNT
                    WHERE phone = TRIM(p_phone);
                ELSE
                    SET v_existing_count = 0;
                END IF;

                IF v_existing_count > 0 THEN
                    SET p_message = 'An account with this phone number already exists.';
                    DO RELEASE_LOCK('register_customer');
                    SET v_lock_acquired = 0;
                ELSE
                    -- Generate sequential Customer ID like CUST011
                    SELECT IFNULL(MAX(CAST(SUBSTRING(customer_id, 5) AS UNSIGNED)), 0)
                    INTO v_max_cust_num
                    FROM CUSTOMER_ACCOUNT
                    WHERE customer_id REGEXP '^CUST[0-9]+$';

                    SET v_next_cust_num = v_max_cust_num + 1;
                    SET p_customer_id = CONCAT('CUST', LPAD(v_next_cust_num, 3, '0'));

                    -- Generate sequential Account Number like ACC1012
                    SELECT IFNULL(MAX(CAST(SUBSTRING(account_number, 4) AS UNSIGNED)), 0)
                    INTO v_max_acc_num
                    FROM CUSTOMER_ACCOUNT
                    WHERE account_number REGEXP '^ACC[0-9]+$';

                    SET v_next_acc_num = v_max_acc_num + 1;
                    SET p_account_number = CONCAT('ACC', v_next_acc_num);

                    -- Wrap in transaction
                    START TRANSACTION;
                    SET v_dup_key = 0;

                    INSERT INTO CUSTOMER_ACCOUNT (
                        customer_id, full_name, date_of_birth, email, phone, address,
                        password_hash, account_number, account_type, balance, account_status,
                        opened_at, holder_role, start_date
                    ) VALUES (
                        p_customer_id, TRIM(p_full_name), p_date_of_birth, TRIM(p_email),
                        NULLIF(TRIM(p_phone), ''), NULLIF(TRIM(p_address), ''),
                        p_password_hash, p_account_number, p_account_type, 0.00, 'ACTIVE',
                        NOW(), 'PRIMARY', CURDATE()
                    );

                    IF v_dup_key = 1 THEN
                        ROLLBACK;
                        DO RELEASE_LOCK('register_customer');
                        SET v_lock_acquired = 0;
                        SET p_customer_id = NULL;
                        SET p_account_number = NULL;
                        SET p_result = 'FAILED';
                        SET p_message = 'Duplicate account number generated. Please retry.';
                    ELSE
                        SET v_new_account_id = LAST_INSERT_ID();
                        COMMIT;
                        DO RELEASE_LOCK('register_customer');
                        SET v_lock_acquired = 0;

                        SET p_result = 'CREATED';
                        SET p_message = 'Account created successfully.';

                        -- Process initial deposit if provided
                        IF p_initial_deposit IS NOT NULL AND p_initial_deposit > 0 THEN
                            CALL sp_make_transaction(
                                'DEPOSIT',
                                NULL,
                                v_new_account_id,
                                p_initial_deposit,
                                v_dep_txn_id,
                                v_dep_result,
                                v_dep_message
                            );
                            IF v_dep_result = 'FAILED' THEN
                                SET p_message = CONCAT('Account created, but initial deposit failed: ', v_dep_message);
                            END IF;
                        END IF;
                    END IF;
                END IF;
            END IF;
        END IF;
    END IF;
END//

DELIMITER ;
