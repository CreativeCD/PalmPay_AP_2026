# PalmPay — CP3 Viva Preparation Guide

> **Target Audience:** Absolute beginner in Databases, SQL, and Backend Development.  
> **Course:** Database Engineering (DE) Capstone Project 2026.  
> **Project Name:** PalmPay — NIR-Based Palm-Vein Biometric Authentication and Payment Simulation System.  
> **Repository:** PalmPay AP Repository (`PalmPay_AP_2026`).  
> **Deliverable Covered:** Checkpoint 03 (`dbms/04_queries.sql`).

---

## Table of Contents
1. [Project Understanding](#1-project-understanding)
2. [Database Fundamentals (Explained Simply)](#2-database-fundamentals-explained-simply)
3. [The PalmPay Database Schema](#3-the-palmpay-database-schema)
4. [Detailed Breakdown of Every Application Query](#4-detailed-breakdown-of-every-application-query)
5. [Understanding SQL JOINs in PalmPay](#5-understanding-sql-joins-in-palmpay)
6. [Concurrency Control: Why `FOR UPDATE` Matters](#6-concurrency-control-why-for-update-matters)
7. [25 Essential Viva Questions & Answers](#7-25-essential-viva-questions--answers)

---

## 1. Project Understanding

### What is PalmPay?
**PalmPay** is an academic capstone application simulating a biometric contactless payment system. Instead of scanning a physical credit card, smartphone QR code, or typing an OTP, a user pays at a merchant terminal by presenting their hand. 
The system authenticates the user using their unique **near-infrared (NIR) palm-vein pattern** and debits a simulated digital wallet.

### How Does the Complete System Work?
The system consists of three main building blocks:
1. **Frontend (React / Vite Web Application):**
   - The user interface seen in the browser.
   - Allows users to register, log in, view their digital wallet balance, upload a palm image for biometric enrollment, select a merchant, and simulate making a payment.
2. **Backend (Node.js & Express API + Python Biometric Microservice):**
   - The "brain" of the application.
   - Handles HTTP requests from the frontend.
   - Uses `bcrypt` for password hashing and `jsonwebtoken` (JWT) for secure session management.
   - When a palm image is uploaded, the backend coordinates with an internal Python microservice to extract biometric feature vectors and compute cosine similarity match scores.
   - Enforces business rules: checks if the user has enough money, verifies biometric match thresholds server-side, and initiates database transactions.
3. **Database (PostgreSQL Relational Database):**
   - The persistent memory of the system.
   - Stores users, wallets, biometric template references, merchant profiles, payment transaction ledgers, and security audit logs.

### Communication Flow: Frontend $\rightarrow$ Backend $\rightarrow$ Database
```
[User Browser (React)]
       |
       |  1. HTTP Request (JSON or multipart form data)
       v
[Backend API (Express)] <---> [Python Biometric Service] (Feature Extraction)
       |
       |  2. SQL Queries ($1, $2 parameterized with 'pg' connection pool)
       v
[PostgreSQL Database] (Tables, Constraints, Foreign Keys, ACID Transactions)
```

1. **Step 1:** The user clicks a button (e.g., "Pay \$15.00 at Campus Cafe"). The React frontend sends an HTTP `POST` request with an authorization token to `/api/payments`.
2. **Step 2:** Express authenticates the token, verifies the uploaded palm image with the biometric matcher, and connects to PostgreSQL using the `pg` connection pool.
3. **Step 3:** The backend sends parameterised SQL statements to PostgreSQL inside a database transaction (`BEGIN ... COMMIT`).
4. **Step 4:** PostgreSQL checks constraints (e.g., balance cannot be negative), updates records, and returns the result back to Express, which responds to the frontend.

### What Role Does the Database Play?
Without a database, all user balances and payment records would disappear as soon as the server restarts. The database provides:
- **Persistence:** Permanently saving account balances and receipts.
- **Data Integrity:** Preventing bad data (e.g., making sure a wallet balance cannot drop below zero).
- **Concurrency Safety:** Preventing "double spending" when two payments happen at the exact same millisecond.
- **Auditability:** Keeping an immutable historical record of every payment and authentication attempt.

---

## 2. Database Fundamentals (Explained Simply)

### What is a Database?
A database is an organized, secure collection of structured data stored electronically on a computer system. Think of it as a supercharged digital filing cabinet designed for fast retrieval, massive storage, and multi-user access.

### What is PostgreSQL?
PostgreSQL (often called "Postgres") is a powerful, open-source **Relational Database Management System (RDBMS)**. It uses the SQL language and is famous for strict standards compliance, reliability, and support for high-concurrency enterprise workloads.

### What is a Table?
A table is a structured grid inside the database that represents a specific concept or object (such as `users`, `merchants`, or `transactions`).

### What are Rows and Columns?
- **Column (Attribute / Field):** A vertical category that defines a single property (e.g., `email`, `balance`, `created_at`). Every item in a column has the same data type.
- **Row (Record / Tuple):** A single horizontal entry in the table representing one real-world item (e.g., one user's account details).

### What is a Primary Key (PK)?
A **Primary Key** is a column (or set of columns) that uniquely identifies each individual row in a table. No two rows can have the same primary key, and it can never be empty (`NULL`).  
*Example:* `user_id` in the `users` table. Even if two users share the same name, their `user_id` values (e.g., 101 and 102) are completely unique.

### What is a Foreign Key (FK)?
A **Foreign Key** is a column in one table that links to the Primary Key of another table. It creates a relationship between the two tables and enforces **referential integrity** (the database will reject any child row pointing to a parent that does not exist).  
*Example:* `wallets.user_id` references `users.user_id`. You cannot create a wallet for a user who does not exist.

### What are Relationships?
Relationships define how rows in one table connect to rows in another:
1. **One-to-One (1:1):** One record in Table A connects to exactly one record in Table B.  
   *PalmPay Example:* Each `users` record has exactly one `wallets` record. This is enforced by placing a `UNIQUE` constraint on `wallets.user_id`.
2. **One-to-Many (1:N):** One record in Table A connects to multiple records in Table B.  
   *PalmPay Example:* One user can have many payment records in the `transactions` table. One merchant can receive many payments.
3. **Many-to-Many (M:N):** Many records in Table A connect to many records in Table B.  
   *PalmPay Example:* Users and Merchants have a many-to-many business relationship, which is resolved via the `transactions` junction table.

---

## 3. The PalmPay Database Schema

The database consists of 6 core tables defined in `dbms/03_schema.sql`:

| Table Name | Primary Key | Description | Key Foreign Keys |
|---|---|---|---|
| `users` | `user_id` | Stores user credentials and profile information. | None |
| `wallets` | `wallet_id` | Stores simulated currency balance (Strict 1:1 with user). | `user_id` $\rightarrow$ `users.user_id` (`ON DELETE CASCADE`) |
| `biometric_templates` | `template_id` | Stores encrypted palm feature representations / vault paths. | `user_id` $\rightarrow$ `users.user_id` (`ON DELETE CASCADE`) |
| `merchants` | `merchant_id` | Registered stores and campus outlets accepting payments. | None |
| `transactions` | `transaction_id` | Financial ledger of simulated payments. | `user_id` $\rightarrow$ `users.user_id`, `merchant_id` $\rightarrow$ `merchants.merchant_id` (`ON DELETE RESTRICT`) |
| `auth_logs` | `auth_log_id` | Security audit trail of all verification attempts. | `user_id` $\rightarrow$ `users.user_id` (`ON DELETE SET NULL`) |

---

## 4. Detailed Breakdown of Every Application Query

The deliverable `dbms/04_queries.sql` contains **22 SQL queries** representing every database operation in the PalmPay application.

### Classification Rules:
- `-- READ`: Queries that fetch data without modifying the database (`SELECT`).
- `-- WRITE`: Queries that insert, modify, or delete database rows (`INSERT`, `UPDATE`, `DELETE`).

---

### Section 1: User Registration & Authentication

#### Query R1: Check Email Availability
```sql
-- READ
SELECT user_id, email
  FROM users
 WHERE LOWER(email) = LOWER($1);
```
- **What it does:** Searches for an existing user account with the candidate email.
- **Why needed:** Prevents creating duplicate accounts with the same email.
- **Tables used:** `users`.
- **Output:** Returns `user_id` and `email` if found; 0 rows if available.
- **Classification:** **READ** because it only reads data from disk.

#### Query W1: Register New User Account
```sql
-- WRITE
INSERT INTO users (name, email, password_hash)
VALUES ($1, LOWER($2), $3)
RETURNING user_id, name, email, created_at;
```
- **What it does:** Inserts a new user record with a pre-hashed password.
- **Why needed:** Creates the customer account identity.
- **Tables used:** `users`.
- **Output:** Returns the generated `user_id` and creation timestamp.
- **Classification:** **WRITE** because it inserts a new row.

#### Query W2: Initialize Demo Wallet
```sql
-- WRITE
INSERT INTO wallets (user_id, balance)
VALUES ($1, 1000.00)
RETURNING wallet_id, user_id, balance, updated_at;
```
- **What it does:** Creates a wallet row linked to the new user with an initial balance of \$1,000.00.
- **Why needed:** Every user needs a demo balance to test payments.
- **Tables used:** `wallets`.
- **Output:** Returns `wallet_id` and starting balance.
- **Classification:** **WRITE** because it inserts a new row.

#### Query R2: Authenticate User Login
```sql
-- READ
SELECT user_id, name, email, password_hash
  FROM users
 WHERE LOWER(email) = LOWER($1);
```
- **What it does:** Retrieves the stored bcrypt password hash for the supplied email.
- **Why needed:** The backend compares the typed password against the hash using `bcrypt.compare()`.
- **Tables used:** `users`.
- **Output:** User identity and password hash.
- **Classification:** **READ** because it only reads existing credentials.

#### Query R3: User Profile with Wallet Balance (INNER JOIN)
```sql
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
```
- **What it does:** Combines user demographic data and digital wallet balance into one record.
- **Why needed:** Allows the dashboard UI to display the user's name and balance in a single database round-trip.
- **Tables used:** `users` (aliased as `u`) and `wallets` (aliased as `w`).
- **Output:** A single row containing profile details and wallet funds.
- **Classification:** **READ** because it reads and combines data.

---

### Section 2: Biometric Template Enrollment & Verification

#### Query W3: Enroll Biometric Template
```sql
-- WRITE
INSERT INTO biometric_templates (user_id, template_reference, method)
VALUES ($1, $2, $3)
RETURNING template_id, user_id, method, created_at;
```
- **What it does:** Stores the processed palm-vein feature representation or vault reference.
- **Why needed:** The system must save the user's enrolled biometric pattern so future palm scans can be compared against it.
- **Tables used:** `biometric_templates`.
- **Output:** Generated `template_id` and enrollment timestamp.
- **Classification:** **WRITE** because it writes new biometric data.

#### Query R4: Retrieve Biometric Template with User Verification (INNER JOIN)
```sql
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
```
- **What it does:** Retrieves the latest biometric template for a user while simultaneously confirming that the user account is valid.
- **Why needed:** When the user scans their hand to pay, the system must fetch their baseline enrolled template to compute similarity.
- **Tables used:** `biometric_templates` and `users`.
- **Output:** The enrolled template vector reference, method, and user identity.
- **Classification:** **READ** because it reads data.

#### Query W4: Delete / Reset Biometric Enrollment
```sql
-- WRITE
DELETE FROM biometric_templates
 WHERE user_id = $1;
```
- **What it does:** Deletes existing enrolled templates for a user.
- **Why needed:** Needed when a user requests biometric re-enrollment or account data reset.
- **Tables used:** `biometric_templates`.
- **Output:** Removes matching rows from disk.
- **Classification:** **WRITE** because it removes stored records.

---

### Section 3: Security & Biometric Audit Logging

#### Query W5: Insert Authentication Audit Log
```sql
-- WRITE
INSERT INTO auth_logs (user_id, method, result, score)
VALUES ($1, $2, $3, $4)
RETURNING auth_log_id, user_id, method, result, score, created_at;
```
- **What it does:** Appends a new security log entry for every verification attempt (recording outcome and match score).
- **Why needed:** Essential for cybersecurity audit trails, dispute resolution, and false acceptance/rejection analysis.
- **Tables used:** `auth_logs`.
- **Output:** Generated `auth_log_id` and log timestamp.
- **Classification:** **WRITE** because it inserts audit records.

#### Query R5: Retrieve User Audit Logs (LEFT JOIN)
```sql
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
```
- **What it does:** Retrieves verification logs enriched with the user's name.
- **Why needed:** Allows users and administrators to audit login and payment verification history.
- **Why LEFT JOIN:** `auth_logs.user_id` is nullable (anonymous or failed scans without identified accounts). A `LEFT JOIN` ensures no audit rows are discarded even if `user_id` is null.
- **Tables used:** `auth_logs` and `users`.
- **Output:** Historical log rows ordered newest first.
- **Classification:** **READ** because it retrieves history.

---

### Section 4: Merchant Catalog & Validation

#### Query R6: List Active Merchants
```sql
-- READ
SELECT merchant_id,
       name,
       category
  FROM merchants
 WHERE active = TRUE
 ORDER BY name ASC;
```
- **What it does:** Fetches all operational merchants sorted alphabetically.
- **Why needed:** Populates the merchant selection dropdown in the payment UI.
- **Tables used:** `merchants`.
- **Output:** List of merchant names and business categories.
- **Classification:** **READ**.

#### Query R7: Validate Merchant Status
```sql
-- READ
SELECT merchant_id,
       name,
       category,
       active
  FROM merchants
 WHERE merchant_id = $1
   AND active = TRUE;
```
- **What it does:** Checks if a specific merchant exists and is currently accepting payments.
- **Why needed:** Prevents payments from being sent to disabled or non-existent merchants.
- **Tables used:** `merchants`.
- **Output:** 1 row if valid; 0 rows if invalid or disabled.
- **Classification:** **READ**.

---

### Section 5: Wallet Operations & Concurrency Control

#### Query R8: Fetch Current Wallet Balance
```sql
-- READ
SELECT wallet_id,
       user_id,
       balance,
       updated_at
  FROM wallets
 WHERE user_id = $1;
```
- **What it does:** Reads the current balance for an account.
- **Why needed:** Displays available balance in the navbar and payment screen.
- **Tables used:** `wallets`.
- **Output:** Current numeric balance.
- **Classification:** **READ**.

#### Query R9: Pessimistic Row Lock (`SELECT ... FOR UPDATE`)
```sql
-- READ
SELECT wallet_id,
       user_id,
       balance
  FROM wallets
 WHERE user_id = $1
   FOR UPDATE;
```
- **What it does:** Reads the user's balance and simultaneously places an exclusive row-level lock on the wallet row.
- **Why needed:** **Prevents Race Conditions and Double-Spending!** If a user initiates two simultaneous payments of \$100 with only \$100 in their account, both requests might pass the balance check if executed simultaneously. `FOR UPDATE` forces the second transaction to wait until the first transaction commits, preventing fraud.
- **Tables used:** `wallets`.
- **Output:** The locked balance record.
- **Classification:** **READ** (it retrieves data while holding an ACID row lock).

#### Query W6: Debit Wallet Balance
```sql
-- WRITE
UPDATE wallets
   SET balance    = balance - $1,
       updated_at = CURRENT_TIMESTAMP
 WHERE user_id = $2
   AND balance >= $1
 RETURNING wallet_id, user_id, balance, updated_at;
```
- **What it does:** Subtracts the payment amount from the wallet balance.
- **Why needed:** Deducts funds when a payment succeeds.
- **Crucial check:** `AND balance >= $1` provides a double-check at the database level to ensure balance never becomes negative.
- **Tables used:** `wallets`.
- **Output:** Updated balance and timestamp.
- **Classification:** **WRITE** because it mutates data.

---

### Section 6: Payment Transactions & Ledger

#### Query W7: Record Completed Payment
```sql
-- WRITE
INSERT INTO transactions (user_id, merchant_id, amount, status, reference)
VALUES ($1, $2, $3, 'completed', $4)
RETURNING transaction_id, user_id, merchant_id, amount, status, reference, created_at;
```
- **What it does:** Creates an official entry in the simulated payment ledger.
- **Why needed:** Serves as the permanent financial audit record connecting customer, merchant, amount, and reference code.
- **Tables used:** `transactions`.
- **Output:** Generated `transaction_id` and timestamp.
- **Classification:** **WRITE**.

#### Query R10: Check Idempotency by Reference
```sql
-- READ
SELECT transaction_id,
       status,
       amount,
       created_at
  FROM transactions
 WHERE reference = $1;
```
- **What it does:** Checks if a transaction reference key was already processed.
- **Why needed:** **Idempotency.** If a mobile device loses Wi-Fi connection right as the payment succeeds and retries sending the request, this query detects that the transaction was already created and avoids charging the customer twice.
- **Tables used:** `transactions`.
- **Output:** Existing transaction details if previously processed.
- **Classification:** **READ**.

#### Query R11: User Transaction History (INNER JOIN)
```sql
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
```
- **What it does:** Retrieves a customer's transaction history enriched with merchant names and business categories.
- **Why needed:** In the database, `transactions` only stores `merchant_id` (e.g. 5). The user wants to see "Campus Coffee Bar", not "5". An `INNER JOIN` bridges this gap.
- **Tables used:** `transactions` and `merchants`.
- **Output:** Transaction list ordered from newest to oldest.
- **Classification:** **READ**.

#### Query R12: Multi-Table Transaction Receipt Lookup (3-TABLE INNER JOIN)
```sql
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
```
- **What it does:** Joins three tables (`transactions`, `users`, `merchants`) to generate a complete payment receipt voucher.
- **Why needed:** A full receipt requires customer information (from `users`), payment details (from `transactions`), and store details (from `merchants`).
- **Tables used:** `transactions`, `users`, `merchants`.
- **Output:** One complete invoice record.
- **Classification:** **READ**.

---

### Section 7: Aggregate Queries & Financial Analytics

#### Query R13: Spending Aggregated by Merchant Category
```sql
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
```
- **What it does:** Uses SQL aggregate functions (`COUNT`, `SUM`, `AVG`) grouped by merchant category.
- **Why needed:** Provides personal budgeting insights (e.g., "You spent \$240 on Dining across 12 visits, average \$20 per visit").
- **Tables used:** `transactions` and `merchants`.
- **Output:** One summary row per spending category.
- **Classification:** **READ**.

#### Query R14: Merchant Revenue & Volume Summary (LEFT JOIN + AGGREGATE)
```sql
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
```
- **What it does:** Calculates total gross revenue and number of completed orders for every merchant.
- **Why LEFT JOIN:** If a newly registered merchant has zero sales, an `INNER JOIN` would omit them entirely. A `LEFT JOIN` ensures all active merchants appear in the report, showing \$0.00 revenue via `COALESCE`.
- **Tables used:** `merchants` and `transactions`.
- **Output:** Revenue report per merchant.
- **Classification:** **READ**.

#### Query R15: User Monthly Spending Breakdown
```sql
-- READ
SELECT DATE_TRUNC('month', created_at) AS transaction_month,
       COUNT(transaction_id) AS monthly_transaction_count,
       SUM(amount) AS monthly_total_spent
  FROM transactions
 WHERE user_id = $1
   AND status = 'completed'
 GROUP BY DATE_TRUNC('month', created_at)
 ORDER BY transaction_month DESC;
```
- **What it does:** Groups payments by month using `DATE_TRUNC` and sums monthly expenditures.
- **Why needed:** Powers historical spending bar charts on the user analytics tab.
- **Tables used:** `transactions`.
- **Output:** Total payments and money spent per month.
- **Classification:** **READ**.

---

## 5. Understanding SQL JOINs in PalmPay

### What is a JOIN?
A **JOIN** is an SQL operation used to combine rows from two or more tables based on a related column between them (usually a Primary Key in one table and a Foreign Key in another).

### Why Do We Need JOINs?
Because of **Database Normalization (3NF)**!  
In CP1, we decomposed one giant unnormalized table into smaller, focused tables (`users`, `merchants`, `transactions`, `wallets`) to eliminate duplicate data.  
JOINs allow us to reconstruct meaningful information when querying without storing redundant text in multiple places.

### What is an INNER JOIN?
An **INNER JOIN** returns only the rows where there is a match in **both** tables. If a row in Table A does not match any row in Table B, it is excluded from the result.

```
Table A (users)         Table B (wallets)
[ user_id: 1 ] <======> [ user_id: 1 ]   --> Included in result!
[ user_id: 2 ]          (no wallet)       --> EXCLUDED!
```

*PalmPay Example (Query R11):*
```sql
SELECT t.transaction_id, t.amount, m.name AS merchant_name
  FROM transactions t
  JOIN merchants m ON t.merchant_id = m.merchant_id;
```
Every transaction is guaranteed to have a valid merchant, so `INNER JOIN` cleanly joins each transaction with its merchant name.

### What is a LEFT JOIN?
A **LEFT JOIN** (or LEFT OUTER JOIN) returns **all** rows from the left table, along with matching rows from the right table. If there is no match on the right side, the result contains `NULL` values for the right table's columns.

```
Left Table (merchants)     Right Table (transactions)
[ merchant_id: 1 (Cafe) ] <---> [ t_id: 101, amount: $10 ]  --> Returned with $10
[ merchant_id: 2 (Tech) ]       (no transactions yet)       --> Returned with NULL / $0!
```

*PalmPay Example (Query R14):*
When computing merchant revenue, we want to see **all active merchants**, even if they just joined today and have zero sales. A `LEFT JOIN` keeps them in the report!

### Key Difference Summary
| Feature | `INNER JOIN` | `LEFT JOIN` |
|---|---|---|
| **Matching condition** | Requires match in both tables | Returns all rows from Left table |
| **Unmatched rows** | Discarded completely | Preserved from Left table (Right table columns are `NULL`) |
| **When to use in PalmPay** | Fetching transaction receipts, user profiles | Merchant revenue reports, audit logs with nullable user IDs |

---

## 6. Concurrency Control: Why `FOR UPDATE` Matters

In a financial system, multiple transactions can attempt to access the same wallet at the exact same moment.

### The Double-Spending Vulnerability (Without Concurrency Control):
1. User has balance = \$100.00.
2. Request 1 (Payment of \$100 at Cafe) arrives. Express reads balance = \$100.00.
3. Request 2 (Payment of \$100 at Bookstore) arrives 1 millisecond later. Express reads balance = \$100.00.
4. Both requests verify that \$100 >= \$100.
5. Request 1 debits \$100 $\rightarrow$ new balance = \$0.
6. Request 2 debits \$100 $\rightarrow$ overdraft error or \$200 worth of purchases for \$100!

### The PalmPay Solution:
PalmPay wraps the payment in an atomic PostgreSQL transaction with a **pessimistic row lock**:
```sql
BEGIN;
SELECT balance FROM wallets WHERE user_id = $1 FOR UPDATE;
-- (Row is now locked! Other requests for this user must wait)
UPDATE wallets SET balance = balance - $2 WHERE user_id = $1;
INSERT INTO transactions (...) VALUES (...);
COMMIT;
-- (Row lock is released)
```
The `FOR UPDATE` lock guarantees serial execution per wallet, completely eliminating double-spending bugs.

---

## 7. 25 Essential Viva Questions & Answers

### Q1: What is the main objective of the PalmPay project?
**Answer:** PalmPay simulates a contactless, cashless payment system where users authenticate payments using their near-infrared (NIR) palm-vein biometrics linked to a virtual demo wallet.

### Q2: Why did we choose PostgreSQL as the database?
**Answer:** PostgreSQL is an enterprise-grade relational database known for strict ACID compliance, strong support for check constraints, foreign keys, row-level locking (`FOR UPDATE`), and indexing performance.

### Q3: What is the difference between a READ query and a WRITE query?
**Answer:** A READ query (such as `SELECT`) retrieves existing data without altering the state of the database. A WRITE query (such as `INSERT`, `UPDATE`, or `DELETE`) alters, creates, or removes data stored on disk.

### Q4: How many queries are in `dbms/04_queries.sql`, and how are they classified?
**Answer:** There are 22 queries in total: 15 READ queries (including profile lookups, merchant catalogs, history, and analytics) and 7 WRITE queries (covering user registration, wallet setup, biometric enrollment, audit logging, debits, and transaction recording).

### Q5: What is a Primary Key and give an example from PalmPay?
**Answer:** A Primary Key uniquely identifies each row in a table. In PalmPay, `user_id` in `users` and `transaction_id` in `transactions` are primary keys generated using `BIGINT GENERATED ALWAYS AS IDENTITY`.

### Q6: What is a Foreign Key and give an example?
**Answer:** A Foreign Key is a field in one table that references the Primary Key of another table to maintain referential integrity. In PalmPay, `transactions.user_id` is a foreign key referencing `users.user_id`.

### Q7: What does `ON DELETE RESTRICT` mean in our `transactions` table?
**Answer:** `ON DELETE RESTRICT` prevents any user or merchant from being deleted if they have existing payment transactions in the ledger. This protects the financial audit trail from accidental deletion.

### Q8: What does `ON DELETE CASCADE` mean in our `wallets` table?
**Answer:** `ON DELETE CASCADE` ensures that if a user account is deleted, their corresponding wallet row is automatically removed by the database to prevent orphaned records.

### Q9: Why is `user_id` nullable in `auth_logs`?
**Answer:** `auth_logs` captures all authentication attempts. If an unknown person attempts to scan an unregistered palm or someone tries an invalid login, there is no associated `user_id`. Making `user_id` nullable allows the system to log security events without foreign key violations.

### Q10: What is an INNER JOIN and where is it used in PalmPay?
**Answer:** An `INNER JOIN` returns only rows that have matching values in both joined tables. It is used in Query R11 to join `transactions` with `merchants` to display the merchant's business name on the customer's receipt.

### Q11: What is a LEFT JOIN and where is it used in PalmPay?
**Answer:** A `LEFT JOIN` returns all records from the left table and matched records from the right table. It is used in Query R14 (Merchant Revenue Analytics) so that newly registered merchants with zero transactions still appear in the report with \$0 revenue.

### Q12: Why are parameterized queries (`$1, $2`) used instead of string concatenation?
**Answer:** Parameterized queries separate SQL commands from user input, completely preventing **SQL Injection (SQLi)** attacks. The database treats parameters strictly as data, never as executable code.

### Q13: Why do we use `LOWER(email)` in user queries?
**Answer:** Email addresses are case-insensitive by standard (`Alice@test.com` and `alice@test.com` are the same). Using `LOWER(email)` in queries and unique indexes guarantees that duplicate accounts cannot be created using different capitalization.

### Q14: How does PalmPay prevent users from spending more money than they have?
**Answer:** It uses three layers of protection:
1. Application layer checks: Express checks `currentBalance >= amount`.
2. Concurrency locking: `SELECT balance FROM wallets ... FOR UPDATE`.
3. Database constraint: `wallets` has `CHECK (balance >= 0.00)`.

### Q15: What is the purpose of `SELECT ... FOR UPDATE` (Query R9)?
**Answer:** It places an exclusive row-level lock on the user's wallet during checkout. This prevents concurrent requests from causing double-spending race conditions.

### Q16: What is idempotency and how is it implemented in PalmPay?
**Answer:** Idempotency means executing the same request multiple times produces the exact same result without duplicate charges. PalmPay requires each payment to carry a unique `reference` key. The database enforces `UNIQUE (reference)` on `transactions`, rejecting duplicate submissions.

### Q17: What is the difference between 1NF, 2NF, and 3NF?
**Answer:**
- **1NF:** Values in each cell are atomic; no repeating groups.
- **2NF:** In 1NF and all non-key attributes are fully dependent on the primary key (no partial dependencies).
- **3NF:** In 2NF and no non-key attribute depends transitively on another non-key attribute (no transitive dependencies).

### Q18: What tables does Query R12 join and why?
**Answer:** Query R12 joins three tables: `transactions`, `users`, and `merchants`. It is used to generate a full invoice containing the customer's name/email, the merchant's name/category, and the transaction amount/timestamp.

### Q19: Why do we store password hashes rather than plaintext passwords?
**Answer:** For security compliance. If the database is ever compromised, attackers cannot read user passwords. PalmPay uses `bcrypt` with salt rounds $\ge 12$.

### Q20: What aggregate functions are used in `04_queries.sql`?
**Answer:**
- `COUNT()`: Counts the number of transactions.
- `SUM()`: Sums total monetary spend or merchant revenue.
- `AVG()`: Calculates average transaction values.
- `ROUND()`: Formats decimal averages for currency display.

### Q21: What is the purpose of `DATE_TRUNC('month', created_at)` in Query R15?
**Answer:** `DATE_TRUNC` rounds a timestamp down to the first day of that month, allowing `GROUP BY` to aggregate all payment amounts by calendar month for budgeting analytics.

### Q22: Why does `merchants` use an `active` boolean flag instead of deleting rows?
**Answer:** This is a **Soft Delete**. Deleting a merchant would violate foreign key constraints on past transactions. Setting `active = FALSE` prevents future payments while preserving historical audit ledgers.

### Q23: Why do we use `NUMERIC(12, 2)` for currency balances instead of `FLOAT` or `DOUBLE`?
**Answer:** Floating-point numbers introduce binary rounding errors (e.g., $0.1 + 0.2 = 0.30000000000000004$). `NUMERIC(12, 2)` uses exact fixed-point arithmetic, essential for financial accuracy.

### Q24: What happens if an error occurs halfway through payment processing?
**Answer:** Because the operations are inside a PostgreSQL transaction (`BEGIN ... COMMIT`), any failure triggers `ROLLBACK`, restoring the wallet balance and leaving no orphan transaction record.

### Q25: How does the application connect to PostgreSQL?
**Answer:** It uses the Node.js `pg` library with a `Pool` configuration. The pool manages reusable database connections, minimizing connection latency for high-throughput queries.

---

*Prepared for PalmPay Capstone CP3 Evaluation.*
