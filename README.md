# PalmPay — NIR Palm-Vein Biometrics & Payment Simulation System

**Course:** Database Management Systems (DBMS) / Application Engineering  
**Checkpoint:** CP4 — Final Project Submission  
**Engine:** PostgreSQL 18.6 (compatible with PostgreSQL 16+)  
**Repository Branch:** `main`  
**Submission Date:** November 23, 2026  

---

## 1. Project Overview

**PalmPay** is a high-security, near-infrared (NIR) palm-vein biometric authentication and digital wallet payment simulation platform. The system models contactless biometric identification, real-time ledger debiting, concurrency control, and fraud audit trails.

The database architecture is designed in strict **Third Normal Form (3NF)** with explicit foreign key integrity, check constraints, domain validation, and specialized indexing (functional expression B-Trees, unique indexes, and composite timestamp indexes).

---

## 2. Repository Structure & Deliverables

```
PalmPay_AP_2026/
├── README.md                      # Project documentation and evaluator quickstart
├── dbms/
│   ├── 01_normalization.md       # Relational normalization proof (1NF, 2NF, 3NF, BCNF)
│   ├── 02_er_diagram.png         # Physical Entity-Relationship Diagram (ERD)
│   ├── 03_schema.sql             # DDL: Tables, constraints, and indexes
│   ├── 04_queries.sql            # 22 Core application queries (15 READ, 7 WRITE)
│   ├── 05_query_timings.md       # CP4 Benchmark timings (3 runs, averages, plan analyses)
│   ├── seed_data.sql             # Benchmark seed dataset (users, wallets, transactions)
│   ├── run_benchmarks.py         # Autonomous benchmark runner with EXPLAIN ANALYZE
│   ├── validate_queries.py       # Query syntactic, relational, and logic test suite
│   ├── validate_cp4_submission.py# Automated CP4 submission compliance validator
│   └── plans/                    # PostgreSQL execution plan logs (.txt and summary.csv)
│       ├── R01.txt ... R15.txt   # Read query execution plans (Runs 1 to 3)
│       ├── W01.txt ... W07.txt   # Write query execution plans (Runs 1 to 3)
│       ├── r1_... to r15_...txt  # Named query execution plans
│       ├── w1_... to w7_...txt   # Named write query execution plans
│       └── summary.csv           # Master timing export (CSV format)
└── docs/
    └── CP3_VIVA_PREPARATION.md   # Viva defense question-and-answer preparation guide
```

---

## 3. Database Schema Entities

The relational database consists of 6 core relational entities:

1. **`users`**: Customer credentials, emails, and bcrypt password hashes.
2. **`wallets`**: Stored-value balances with non-negative constraints.
3. **`biometric_templates`**: Palm-vein NIR biometric template references and sensor types.
4. **`merchants`**: Registered merchant directory and checkout categories.
5. **`transactions`**: Double-entry financial audit ledger with unique transaction references.
6. **`auth_logs`**: Security telemetry recording biometric match confidence scores and timestamps.

---

## 4. CP4 Deliverables & Benchmark Summary

All 22 SQL statements from `dbms/04_queries.sql` were executed three times in PostgreSQL using:
```sql
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS) <query>;
```

### Master Benchmark Timing Table (3 Runs & Verified Average)

