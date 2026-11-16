-- ============================================================================
-- PalmPay Database Schema (PostgreSQL)
-- Academic Capstone Project: NIR-Based Palm-Vein Biometric Authentication
-- and Payment Simulation System
-- Checkpoint 03: Physical Relational Schema
-- ============================================================================

-- Drop tables in reverse order of foreign key dependency if they exist
DROP TABLE IF EXISTS auth_logs CASCADE;
DROP TABLE IF EXISTS transactions CASCADE;
DROP TABLE IF EXISTS merchants CASCADE;
DROP TABLE IF EXISTS biometric_templates CASCADE;
DROP TABLE IF EXISTS wallets CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ----------------------------------------------------------------------------
-- 1. USERS
-- Core account entity storing user demographic and authentication credentials.
-- ----------------------------------------------------------------------------
CREATE TABLE users (
    user_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Case-insensitive unique constraint on email
CREATE UNIQUE INDEX uq_users_email_ci ON users (LOWER(email));

COMMENT ON TABLE users IS 'User accounts for authentication and simulated payments';
COMMENT ON COLUMN users.user_id IS 'Unique user identifier (Surrogate primary key)';
COMMENT ON COLUMN users.name IS 'Full legal or display name of the user';
COMMENT ON COLUMN users.email IS 'Unique login email address (enforced case-insensitively)';
COMMENT ON COLUMN users.password_hash IS 'Cryptographic hash of user password (e.g., bcrypt/argon2; never plaintext)';
COMMENT ON COLUMN users.created_at IS 'UTC timestamp when the user account was created';

-- ----------------------------------------------------------------------------
-- 2. WALLETS
-- Digital demo wallet holding simulated funds.
-- Enforces a strict 1:1 relationship with USERS via UNIQUE(user_id).
-- ----------------------------------------------------------------------------
CREATE TABLE wallets (
    wallet_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    balance NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_wallets_user_id UNIQUE (user_id),
    CONSTRAINT fk_wallets_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE,
    CONSTRAINT chk_wallets_non_negative_balance CHECK (balance >= 0.00)
);

COMMENT ON TABLE wallets IS 'Simulated digital wallets associated with users (Strict 1:1 relationship)';
COMMENT ON COLUMN wallets.wallet_id IS 'Unique wallet identifier (Primary key)';
COMMENT ON COLUMN wallets.user_id IS 'Owner user ID (Foreign key with UNIQUE constraint for 1:1 relationship)';
COMMENT ON COLUMN wallets.balance IS 'Simulated currency balance with 2 decimal precision; cannot be negative';
COMMENT ON COLUMN wallets.updated_at IS 'UTC timestamp of the most recent balance update';

-- ----------------------------------------------------------------------------
-- 3. BIOMETRIC_TEMPLATES
-- Stores processed biometric representations or secure template references.
-- Supports 1:MANY relationship with USERS (multiple enrollments per user).
-- ----------------------------------------------------------------------------
CREATE TABLE biometric_templates (
    template_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    template_reference TEXT NOT NULL,
    method VARCHAR(50) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_biometric_templates_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE CASCADE
);

COMMENT ON TABLE biometric_templates IS 'Biometric templates or secure vault references for palm-vein authentication';
COMMENT ON COLUMN biometric_templates.template_id IS 'Unique biometric template enrollment identifier';
COMMENT ON COLUMN biometric_templates.user_id IS 'Foreign key referencing the user who enrolled this template';
COMMENT ON COLUMN biometric_templates.template_reference IS 'Encrypted template feature vector or path reference in secure storage';
COMMENT ON COLUMN biometric_templates.method IS 'Acquisition and feature extraction method (e.g. NIR_DATASET, NIR_SENSOR_V1, SIMULATED)';
COMMENT ON COLUMN biometric_templates.created_at IS 'UTC timestamp when the biometric template was enrolled';

-- ----------------------------------------------------------------------------
-- 4. MERCHANTS
-- Commercial entities participating in the simulated payment ecosystem.
-- ----------------------------------------------------------------------------
CREATE TABLE merchants (
    merchant_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    category VARCHAR(100) NOT NULL,
    active BOOLEAN NOT NULL DEFAULT TRUE
);

COMMENT ON TABLE merchants IS 'Registered merchant endpoints participating in simulated payments';
COMMENT ON COLUMN merchants.merchant_id IS 'Unique merchant identifier (Primary key)';
COMMENT ON COLUMN merchants.name IS 'Registered commercial or trade name of the merchant';
COMMENT ON COLUMN merchants.category IS 'Business domain/category (e.g., DINING, RETAIL, TRANSIT)';
COMMENT ON COLUMN merchants.active IS 'Flag indicating whether merchant is active and can accept transactions';

-- ----------------------------------------------------------------------------
-- 5. TRANSACTIONS
-- Ledger of simulated payment transactions initiated by users to merchants.
-- Maintains financial audit integrity by using ON DELETE RESTRICT on parties.
-- ----------------------------------------------------------------------------
CREATE TABLE transactions (
    transaction_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL,
    merchant_id BIGINT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    status VARCHAR(50) NOT NULL,
    reference VARCHAR(100) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_transactions_reference UNIQUE (reference),
    CONSTRAINT fk_transactions_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE RESTRICT,
    CONSTRAINT fk_transactions_merchant FOREIGN KEY (merchant_id)
        REFERENCES merchants (merchant_id) ON DELETE RESTRICT,
    CONSTRAINT chk_transactions_positive_amount CHECK (amount > 0.00)
);

COMMENT ON TABLE transactions IS 'Simulated payment transaction audit ledger';
COMMENT ON COLUMN transactions.transaction_id IS 'Unique transaction record identifier';
COMMENT ON COLUMN transactions.user_id IS 'Foreign key referencing paying user (RESTRICT on delete to protect audit trail)';
COMMENT ON COLUMN transactions.merchant_id IS 'Foreign key referencing recipient merchant (RESTRICT on delete)';
COMMENT ON COLUMN transactions.amount IS 'Payment amount in currency units; must be strictly positive (> 0.00)';
COMMENT ON COLUMN transactions.status IS 'Transaction lifecycle status (e.g. PENDING, SUCCESS, FAILED, REFUNDED)';
COMMENT ON COLUMN transactions.reference IS 'Globally unique transaction reference code / receipt number';
COMMENT ON COLUMN transactions.created_at IS 'UTC timestamp when transaction was initiated';

-- ----------------------------------------------------------------------------
-- 6. AUTH_LOGS
-- Comprehensive security audit trail of authentication attempts.
-- user_id is NULLABLE to capture unauthenticated or anonymous attempts.
-- ----------------------------------------------------------------------------
CREATE TABLE auth_logs (
    auth_log_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NULL,
    method VARCHAR(50) NOT NULL,
    result VARCHAR(20) NOT NULL,
    score NUMERIC(6, 4) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_auth_logs_user FOREIGN KEY (user_id)
        REFERENCES users (user_id) ON DELETE SET NULL,
    CONSTRAINT chk_auth_logs_score_range CHECK (score IS NULL OR (score >= 0.0000 AND score <= 1.0000))
);

COMMENT ON TABLE auth_logs IS 'Audit logging table for all authentication verification attempts';
COMMENT ON COLUMN auth_logs.auth_log_id IS 'Unique authentication log identifier';
COMMENT ON COLUMN auth_logs.user_id IS 'Optional foreign key to users table; NULL for unauthenticated or unknown attempts';
COMMENT ON COLUMN auth_logs.method IS 'Authentication modality used (e.g. PASSWORD, NIR_PALM_MATCH, PIN)';
COMMENT ON COLUMN auth_logs.result IS 'Authentication outcome (e.g. SUCCESS, FAILURE, ERROR, TIMEOUT)';
COMMENT ON COLUMN auth_logs.score IS 'Normalized biometric comparison/similarity score (0.0000 to 1.0000); NULL if non-biometric';
COMMENT ON COLUMN auth_logs.created_at IS 'UTC timestamp when the authentication attempt occurred';

-- ============================================================================
-- INDEXES FOR PERFORMANCE AND OPTIMIZATION
-- Indexing foreign keys for join performance and timestamp fields for time-series queries.
-- ============================================================================

-- Foreign key indexes
CREATE INDEX idx_biometric_templates_user_id ON biometric_templates (user_id);
CREATE INDEX idx_transactions_user_id ON transactions (user_id);
CREATE INDEX idx_transactions_merchant_id ON transactions (merchant_id);
CREATE INDEX idx_auth_logs_user_id ON auth_logs (user_id);

-- Timestamp indexes for history, filtering, and reporting
CREATE INDEX idx_transactions_created_at ON transactions (created_at DESC);
CREATE INDEX idx_auth_logs_created_at ON auth_logs (created_at DESC);
CREATE INDEX idx_biometric_templates_created_at ON biometric_templates (created_at DESC);

-- Composite indexes for frequent user-filtered historical queries
CREATE INDEX idx_transactions_user_created ON transactions (user_id, created_at DESC);
CREATE INDEX idx_transactions_merchant_created ON transactions (merchant_id, created_at DESC);
CREATE INDEX idx_auth_logs_user_created ON auth_logs (user_id, created_at DESC);
