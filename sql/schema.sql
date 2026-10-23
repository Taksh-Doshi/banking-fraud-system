
-- ============================================================
-- BANKING TRANSACTION & FRAUD FLAG MANAGEMENT SYSTEM
-- Database schema: six core tables
-- Requires MySQL 8.0.16+ for enforced CHECK constraints
-- ============================================================

CREATE DATABASE IF NOT EXISTS banking_fraud_db;
USE banking_fraud_db;

-- ============================================================
-- 1. CUSTOMER_ACCOUNT
-- Stores customer details and their account/holder information.
-- ============================================================

CREATE TABLE IF NOT EXISTS CUSTOMER_ACCOUNT (
    customer_account_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    customer_id VARCHAR(30) NOT NULL,
    full_name VARCHAR(120) NOT NULL,
    date_of_birth DATE,
    email VARCHAR(150),
    phone VARCHAR(20),
    address VARCHAR(255),

    account_number VARCHAR(30) NOT NULL,
    account_type VARCHAR(30) NOT NULL,
    balance DECIMAL(15,2) NOT NULL DEFAULT 0.00,
    account_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    holder_role VARCHAR(30) NOT NULL DEFAULT 'PRIMARY',
    start_date DATE,
    end_date DATE,

    CONSTRAINT chk_account_balance
        CHECK (balance >= 0),

    CONSTRAINT chk_account_status
        CHECK (account_status IN
            ('ACTIVE', 'INACTIVE', 'FROZEN', 'CLOSED')),

    CONSTRAINT chk_account_type
        CHECK (account_type IN
            ('SAVINGS', 'CURRENT', 'SALARY', 'FIXED_DEPOSIT')),

    CONSTRAINT chk_holder_dates
        CHECK (end_date IS NULL OR start_date IS NULL
               OR end_date >= start_date),

    INDEX idx_customer_id (customer_id),
    INDEX idx_account_number (account_number),
    INDEX idx_account_status (account_status)
) ENGINE=InnoDB;


-- ============================================================
-- 2. STAFF
-- Stores bank staff who manage fraud flags and investigations.
-- ============================================================

CREATE TABLE IF NOT EXISTS STAFF (
    staff_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    staff_name VARCHAR(120) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    role VARCHAR(40) NOT NULL,
    staff_status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',

    CONSTRAINT chk_staff_status
        CHECK (staff_status IN ('ACTIVE', 'INACTIVE'))
) ENGINE=InnoDB;


-- ============================================================
-- 3. BANK_TRANSACTION
-- Stores deposits, withdrawals and account transfers.
-- ============================================================


