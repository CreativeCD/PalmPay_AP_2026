# PalmPay — Query Execution Timings & Optimization Analysis

**Project:** PalmPay — NIR-Based Palm-Vein Biometric Authentication and Payment Simulation System  
**Target Engine:** PostgreSQL 16 (Relational Database Management System)  
**Deliverable:** `dbms/05_query_timings.md` & `dbms/plans/`  
**Checkpoint:** Database Engineering Capstone — Query Performance, Benchmarking & Execution Plans  
**Status:** In Progress (Collaborative Split: Part 1 In-Progress [Queries 1–11], Part 2 Pending Partner Handover [Queries 12–22])

---

## 1. Executive Summary & Purpose

This deliverable provides performance benchmarks, execution plan analyses, and index optimization audits for the 22 SQL statements defined in `dbms/04_queries.sql` against the physical schema defined in `dbms/03_schema.sql`.

The purpose of this performance evaluation is to:
1. **Verify Query Optimization:** Confirm that PostgreSQL's Cost-Based Optimizer (CBO) utilizes the indexes defined in `03_schema.sql` (e.g., `uq_users_email_ci`, `users_pkey`, `uq_wallets_user_id`, composite indexes on timestamps).
2. **Prevent Table Scans on Critical Paths:** Eliminate unintentional sequential scans (`Seq Scan`) on large ledger tables (`transactions`, `auth_logs`, `users`).
3. **Validate Concurrency & Latency:** Ensure high-frequency user-facing paths (authentication, balance checks, payment debits) execute in sub-millisecond timeframes.
4. **Deliver Structured Execution Plans:** Persist human-readable `EXPLAIN (ANALYZE, BUFFERS)` execution plan logs in `dbms/plans/`.