| Query ID | Alt ID | Type | Business Operation & Purpose | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) | Access Path / Scan Nodes |
|:---:|:---:|:---:|---|---:|---:|---:|---:|---|
| **R01** | `R1` | READ | Check if email address is already registered | 0.021 | 0.020 | 0.021 | **0.021** | Index Scan (`uq_users_email_ci`) |
| **W01** | `W1` | WRITE | Register a new user account with hashed password | 0.191 | 0.162 | 0.152 | **0.168** | Insert (`users`) |
| **W02** | `W2` | WRITE | Provision default demo wallet for newly registered user | 0.399 | 0.294 | 0.279 | **0.324** | Insert (`wallets`) |
| **R02** | `R2` | READ | Authenticate user login credentials by email | 0.021 | 0.016 | 0.018 | **0.018** | Index Scan (`uq_users_email_ci`) |
| **R03** | `R3` | READ | Get user profile with wallet summary (JOIN) | 0.036 | 0.035 | 0.032 | **0.034** | Nested Loop (`users_pkey` + `uq_wallets_user_id`) |
| **W03** | `W3` | WRITE | Enroll or update user biometric template | 0.404 | 0.301 | 0.311 | **0.339** | Insert (`biometric_templates`) |
| **R04** | `R4` | READ | Retrieve latest biometric template with user verification (JOIN) | 0.033 | 0.035 | 0.030 | **0.033** | Nested Loop (`idx_biometric_templates_user_id` + `users_pkey`) |
| **W04** | `W4` | WRITE | Reset / Delete existing biometric template enrollment | 0.094 | 0.060 | 0.063 | **0.072** | Delete via Index Scan (`idx_biometric_templates_user_id`) |
| **W05** | `W5` | WRITE | Insert authentication / biometric audit log record | 0.421 | 0.404 | 0.332 | **0.386** | Insert (`auth_logs`) |
| **R05** | `R5` | READ | Retrieve user authentication audit logs (LEFT JOIN) | 0.385 | 0.382 | 0.479 | **0.415** | Hash Left Join: Bitmap Heap Scan (`auth_logs`) + `users_pkey` |
| **R06** | `R6` | READ | List all active merchants for payment checkout | 0.417 | 0.033 | 0.035 | **0.162** | Seq Scan (`merchants`) + Sort |
| **R07** | `R7` | READ | Validate merchant status for payment processing | 0.018 | 0.018 | 0.018 | **0.018** | Seq Scan (`merchants`) |
| **R08** | `R8` | READ | Fetch current wallet balance for authenticated user | 0.027 | 0.024 | 0.025 | **0.025** | Index Scan (`uq_wallets_user_id`) |
| **R09** | `R9` | READ | Lock wallet row for atomic payment deduction (`FOR UPDATE`) | 0.075 | 0.064 | 0.055 | **0.065** | LockRows: Index Scan (`uq_wallets_user_id`) |
| **W06** | `W6` | WRITE | Debit wallet balance following biometric authorization | 0.146 | 0.125 | 0.124 | **0.132** | Update via Index Scan (`uq_wallets_user_id`) |
| **W07** | `W7` | WRITE | Record completed payment transaction in audit ledger | 0.544 | 0.455 | 0.478 | **0.492** | Insert (`transactions`) |
| **R10** | `R10` | READ | Check transaction reference uniqueness (Idempotency Guard) | 0.030 | 0.023 | 0.022 | **0.025** | Index Scan (`uq_transactions_reference`) |
| **R11** | `R11` | READ | Retrieve user transaction history with merchant details (JOIN) | 0.697 | 0.685 | 0.681 | **0.688** | Hash Join: Bitmap Heap Scan (`transactions`) + Seq Scan (`merchants`) |
| **R12** | `R12` | READ | Comprehensive transaction receipt lookup (3-TABLE JOIN) | 0.032 | 0.033 | 0.033 | **0.033** | Nested Loop (`transactions_pkey` + `users_pkey` + `merchants`) |
| **R13** | `R13` | READ | User expenditure summary aggregated by category (AGGREGATE) | 0.595 | 0.520 | 0.533 | **0.549** | HashAggregate: Hash Join + Bitmap Heap Scan (`transactions`) |
| **R14** | `R14` | READ | Merchant total revenue and volume summary (AGGREGATE) | 4.408 | 4.290 | 4.292 | **4.330** | HashAggregate: Hash Right Join + Seq Scan (`transactions` 25k) |
| **R15** | `R15` | READ | User monthly spending summary (AGGREGATE `DATE_TRUNC`) | 0.570 | 0.534 | 0.531 | **0.545** | HashAggregate: Bitmap Heap Scan (`transactions`) |

---

## 5. Verification & Test Suite Execution

To verify the submission independently:

### Step 1: Run the CP4 Final Submission Validator
```bash
python3 dbms/validate_cp4_submission.py
```
This automated validator checks:
- Existence and completeness of `03_schema.sql`, `04_queries.sql`, and `05_query_timings.md`.
- Verifies that all 22 execution plans in `dbms/plans/` contain real runtime statistics.
- Validates the mathematical precision of all average execution times ($\frac{R1+R2+R3}{3}$).
- Executes the schema consistency test suite.

### Step 2: Run the Relational Schema & Query Validator
```bash
python3 dbms/validate_queries.py
```

### Step 3: Re-Run Benchmarks Against PostgreSQL (Optional)
```bash
python3 dbms/run_benchmarks.py
```

---

## 6. Key Optimization Insights

1. **Sub-Millisecond Point Lookups:** 21 of 22 queries execute in under **1 millisecond**.
2. **Expression B-Trees:** Case-insensitive email indexing (`uq_users_email_ci`) eliminates sequential scans on authentication paths.
3. **Pessimistic Concurrency:** Row-level locking (`SELECT ... FOR UPDATE`) resolves in **0.065 ms**, preventing race conditions during concurrent palm-vein payments.
4. **Bitmap Heap Scans:** High-volume ledger queries on `transactions` and `auth_logs` leverage index bitmap filters to avoid full table sweeps.
5. **Zero Disk Spills:** All analytical hash aggregations execute entirely in memory (`work_mem`).