CREATE TABLE IF NOT EXISTS BANK_TRANSACTION (
    transaction_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_type VARCHAR(20) NOT NULL,
    amount DECIMAL(15,2) NOT NULL,
    transaction_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    transaction_status VARCHAR(25) NOT NULL DEFAULT 'PENDING',
    reference_number VARCHAR(60) NOT NULL UNIQUE,

    from_account_id BIGINT,
    to_account_id BIGINT,

    CONSTRAINT fk_transaction_from_account
        FOREIGN KEY (from_account_id)
        REFERENCES CUSTOMER_ACCOUNT(customer_account_id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_transaction_to_account
        FOREIGN KEY (to_account_id)
        REFERENCES CUSTOMER_ACCOUNT(customer_account_id)
        ON DELETE RESTRICT,

    CONSTRAINT chk_transaction_amount
        CHECK (amount > 0),

    CONSTRAINT chk_transaction_type
        CHECK (transaction_type IN
            ('DEPOSIT', 'WITHDRAWAL', 'TRANSFER')),

    CONSTRAINT chk_transaction_status
        CHECK (transaction_status IN
            ('PENDING', 'COMPLETED', 'FAILED',
             'REVERSED', 'UNDER_REVIEW')),

    CONSTRAINT chk_transaction_accounts
        CHECK (
            (transaction_type = 'DEPOSIT'
                AND from_account_id IS NULL
                AND to_account_id IS NOT NULL)
            OR
            (transaction_type = 'WITHDRAWAL'
                AND from_account_id IS NOT NULL
                AND to_account_id IS NULL)
            OR
            (transaction_type = 'TRANSFER'
                AND from_account_id IS NOT NULL
                AND to_account_id IS NOT NULL
                AND from_account_id <> to_account_id)
        ),

    INDEX idx_transaction_time (transaction_time),
    INDEX idx_transaction_status (transaction_status),
    INDEX idx_transaction_from (from_account_id),
    INDEX idx_transaction_to (to_account_id)
) ENGINE=InnoDB;



-- ============================================================
-- 4. FRAUD_FLAG
-- Stores suspicious activity detected automatically or
-- reported manually. A flag is an alert, not proof of fraud.
-- ============================================================

CREATE TABLE IF NOT EXISTS FRAUD_FLAG (
    flag_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id BIGINT NOT NULL,

    rule_id VARCHAR(40),
    rule_name VARCHAR(100) NOT NULL,
    rule_description TEXT,
    rule_type VARCHAR(40) NOT NULL,
    threshold_value DECIMAL(15,2),

    flag_source VARCHAR(20) NOT NULL DEFAULT 'AUTOMATIC',
    reason TEXT NOT NULL,
    severity VARCHAR(20) NOT NULL DEFAULT 'MEDIUM',
    flag_status VARCHAR(25) NOT NULL DEFAULT 'OPEN',

    created_by_staff_id BIGINT,
    flagged_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_flag_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES BANK_TRANSACTION(transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_flag_created_by
        FOREIGN KEY (created_by_staff_id)
        REFERENCES STAFF(staff_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_flag_source
        CHECK (flag_source IN ('AUTOMATIC', 'MANUAL')),

    CONSTRAINT chk_flag_severity
        CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),

    CONSTRAINT chk_flag_status
        CHECK (flag_status IN
            ('OPEN', 'UNDER_INVESTIGATION', 'CONFIRMED',
             'FALSE_POSITIVE', 'CLOSED')),

    INDEX idx_flag_transaction (transaction_id),
    INDEX idx_flag_status_severity (flag_status, severity),
    INDEX idx_flagged_at (flagged_at)
) ENGINE=InnoDB;


-- ============================================================
-- 5. INVESTIGATION
-- Stores staff assignments, findings and investigation outcomes.
-- ============================================================

CREATE TABLE IF NOT EXISTS INVESTIGATION (
    investigation_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    flag_id BIGINT NOT NULL,
    assigned_staff_id BIGINT,

    investigation_status VARCHAR(25) NOT NULL DEFAULT 'OPEN',
    findings TEXT,
    outcome VARCHAR(40),

    opened_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    resolved_at DATETIME,

    CONSTRAINT fk_investigation_flag
        FOREIGN KEY (flag_id)
        REFERENCES FRAUD_FLAG(flag_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_investigation_staff
        FOREIGN KEY (assigned_staff_id)
        REFERENCES STAFF(staff_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_investigation_status
        CHECK (investigation_status IN
            ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),

    CONSTRAINT chk_investigation_dates
        CHECK (resolved_at IS NULL OR resolved_at >= opened_at),

    INDEX idx_investigation_flag (flag_id),
    INDEX idx_investigation_staff (assigned_staff_id),
    INDEX idx_investigation_status (investigation_status)
) ENGINE=InnoDB;


-- ============================================================
-- 6. TRANSACTION_AUDIT
-- Records important transaction-related actions for traceability.
-- ============================================================

CREATE TABLE IF NOT EXISTS TRANSACTION_AUDIT (
    audit_id BIGINT AUTO_INCREMENT PRIMARY KEY,
    transaction_id BIGINT NOT NULL,
    staff_id BIGINT,

    action_type VARCHAR(50) NOT NULL,
    old_status VARCHAR(25),
    new_status VARCHAR(25),
    action_details TEXT,
    action_time DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fk_audit_transaction
        FOREIGN KEY (transaction_id)
        REFERENCES BANK_TRANSACTION(transaction_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_audit_staff
        FOREIGN KEY (staff_id)
        REFERENCES STAFF(staff_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    INDEX idx_audit_transaction (transaction_id),
    INDEX idx_audit_staff (staff_id),
    INDEX idx_audit_time (action_time)
) ENGINE=InnoDB;


-- ============================================================
-- END OF SCHEMA
-- ============================================================
