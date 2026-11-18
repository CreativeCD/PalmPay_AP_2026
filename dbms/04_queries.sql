-- ============================================================================
-- PalmPay Database Queries (PostgreSQL)
-- Academic Capstone Project: NIR-Based Palm-Vein Biometric Authentication
-- and Payment Simulation System
-- Checkpoint 03: Application SQL Queries Repository
--
-- Deliverable: dbms/04_queries.sql
-- Classification Standard:
--   -- READ  : Data retrieval statements (SELECT, JOINs, Aggregates)
--   -- WRITE : Data mutation statements (INSERT, UPDATE, DELETE)
--
-- Schema alignment: Conforms strictly to dbms/03_schema.sql
-- ============================================================================


-- ============================================================================
-- SECTION 1: USER REGISTRATION & AUTHENTICATION
-- Handles account creation, credential checks, and profile lookups.
-- ============================================================================

-- Query R1: Check if an email address is already registered
-- Controller: authController.register
-- Purpose: Prevents duplicate user registrations by verifying email uniqueness.
-- Tables: users
-- Parameters: $1 = candidate email address (checked case-insensitively)
-- READ
SELECT user_id, email
  FROM users
 WHERE LOWER(email) = LOWER($1);


-- Query W1: Register a new user account
-- Controller: authController.register
-- Purpose: Inserts a new user record with hashed password credentials.
-- Tables: users
-- Parameters: $1 = name, $2 = email, $3 = password_hash
-- WRITE
INSERT INTO users (name, email, password_hash)
VALUES ($1, LOWER($2), $3)
RETURNING user_id, name, email, created_at;


-- Query W2: Initialize simulated demo wallet upon registration
-- Controller: authController.register
-- Purpose: Provisions a default wallet credited with 1,000.00 demo units for the newly created user.
-- Tables: wallets
-- Parameters: $1 = user_id
-- WRITE
INSERT INTO wallets (user_id, balance)
VALUES ($1, 1000.00)
RETURNING wallet_id, user_id, balance, updated_at;


-- Query R2: Authenticate user login credentials
-- Controller: authController.login
-- Purpose: Retrieves password hash and user identification for credential verification.
-- Tables: users
-- Parameters: $1 = login email address
-- READ
SELECT user_id, name, email, password_hash
  FROM users
 WHERE LOWER(email) = LOWER($1);


-- Query R3: Get authenticated user profile with wallet summary (JOIN)
-- Controller: authController.getMe / Dashboard Profile View
-- Purpose: Retrieves the user's personal profile combined with current wallet status in one round-trip.
-- Tables: users (u), wallets (w)
-- Parameters: $1 = user_id
-- READ
SELECT u.user_id,
       u.name,
       u.email,
       u.created_at AS member_since,
       w.wallet_id,
       w.balance,
       w.updated_at AS balance_last_updated
  FROM users u
  JOIN wallets w ON u.user_id = w.user_id
 WHERE u.user_id = $1;


-- ============================================================================
-- SECTION 2: BIOMETRIC TEMPLATE ENROLLMENT & VERIFICATION
-- Manages near-infrared palm-vein template persistence and verification matching.
-- ============================================================================

-- Query W3: Enroll or update user biometric template
-- Controller: biometricController.enroll
-- Purpose: Persists extracted NIR palm-vein feature representation or vault reference.
-- Tables: biometric_templates
-- Parameters: $1 = user_id, $2 = template_reference, $3 = method
-- WRITE
INSERT INTO biometric_templates (user_id, template_reference, method)
VALUES ($1, $2, $3)
RETURNING template_id, user_id, method, created_at;


-- Query R4: Retrieve latest biometric template with user verification (JOIN)
-- Controller: biometricController.verify / paymentsController.createPayment
-- Purpose: Fetches the stored biometric template joined with user record to verify authorization.
-- Tables: biometric_templates (bt), users (u)
-- Parameters: $1 = user_id
-- READ
SELECT bt.template_id,
       bt.user_id,
       u.name,
       u.email,
       bt.template_reference,
       bt.method,
       bt.created_at
  FROM biometric_templates bt
  JOIN users u ON bt.user_id = u.user_id
 WHERE bt.user_id = $1
 ORDER BY bt.created_at DESC
 LIMIT 1;


-- Query W4: Reset / Delete existing biometric template enrollment
-- Controller: biometricController.deleteTemplate (Biometric Re-enrollment / Security Reset)
-- Purpose: Removes stored biometric templates for a user prior to re-enrollment or upon user request.
-- Tables: biometric_templates
-- Parameters: $1 = user_id
-- WRITE
DELETE FROM biometric_templates
 WHERE user_id = $1;


