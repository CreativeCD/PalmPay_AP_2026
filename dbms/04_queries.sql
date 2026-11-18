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


