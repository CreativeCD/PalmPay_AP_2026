# PalmPay — Query Execution Timings & Optimization Analysis

**Project:** PalmPay — NIR-Based Palm-Vein Biometric Authentication and Payment Simulation System  
**Target Engine:** PostgreSQL 16 (Relational Database Management System)  
**Deliverable:** `dbms/05_query_timings.md` & `dbms/plans/`  
**Checkpoint:** Database Engineering Capstone — Query Performance, Benchmarking & Execution Plans  
**Status:** Half Complete (Part 1 Done: Queries 1–11 [50%] | Part 2 Ready for Partner: Queries 12–22 [50%])

---

## 1. Executive Summary & Purpose

This deliverable provides performance benchmarks, execution plan analyses, and index optimization audits for the 22 SQL statements defined in `dbms/04_queries.sql` against the physical schema defined in `dbms/03_schema.sql`.

The purpose of this performance evaluation is to:
1. **Verify Query Optimization:** Confirm that PostgreSQL's Cost-Based Optimizer (CBO) utilizes the indexes defined in `03_schema.sql` (e.g., `uq_users_email_ci`, `users_pkey`, `uq_wallets_user_id`, composite indexes on timestamps).
2. **Prevent Table Scans on Critical Paths:** Eliminate unintentional sequential scans (`Seq Scan`) on large ledger tables (`transactions`, `auth_logs`, `users`).
3. **Validate Concurrency & Latency:** Ensure high-frequency user-facing paths (authentication, balance checks, payment debits) execute in sub-millisecond timeframes.
4. **Deliver Structured Execution Plans:** Persist human-readable `EXPLAIN (ANALYZE, BUFFERS)` execution plan logs in `dbms/plans/`.

### Collaborative Split Overview
To facilitate peer collaboration, the 22 application queries are divided into two symmetrical shares:
- **Part 1 (Completed — This Share):** 11 queries (50.0%) covering Sections 1 through 4:
  - Section 1: User Registration & Authentication (Queries R1, W1, W2, R2, R3)
  - Section 2: Biometric Template Enrollment & Verification (Queries W3, R4, W4)
  - Section 3: Security & Biometric Audit Logging (Queries W5, R5)
  - Section 4: Merchant Directory Catalog (Query R6)
- **Part 2 (Assigned to Partner / Friend):** 11 queries (50.0%) covering Sections 4 through 7:
  - Section 4: Merchant Status Validation (Query R7)
  - Section 5: Wallet Transactions & Concurrency Control (Queries R8, R9, W6)
  - Section 6: Payment Transactions & Ledger (Queries W7, R10, R11, R12)
  - Section 7: Aggregate Queries & Financial Analytics (Queries R13, R14, R15)

---

## 2. Benchmarking Environment & Methodology

### 2.1 Server Configuration
- **Database Server:** PostgreSQL 16.2 on macOS Darwin 24.1.0 (Apple Silicon ARM64)
- **Shared Memory Buffer:** `shared_buffers = 256MB`
- **Working Memory:** `work_mem = 64MB`
- **Effective Cache Size:** `effective_cache_size = 1GB`
- **Random Page Cost:** `random_page_cost = 1.1` (SSD-optimized NVMe storage)

### 2.2 Synthetic Dataset Scale
To ensure the optimizer produces realistic production-like execution plans rather than defaulting to sequential scans on empty tables, the benchmarks are evaluated against a representative test population:

| Table | Row Count | Primary Key Index | Secondary & Composite Indexes |
|---|---:|---|---|
| `users` | 10,000 | `users_pkey` | `uq_users_email_ci` |
| `wallets` | 10,000 | `wallets_pkey` | `uq_wallets_user_id` |
| `biometric_templates` | 12,500 | `biometric_templates_pkey` | `idx_biometric_templates_user_id`, `idx_biometric_templates_created_at` |
| `merchants` | 50 | `merchants_pkey` | None (small reference catalog) |
| `transactions` | 100,000 | `transactions_pkey` | `uq_transactions_reference`, `idx_transactions_user_id`, `idx_transactions_merchant_id`, `idx_transactions_created_at`, `idx_transactions_user_created`, `idx_transactions_merchant_created` |
| `auth_logs` | 50,000 | `auth_logs_pkey` | `idx_auth_logs_user_id`, `idx_auth_logs_created_at`, `idx_auth_logs_user_created` |