-- ============================================================================
-- SECTION 3: SECURITY & BIOMETRIC AUDIT LOGGING
-- Maintains an immutable trail of all authentication and verification attempts.
-- ============================================================================

-- Query W5: Insert authentication / biometric audit log record
-- Controller: biometricController.verify / paymentsController.createPayment
-- Purpose: Logs biometric verification attempts with modality, match score, and outcome.
-- Tables: auth_logs
-- Parameters: $1 = user_id (NULL for anonymous/unknown attempts), $2 = method, $3 = result, $4 = score
-- WRITE
INSERT INTO auth_logs (user_id, method, result, score)
VALUES ($1, $2, $3, $4)
RETURNING auth_log_id, user_id, method, result, score, created_at;


-- Query R5: Retrieve user authentication audit logs with user details (LEFT JOIN)
-- Controller: biometricController.getLogs
-- Purpose: Fetches user audit trail; uses LEFT JOIN as auth_logs.user_id is nullable for unauthenticated attempts.
-- Tables: auth_logs (al), users (u)
-- Parameters: $1 = user_id
-- READ
SELECT al.auth_log_id,
       al.user_id,
       COALESCE(u.name, 'Unauthenticated / Anonymous') AS user_name,
       u.email,
       al.method,
       al.result,
       al.score,
       al.created_at
  FROM auth_logs al
  LEFT JOIN users u ON al.user_id = u.user_id
 WHERE al.user_id = $1
 ORDER BY al.created_at DESC;


-- ============================================================================
-- SECTION 4: MERCHANT CATALOG & VALIDATION
-- Handles retrieval and status validation of registered merchant endpoints.
-- ============================================================================

-- Query R6: List all active merchants for payment checkout
-- Controller: merchantsController.getMerchants
-- Purpose: Provides merchant directory for user payment destination selection in checkout UI.
-- Tables: merchants
-- Parameters: None
-- READ
SELECT merchant_id,
       name,
       category
  FROM merchants
 WHERE active = TRUE
 ORDER BY name ASC;


-- Query R7: Validate merchant status for payment processing
-- Controller: paymentsController.createPayment
-- Purpose: Ensures the destination merchant exists and is currently active before charging payment.
-- Tables: merchants
-- Parameters: $1 = merchant_id
-- READ
SELECT merchant_id,
       name,
       category,
       active
  FROM merchants
 WHERE merchant_id = $1
   AND active = TRUE;


-- ============================================================================
-- SECTION 5: WALLET TRANSACTIONS & CONCURRENCY CONTROL
-- Manages atomic debits, balance verification, and row-level locking.
-- ============================================================================

-- Query R8: Fetch current wallet balance
-- Controller: walletController.getWallet
-- Purpose: Retrieves current available balance and last updated timestamp for display.
-- Tables: wallets
-- Parameters: $1 = user_id
-- READ
SELECT wallet_id,
       user_id,
       balance,
       updated_at
  FROM wallets
 WHERE user_id = $1;


-- Query R9: Lock wallet row for atomic payment deduction (Concurrency Control)
-- Service: paymentService.processPayment
-- Purpose: Acquires an exclusive row-level lock (FOR UPDATE) to prevent race conditions / double-spending.
-- Tables: wallets
-- Parameters: $1 = user_id
-- READ
SELECT wallet_id,
       user_id,
       balance
  FROM wallets
 WHERE user_id = $1
   FOR UPDATE;


-- Query W6: Debit wallet balance following successful biometric authorization
-- Service: paymentService.processPayment
-- Purpose: Deducts transaction amount from wallet balance with non-negative balance guard.
-- Tables: wallets
-- Parameters: $1 = deduction amount, $2 = user_id
-- WRITE
UPDATE wallets
   SET balance    = balance - $1,
       updated_at = CURRENT_TIMESTAMP
 WHERE user_id = $2
   AND balance >= $1
 RETURNING wallet_id, user_id, balance, updated_at;


-- ============================================================================
-- SECTION 6: PAYMENT TRANSACTIONS & LEDGER
-- Records immutable financial ledger entries and provides transaction histories.
-- ============================================================================

-- Query W7: Record completed payment transaction in ledger
-- Service: paymentService.processPayment
-- Purpose: Appends confirmed simulated payment into audit ledger linking user and merchant.
-- Tables: transactions
-- Parameters: $1 = user_id, $2 = merchant_id, $3 = amount, $4 = reference
-- WRITE
INSERT INTO transactions (user_id, merchant_id, amount, status, reference)
VALUES ($1, $2, $3, 'completed', $4)
RETURNING transaction_id, user_id, merchant_id, amount, status, reference, created_at;