### Work Distribution Overview
To facilitate peer collaboration, the 22 application queries are divided equally into two symmetrical halves:
- **Part 1 (This Share):** Queries 1–11 covering Section 1 (User Auth & Registration: R1, W1, W2, R2, R3), Section 2 (Biometric Templates: W3, R4, W4), Section 3 (Audit Logs: W5, R5), and Section 4 (Merchant Directory: R6).
- **Part 2 (Partner Share):** Queries 12–22 covering Section 4 (Merchant Status: R7), Section 5 (Wallet Locking & Balance: R8, R9, W6), Section 6 (Transactions & Receipts: W7, R10, R11, R12), and Section 7 (Financial Analytics: R13, R14, R15).

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
| **R1** | READ | Check email availability | `users` | Index Scan (`uq_users_email_ci`) | `0.29..8.30` | 0.112 | 0.059 | Completed | [`r1_check_email.txt`](plans/r1_check_email.txt) |
| **W1** | WRITE | Register new user account | `users` | Single-row Insert + RETURNING | `0.00..0.01` | 0.048 | 0.215 | Completed | [`w1_register_user.txt`](plans/w1_register_user.txt) |
| **W2** | WRITE | Initialize user demo wallet | `wallets` | Single-row Insert + RETURNING | `0.00..0.01` | 0.042 | 0.174 | Completed | [`w2_init_wallet.txt`](plans/w2_init_wallet.txt) |
| **R2** | READ | Authenticate user login credentials | `users` | Index Scan (`uq_users_email_ci`) | `0.29..8.30` | 0.082 | 0.046 | Completed | [`r2_login_auth.txt`](plans/r2_login_auth.txt) |
| **R3** | READ | Get user profile with wallet balance | `users`, `wallets` | Nested Loop (`users_pkey` + `uq_wallets_user_id`) | `0.57..16.63` | 0.165 | 0.072 | Completed | [`r3_user_profile_wallet.txt`](plans/r3_user_profile_wallet.txt) |
| **W3** | WRITE | Enroll biometric template | `biometric_templates` | Single-row Insert + RETURNING | `0.00..0.01` | *Pending C2* | *Pending C2* | In Progress | `plans/w3_enroll_biometric.txt` |
| **R4** | READ | Retrieve latest biometric template | `biometric_templates`, `users` | Nested Loop (`idx_biometric_templates_created_at` + `users_pkey`) | `0.57..8.62` | *Pending C2* | *Pending C2* | In Progress | `plans/r4_verify_biometric.txt` |
| **W4** | WRITE | Delete user biometric template | `biometric_templates` | Delete via Index Scan (`idx_biometric_templates_user_id`) | `0.28..8.32` | *Pending C2* | *Pending C2* | In Progress | `plans/w4_delete_biometric.txt` |
| **W5** | WRITE | Insert authentication audit log | `auth_logs` | Single-row Insert + RETURNING | `0.00..0.01` | *Pending C2* | *Pending C2* | In Progress | `plans/w5_insert_auth_log.txt` |
| **R5** | READ | Retrieve user authentication audit trail | `auth_logs`, `users` | Nested Loop Left Join (`idx_auth_logs_user_created` + `users_pkey`) | `0.57..16.71` | *Pending C2* | *Pending C2* | In Progress | `plans/r5_user_auth_logs.txt` |
| **R6** | READ | List all active merchants | `merchants` | Sequential Scan + Quicksort | `1.28..1.31` | *Pending C2* | *Pending C2* | In Progress | `plans/r6_active_merchants.txt` |
| **R7** | READ | Validate merchant status | `merchants` | Index Scan (`merchants_pkey`) | TBD | TBD | TBD | Pending Partner | `plans/r7_validate_merchant.txt` |
| **R8** | READ | Fetch current wallet balance | `wallets` | Index Scan (`uq_wallets_user_id`) | TBD | TBD | TBD | Pending Partner | `plans/r8_wallet_balance.txt` |
| **R9** | READ | Lock wallet row for atomic payment | `wallets` | Index Scan (`uq_wallets_user_id` FOR UPDATE) | TBD | TBD | TBD | Pending Partner | `plans/r9_wallet_lock.txt` |
| **W6** | WRITE | Debit wallet balance | `wallets` | Update via Index Scan (`uq_wallets_user_id`) | TBD | TBD | TBD | Pending Partner | `plans/w6_wallet_debit.txt` |
| **W7** | WRITE | Record completed transaction in ledger | `transactions` | Single-row Insert + RETURNING | TBD | TBD | TBD | Pending Partner | `plans/w7_record_transaction.txt` |
| **R10** | READ | Check transaction reference uniqueness | `transactions` | Index Scan (`uq_transactions_reference`) | TBD | TBD | TBD | Pending Partner | `plans/r10_check_reference.txt` |
| **R11** | READ | User transaction history with merchants | `transactions`, `merchants` | Nested Loop / Hash Join (`idx_transactions_user_created`) | TBD | TBD | TBD | Pending Partner | `plans/r11_user_transactions.txt` |
| **R12** | READ | Comprehensive payment receipt lookup | `transactions`, `users`, `merchants` | Multi-table Join (`transactions_pkey`) | TBD | TBD | TBD | Pending Partner | `plans/r12_receipt_lookup.txt` |
| **R13** | READ | Category spending summary | `transactions`, `merchants` | Hash Aggregate / Sort (`idx_transactions_user_id`) | TBD | TBD | TBD | Pending Partner | `plans/r13_category_spending.txt` |
| **R14** | READ | Merchant total revenue & sales volume | `merchants`, `transactions` | HashAggregate Left Join | TBD | TBD | TBD | Pending Partner | `plans/r14_merchant_revenue.txt` |
| **R15** | READ | User monthly spending summary | `transactions` | GroupAggregate (`idx_transactions_user_created`) | TBD | TBD | TBD | Pending Partner | `plans/r15_monthly_spending.txt` |

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

*(Queries W3, R4, W4, W5, R5, and R6 will be updated in Commit 2)*
