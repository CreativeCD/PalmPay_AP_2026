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