-- Query R10: Check transaction reference uniqueness (Idempotency Guard)
-- Controller: paymentsController.createPayment
-- Purpose: Verifies whether an idempotency key was previously processed to avoid duplicate debits.
-- Tables: transactions
-- Parameters: $1 = reference string
-- READ
SELECT transaction_id,
       status,
       amount,
       created_at
  FROM transactions
 WHERE reference = $1;


-- Query R11: Retrieve user transaction history with merchant details (JOIN)
-- Controller: transactionsController.getTransactions
-- Purpose: Displays user transaction statement with enriched merchant names and business categories.
-- Tables: transactions (t), merchants (m)
-- Parameters: $1 = user_id
-- READ
SELECT t.transaction_id,
       t.amount,
       t.status,
       t.reference,
       t.created_at,
       m.merchant_id,
       m.name AS merchant_name,
       m.category AS merchant_category
  FROM transactions t
  JOIN merchants m ON t.merchant_id = m.merchant_id
 WHERE t.user_id = $1
 ORDER BY t.created_at DESC;


-- Query R12: Comprehensive transaction receipt lookup (MULTI-TABLE JOIN)
-- Controller: paymentsController.createPayment / Receipt View
-- Purpose: Fetches complete payment voucher joining transaction ledger, paying customer, and merchant.
-- Tables: transactions (t), users (u), merchants (m)
-- Parameters: $1 = transaction_id
-- READ
SELECT t.transaction_id,
       t.reference,
       t.amount,
       t.status,
       t.created_at,
       u.user_id,
       u.name AS customer_name,
       u.email AS customer_email,
       m.merchant_id,
       m.name AS merchant_name,
       m.category AS merchant_category
  FROM transactions t
  JOIN users u ON t.user_id = u.user_id
  JOIN merchants m ON t.merchant_id = m.merchant_id
 WHERE t.transaction_id = $1;


-- ============================================================================
-- SECTION 7: AGGREGATE QUERIES & FINANCIAL ANALYTICS
-- Computes spending breakdowns, transaction volumes, and merchant performance.
-- ============================================================================

-- Query R13: User expenditure summary aggregated by merchant category (AGGREGATE + JOIN)
-- Controller: Analytics / Dashboard Expenditure Chart
-- Purpose: Aggregates customer expenditure by category, computing totals, count, and average spend.
-- Tables: transactions (t), merchants (m)
-- Parameters: $1 = user_id
-- READ
SELECT m.category,
       COUNT(t.transaction_id) AS total_transactions,
       SUM(t.amount) AS total_spent,
       ROUND(AVG(t.amount), 2) AS avg_transaction_amount
  FROM transactions t
  JOIN merchants m ON t.merchant_id = m.merchant_id
 WHERE t.user_id = $1
   AND t.status = 'completed'
 GROUP BY m.category
 ORDER BY total_spent DESC;


-- Query R14: Merchant total revenue and transaction volume summary (AGGREGATE + JOIN)
-- Controller: Merchant Portal / Admin Settlement Analytics
-- Purpose: Computes total business volume and revenue per merchant using LEFT JOIN for all merchants.
-- Tables: merchants (m), transactions (t)
-- Parameters: None
-- READ
SELECT m.merchant_id,
       m.name AS merchant_name,
       m.category,
       COUNT(t.transaction_id) AS total_sales_count,
       COALESCE(SUM(t.amount), 0.00) AS total_revenue
  FROM merchants m
  LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
                          AND t.status = 'completed'
 WHERE m.active = TRUE
 GROUP BY m.merchant_id, m.name, m.category
 ORDER BY total_revenue DESC;


-- Query R15: User monthly spending summary (AGGREGATE)
-- Controller: Monthly Statement / Budgeting Analytics
-- Purpose: Computes monthly total spend and count of transactions for personal finance tracking.
-- Tables: transactions
-- Parameters: $1 = user_id
-- READ
SELECT DATE_TRUNC('month', created_at) AS transaction_month,
       COUNT(transaction_id) AS monthly_transaction_count,
       SUM(amount) AS monthly_total_spent
  FROM transactions
 WHERE user_id = $1
   AND status = 'completed'
 GROUP BY DATE_TRUNC('month', created_at)
 ORDER BY transaction_month DESC;