### 2.3 Measurement Protocol
- Each query was evaluated using `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)`.
- Tests were run with a warm cache (pre-warmed buffer cache) across 5 consecutive iterations, recording the mean planning and execution times.
- Parameterized placeholders (`$1`, `$2`, etc.) were bound with valid indexed test keys.

---

## 3. Master Query Performance Summary Table

| Query ID | Type | Operation / Query Purpose | Target Table(s) | Primary Access / Join Path | Plan Cost Range | Plan Time (ms) | Exec Time (ms) | Status | Plan Artifact |
|---|---|---|---|---|---:|---:|---:|---|---|
| **R1** | READ | Check email availability | `users` | Index Scan (`uq_users_email_ci`) | `0.29..8.30` | 0.112 | 0.059 | Completed (Part 1) | [`r1_check_email.txt`](plans/r1_check_email.txt) |
| **W1** | WRITE | Register new user account | `users` | Single-row Insert + RETURNING | `0.00..0.01` | 0.048 | 0.215 | Completed (Part 1) | [`w1_register_user.txt`](plans/w1_register_user.txt) |
| **W2** | WRITE | Initialize user demo wallet | `wallets` | Single-row Insert + RETURNING | `0.00..0.01` | 0.042 | 0.174 | Completed (Part 1) | [`w2_init_wallet.txt`](plans/w2_init_wallet.txt) |
| **R2** | READ | Authenticate user login credentials | `users` | Index Scan (`uq_users_email_ci`) | `0.29..8.30` | 0.082 | 0.046 | Completed (Part 1) | [`r2_login_auth.txt`](plans/r2_login_auth.txt) |
| **R3** | READ | Get user profile with wallet balance | `users`, `wallets` | Nested Loop (`users_pkey` + `uq_wallets_user_id`) | `0.57..16.63` | 0.165 | 0.072 | Completed (Part 1) | [`r3_user_profile_wallet.txt`](plans/r3_user_profile_wallet.txt) |
| **W3** | WRITE | Enroll biometric template | `biometric_templates` | Single-row Insert + RETURNING | `0.00..0.01` | 0.046 | 0.198 | Completed (Part 1) | [`w3_enroll_biometric.txt`](plans/w3_enroll_biometric.txt) |
| **R4** | READ | Retrieve latest biometric template | `biometric_templates`, `users` | Nested Loop (`idx_biometric_templates_created_at` + `users_pkey`) | `0.57..8.62` | 0.208 | 0.078 | Completed (Part 1) | [`r4_verify_biometric.txt`](plans/r4_verify_biometric.txt) |
| **W4** | WRITE | Delete user biometric template | `biometric_templates` | Delete via Index Scan (`idx_biometric_templates_user_id`) | `0.28..8.32` | 0.071 | 0.118 | Completed (Part 1) | [`w4_delete_biometric.txt`](plans/w4_delete_biometric.txt) |
| **W5** | WRITE | Insert authentication audit log | `auth_logs` | Single-row Insert + RETURNING | `0.00..0.01` | 0.044 | 0.188 | Completed (Part 1) | [`w5_insert_auth_log.txt`](plans/w5_insert_auth_log.txt) |
| **R5** | READ | Retrieve user authentication audit trail | `auth_logs`, `users` | Nested Loop Left Join (`idx_auth_logs_user_created` + `users_pkey`) | `0.57..16.71` | 0.198 | 0.092 | Completed (Part 1) | [`r5_user_auth_logs.txt`](plans/r5_user_auth_logs.txt) |
| **R6** | READ | List all active merchants | `merchants` | Sequential Scan + Quicksort | `1.28..1.31` | 0.089 | 0.062 | Completed (Part 1) | [`r6_active_merchants.txt`](plans/r6_active_merchants.txt) |
| **R7** | READ | Validate merchant status | `merchants` | Index Scan (`merchants_pkey`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r7_validate_merchant.txt` |
| **R8** | READ | Fetch current wallet balance | `wallets` | Index Scan (`uq_wallets_user_id`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r8_wallet_balance.txt` |
| **R9** | READ | Lock wallet row for atomic payment | `wallets` | Index Scan (`uq_wallets_user_id` FOR UPDATE) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r9_wallet_lock.txt` |
| **W6** | WRITE | Debit wallet balance | `wallets` | Update via Index Scan (`uq_wallets_user_id`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/w6_wallet_debit.txt` |
| **W7** | WRITE | Record completed transaction in ledger | `transactions` | Single-row Insert + RETURNING | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/w7_record_transaction.txt` |
| **R10** | READ | Check transaction reference uniqueness | `transactions` | Index Scan (`uq_transactions_reference`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r10_check_reference.txt` |
| **R11** | READ | User transaction history with merchants | `transactions`, `merchants` | Nested Loop (`idx_transactions_user_created`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r11_user_transactions.txt` |
| **R12** | READ | Comprehensive payment receipt lookup | `transactions`, `users`, `merchants` | Multi-table Join (`transactions_pkey`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r12_receipt_lookup.txt` |
| **R13** | READ | Category spending summary | `transactions`, `merchants` | Hash Aggregate / Sort (`idx_transactions_user_id`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r13_category_spending.txt` |
| **R14** | READ | Merchant total revenue & sales volume | `merchants`, `transactions` | HashAggregate Left Join | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r14_merchant_revenue.txt` |
| **R15** | READ | User monthly spending summary | `transactions` | GroupAggregate (`idx_transactions_user_created`) | *Pending Part 2* | *TBD* | *TBD* | Assigned to Partner | `plans/r15_monthly_spending.txt` |

---

## 4. Part 1 Detailed Query Performance Analysis (Queries 1–11)

### Section 1: User Registration & Authentication

#### Query R1: Check Email Availability
- **SQL Statement:**
  ```sql
  SELECT user_id, email
    FROM users
   WHERE LOWER(email) = LOWER($1);
  ```
- **Test Parameters:** `$1 = 'asha@example.com'`
- **Access Strategy:** `Index Scan using uq_users_email_ci on public.users`
- **Cost Metrics:** Estimated `cost=0.29..8.30`, Planning Time = `0.112 ms`, Execution Time = `0.059 ms`
- **Buffer I/O:** 3 shared buffer hits (0 disk reads).
- **Optimization Rationale:**
  - Standard indexes on `email` cannot be utilized when wrapping columns in expressions like `LOWER(email)` due to value mutation during evaluation.
  - The schema defines a dedicated functional index: `CREATE UNIQUE INDEX uq_users_email_ci ON users (LOWER(email))`.
  - The CBO directly matches the `WHERE LOWER(email) = ...` clause to `uq_users_email_ci`, achieving logarithmic $O(\log N)$ point lookup latency and eliminating table scans.
- **Execution Plan Artifact:** [`dbms/plans/r1_check_email.txt`](plans/r1_check_email.txt)

---

#### Query W1: Register New User Account
- **SQL Statement:**
  ```sql
  INSERT INTO users (name, email, password_hash)
  VALUES ($1, LOWER($2), $3)
  RETURNING user_id, name, email, created_at;
  ```
- **Test Parameters:** `$1 = 'Asha Sharma'`, `$2 = 'asha@example.com'`, `$3 = '$2b$12$e8rG6xLwM1nB9qZvTkOpXuJ...'`
- **Access Strategy:** `Insert on public.users`
- **Cost Metrics:** Estimated `cost=0.00..0.01`, Planning Time = `0.048 ms`, Execution Time = `0.215 ms`
- **Buffer I/O:** 7 buffer hits, 2 dirtied pages.
- **Optimization Rationale:**
  - PostgreSQL computes surrogate key generation via `IDENTITY` sequence `users_user_id_seq` at zero memory overhead.
  - The insert enforces the uniqueness of `LOWER(email)` through index `uq_users_email_ci` and primary key index `users_pkey`.
  - The `RETURNING` clause fetches the generated `user_id` and timestamp without incurring a secondary round-trip query.
- **Execution Plan Artifact:** [`dbms/plans/w1_register_user.txt`](plans/w1_register_user.txt)

---

#### Query W2: Initialize User Demo Wallet
- **SQL Statement:**
  ```sql
  INSERT INTO wallets (user_id, balance)
  VALUES ($1, 1000.00)
  RETURNING wallet_id, user_id, balance, updated_at;
  ```
- **Test Parameters:** `$1 = 1`
- **Access Strategy:** `Insert on public.wallets`
- **Cost Metrics:** Estimated `cost=0.00..0.01`, Planning Time = `0.042 ms`, Execution Time = `0.174 ms`
- **Buffer I/O:** 5 buffer hits, 1 dirtied page.
- **Optimization Rationale:**
  - Foreign key constraint `fk_wallets_user` verifies existence of parent user in `users_pkey` using index point lookup.
  - Unique constraint `uq_wallets_user_id` enforces strict 1:1 user-to-wallet relationship.
  - Check constraint `chk_wallets_non_negative_balance` evaluates inline with zero disk overhead.
- **Execution Plan Artifact:** [`dbms/plans/w2_init_wallet.txt`](plans/w2_init_wallet.txt)

---

#### Query R2: Authenticate User Login Credentials
- **SQL Statement:**
  ```sql
  SELECT user_id, name, email, password_hash
    FROM users
   WHERE LOWER(email) = LOWER($1);
  ```
- **Test Parameters:** `$1 = 'asha@example.com'`
- **Access Strategy:** `Index Scan using uq_users_email_ci on public.users`
- **Cost Metrics:** Estimated `cost=0.29..8.30`, Planning Time = `0.082 ms`, Execution Time = `0.046 ms`
- **Buffer I/O:** 3 shared buffer hits.
- **Optimization Rationale:**
  - Similar to R1, this query retrieves credentials in a single indexed index fetch.
  - Returning `password_hash` allows Node.js bcrypt comparison to execute in application memory, keeping database workload strictly bounded to indexed retrieval.
- **Execution Plan Artifact:** [`dbms/plans/r2_login_auth.txt`](plans/r2_login_auth.txt)

---

#### Query R3: Get Authenticated User Profile with Wallet Summary (JOIN)
- **SQL Statement:**
  ```sql
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
  ```
- **Test Parameters:** `$1 = 1`
- **Access Strategy:** `Nested Loop` combining `users_pkey` and `uq_wallets_user_id`
- **Cost Metrics:** Estimated `cost=0.57..16.63`, Planning Time = `0.165 ms`, Execution Time = `0.072 ms`
- **Buffer I/O:** 6 shared buffer hits (3 pages from `users`, 3 pages from `wallets`).
- **Optimization Rationale:**
  - Because `u.user_id` is filtered by a single constant (`$1`), the optimizer selects an indexed `Nested Loop` join.
  - Step 1: `Index Scan using users_pkey` locates the single user tuple in 0.020 ms.
  - Step 2: `Index Scan using uq_wallets_user_id` retrieves the matching wallet tuple in 0.019 ms.
  - Overall latency is only 0.072 ms, providing an optimal single round-trip fetch for dashboard rendering.
- **Execution Plan Artifact:** [`dbms/plans/r3_user_profile_wallet.txt`](plans/r3_user_profile_wallet.txt)

---

### Section 2: Biometric Template Enrollment & Verification

#### Query W3: Enroll or Update User Biometric Template
- **SQL Statement:**
  ```sql
  INSERT INTO biometric_templates (user_id, template_reference, method)
  VALUES ($1, $2, $3)
  RETURNING template_id, user_id, method, created_at;
  ```
- **Test Parameters:** `$1 = 1`, `$2 = 'vault://templates/usr_1/palm_left_nir_v1.enc'`, `$3 = 'NIR_SENSOR_V1'`
- **Access Strategy:** `Insert on public.biometric_templates`
- **Cost Metrics:** Estimated `cost=0.00..0.01`, Planning Time = `0.046 ms`, Execution Time = `0.198 ms`
- **Buffer I/O:** 8 shared buffer hits, 2 dirtied pages.
- **Optimization Rationale:**
  - Validates `user_id` against `users.user_id` via foreign key `fk_biometric_templates_user`.
  - Automatically indexes new template across `idx_biometric_templates_user_id` and `idx_biometric_templates_created_at` for rapid authentication retrieval.
- **Execution Plan Artifact:** [`dbms/plans/w3_enroll_biometric.txt`](plans/w3_enroll_biometric.txt)

---

#### Query R4: Retrieve Latest Biometric Template with User Verification (JOIN)
- **SQL Statement:**
  ```sql
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
  ```
- **Test Parameters:** `$1 = 1`
- **Access Strategy:** `Limit` $\rightarrow$ `Nested Loop` $\rightarrow$ `Index Scan using idx_biometric_templates_created_at` + `Index Scan using users_pkey`
- **Cost Metrics:** Estimated `cost=0.57..8.62`, Planning Time = `0.208 ms`, Execution Time = `0.078 ms`
- **Buffer I/O:** 6 shared buffer hits.
- **Optimization Rationale:**
  - The descending B-tree index `idx_biometric_templates_created_at` provides tuples pre-ordered by timestamp.
  - The `LIMIT 1` operator short-circuits evaluation as soon as the first matching row for `$1` is found, reducing query cost by over 50% compared to evaluating all user templates.
- **Execution Plan Artifact:** [`dbms/plans/r4_verify_biometric.txt`](plans/r4_verify_biometric.txt)

---

#### Query W4: Reset / Delete Existing Biometric Template Enrollment
- **SQL Statement:**
  ```sql
  DELETE FROM biometric_templates
   WHERE user_id = $1;
  ```
- **Test Parameters:** `$1 = 1`
- **Access Strategy:** `Delete on public.biometric_templates` using `Index Scan using idx_biometric_templates_user_id`
- **Cost Metrics:** Estimated `cost=0.28..8.32`, Planning Time = `0.071 ms`, Execution Time = `0.118 ms`
- **Buffer I/O:** 9 shared buffer hits, 2 dirtied pages.
- **Optimization Rationale:**
  - The dedicated foreign key index `idx_biometric_templates_user_id` enables direct tuple pointer identification (`ctid`), avoiding an expensive sequential scan across all template records.
- **Execution Plan Artifact:** [`dbms/plans/w4_delete_biometric.txt`](plans/w4_delete_biometric.txt)

---

### Section 3: Security & Biometric Audit Logging

#### Query W5: Insert Authentication / Biometric Audit Log Record
- **SQL Statement:**
  ```sql
  INSERT INTO auth_logs (user_id, method, result, score)
  VALUES ($1, $2, $3, $4)
  RETURNING auth_log_id, user_id, method, result, score, created_at;
  ```
- **Test Parameters:** `$1 = 1`, `$2 = 'NIR_PALM_MATCH'`, `$3 = 'passed'`, `$4 = 0.9420`
- **Access Strategy:** `Insert on public.auth_logs`
- **Cost Metrics:** Estimated `cost=0.00..0.01`, Planning Time = `0.044 ms`, Execution Time = `0.188 ms`
- **Buffer I/O:** 7 shared buffer hits, 2 dirtied pages.
- **Optimization Rationale:**
  - Validates score constraint `chk_auth_logs_score_range` inline.
  - Inserts the log entry into the ledger and updates `idx_auth_logs_user_created` in under 0.2 milliseconds.
- **Execution Plan Artifact:** [`dbms/plans/w5_insert_auth_log.txt`](plans/w5_insert_auth_log.txt)

---

#### Query R5: Retrieve User Authentication Audit Logs with User Details (LEFT JOIN)
- **SQL Statement:**
  ```sql
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
  ```
- **Test Parameters:** `$1 = 1`
- **Access Strategy:** `Nested Loop Left Join` using `idx_auth_logs_user_created` + `users_pkey`
- **Cost Metrics:** Estimated `cost=0.57..16.71`, Planning Time = `0.198 ms`, Execution Time = `0.092 ms`
- **Buffer I/O:** 8 shared buffer hits.
- **Optimization Rationale:**
  - The composite index `idx_auth_logs_user_created ON auth_logs (user_id, created_at DESC)` satisfies both the `WHERE` condition on `user_id` and the `ORDER BY created_at DESC` ordering in a single index pass, completely eliminating an explicit `Sort` operation.
  - The `LEFT JOIN` semantics ensure that even if `user_id` were unlinked or orphaned, the audit record is safely emitted.
- **Execution Plan Artifact:** [`dbms/plans/r5_user_auth_logs.txt`](plans/r5_user_auth_logs.txt)

---

### Section 4: Merchant Catalog & Validation

#### Query R6: List All Active Merchants for Payment Checkout
- **SQL Statement:**
  ```sql
  SELECT merchant_id,
         name,
         category
    FROM merchants
   WHERE active = TRUE
   ORDER BY name ASC;
  ```
- **Test Parameters:** None
- **Access Strategy:** `Sort` $\rightarrow$ `Seq Scan on public.merchants`
- **Cost Metrics:** Estimated `cost=1.28..1.31`, Planning Time = `0.089 ms`, Execution Time = `0.062 ms`
- **Buffer I/O:** 2 shared buffer hits.
- **Optimization Rationale:**
  - The `merchants` table represents small dimension/reference data (50 rows across 2 disk pages).
  - The PostgreSQL optimizer correctly determines that reading 2 consecutive data pages sequentially is faster than index tree traversals.
  - An in-memory quicksort sorts the 50 merchant names in just 0.022 ms with 25kB memory footprint.
- **Execution Plan Artifact:** [`dbms/plans/r6_active_merchants.txt`](plans/r6_active_merchants.txt)

---

## 5. Part 2 Partner Handover & Execution Guide (Queries 12–22)

> **Note for Project Partner:**  
> Part 1 (Queries 1–11: R1–R3, W1–W2, W3, R4, W4, W5, R5, R6) is completed.  
> Your task is to complete the remaining **11 queries (Part 2: Queries 12–22)** to finalize this deliverable.

### 5.1 Checklist of Queries to Benchmark

| Query ID | Section | Name / Operation | Plan File to Create in `dbms/plans/` |
|---|---|---|---|
| **R7** | Section 4 | Validate merchant status for payment processing | `dbms/plans/r7_validate_merchant.txt` |
| **R8** | Section 5 | Fetch current wallet balance | `dbms/plans/r8_wallet_balance.txt` |
| **R9** | Section 5 | Lock wallet row for atomic payment deduction (`FOR UPDATE`) | `dbms/plans/r9_wallet_lock.txt` |
| **W6** | Section 5 | Debit wallet balance with non-negative guard | `dbms/plans/w6_wallet_debit.txt` |
| **W7** | Section 6 | Record completed payment transaction in ledger | `dbms/plans/w7_record_transaction.txt` |
| **R10** | Section 6 | Check transaction reference uniqueness (Idempotency) | `dbms/plans/r10_check_reference.txt` |
| **R11** | Section 6 | Retrieve user transaction history with merchant details | `dbms/plans/r11_user_transactions.txt` |
| **R12** | Section 6 | Comprehensive transaction receipt lookup (Multi-table Join) | `dbms/plans/r12_receipt_lookup.txt` |
| **R13** | Section 7 | User expenditure summary aggregated by category | `dbms/plans/r13_category_spending.txt` |
| **R14** | Section 7 | Merchant total revenue and volume summary (Agg + Left Join) | `dbms/plans/r14_merchant_revenue.txt` |
| **R15** | Section 7 | User monthly spending summary (Date Trunc Aggregation) | `dbms/plans/r15_monthly_spending.txt` |

### 5.2 Test Parameters Template for Partner Queries

Use the following standard test parameters when executing `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)`:
- **Query R7:** `$1 = 1` (merchant_id = 1)
- **Query R8:** `$1 = 1` (user_id = 1)
- **Query R9:** `$1 = 1` (user_id = 1)
- **Query W6:** `$1 = 15.00` (deduction amount), `$2 = 1` (user_id = 1)
- **Query W7:** `$1 = 1` (user_id), `$2 = 1` (merchant_id), `$3 = 15.00` (amount), `$4 = 'TXN-20261118-001'` (reference)
- **Query R10:** `$1 = 'TXN-20261118-001'` (reference string)
- **Query R11:** `$1 = 1` (user_id = 1)
- **Query R12:** `$1 = 1` (transaction_id = 1)
- **Query R13:** `$1 = 1` (user_id = 1)
- **Query R14:** None (evaluates all active merchants)
- **Query R15:** `$1 = 1` (user_id = 1)

### 5.3 Steps to Complete Part 2

1. **Generate Plan Files:** For each query listed above, execute `EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS)` in PostgreSQL and save the output to its corresponding file in `dbms/plans/`.
2. **Update Master Summary Table (Section 3):** Replace `*Pending Part 2*` and `*TBD*` with the actual cost, planning time, and execution time from your generated plans.
3. **Add Detailed Analysis (Section 4):**
   - Create detailed subsections for Section 5 (Queries R8, R9, W6), Section 6 (Queries W7, R10, R11, R12), and Section 7 (Queries R13, R14, R15) following the identical markdown format used in Part 1.
   - Specifically highlight the concurrency lock behavior in Query R9 (`FOR UPDATE`), the composite index acceleration in Query R11 (`idx_transactions_user_created`), and the aggregation plan nodes in Queries R13–R15 (`HashAggregate` / `GroupAggregate`).
4. **Update Status Badge:** Change document status from `Half Complete` to `Complete (100% Benchmarked)`.
