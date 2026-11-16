# PalmPay — Database Normalization (1NF, 2NF and 3NF)

**Project:** PalmPay — NIR-Based Palm-Vein Biometric Authentication and Payment Simulation System  
**Target:** Relational SQL database (PostgreSQL or MySQL; final engine to be selected by the team)

## 1. Purpose and assumptions

PalmPay stores user accounts, biometric enrollment references, wallet balances, merchants, simulated payments and authentication attempts. Normalization reduces duplicate data and helps prevent insertion, update and deletion anomalies.

Assumptions:
- Each user has one demo wallet.
- A user may have multiple biometric enrollment records.
- A merchant may receive multiple transactions.
- A user may make multiple transactions.
- Authentication attempts are recorded separately from payments.
- Payments are simulated; this system does not store or process real banking/UPI transactions.

## 2. Unnormalized form (UNF)

A single unnormalized record might contain repeating lists:

| user_id | user_name | email | wallet_balance | biometric_records | payments | auth_attempts |
|---|---|---|---:|---|---|---|
| U01 | Asha | asha@example.com | 1500.00 | `[(B01, template-A), (B02, template-B)]` | `[(M01, Cafe, 100), (M02, Books, 250)]` | `[(success, 0.91), (failed, 0.42)]` |

The `biometric_records`, `payments` and `auth_attempts` columns contain multiple values. These repeating groups make individual records difficult to query and update.

## 3. First Normal Form (1NF)

A relation is in 1NF when every cell contains one atomic value, there are no repeating groups, and each row can be uniquely identified.

The repeating payment list is converted into separate rows:

### PAYMENT_RECORD_1NF

| transaction_id (PK) | user_id | user_name | email | wallet_balance | merchant_id | merchant_name | amount | status |
|---|---|---|---|---:|---|---|---:|---|
| T01 | U01 | Asha | asha@example.com | 1500.00 | M01 | Cafe | 100.00 | SUCCESS |
| T02 | U01 | Asha | asha@example.com | 1500.00 | M02 | Books | 250.00 | SUCCESS |

Each cell now contains a single value and each payment has its own row. This satisfies 1NF.

**Remaining issue:** User and merchant information is repeated in multiple payment rows. Changing Asha's email, for example, would require updating multiple rows. This can cause update anomalies. Biometric enrollments and authentication attempts must similarly be stored as separate rows, not lists in a user record.

## 4. Second Normal Form (2NF)

A relation is in 2NF when it is in 1NF and every non-key attribute depends on the whole candidate key, not just part of a composite key.

Consider an enrollment relation whose composite primary key is `(user_id, enrollment_no)`:

### ENROLLMENT_1NF

| user_id (PK part) | enrollment_no (PK part) | user_name | email | template_reference | capture_method | enrolled_at |
|---|---:|---|---|---|---|---|
| U01 | 1 | Asha | asha@example.com | template-A | NIR_DATASET | 2026-11-16 |
| U01 | 2 | Asha | asha@example.com | template-B | NIR_DATASET | 2026-11-17 |

Here:
- `template_reference`, `capture_method` and `enrolled_at` depend on the complete key `(user_id, enrollment_no)`.
- `user_name` and `email` depend only on `user_id`, which is part of the composite key.

Therefore, `user_name` and `email` are partially dependent on the key. The relation violates 2NF.

### Decomposition into 2NF relations

**USERS**

| user_id (PK) | user_name | email |
|---|---|---|
| U01 | Asha | asha@example.com |

**BIOMETRIC_ENROLLMENTS**

| user_id (PK part, FK) | enrollment_no (PK part) | template_reference | capture_method | enrolled_at |
|---|---:|---|---|---|
| U01 | 1 | template-A | NIR_DATASET | 2026-11-16 |
| U01 | 2 | template-B | NIR_DATASET | 2026-11-17 |

User details are now stored once in `USERS`; enrollment-specific attributes remain in `BIOMETRIC_ENROLLMENTS`. In the implementation, the team may use a generated `template_id` primary key instead of the composite key, while keeping the same logical separation.

## 5. Third Normal Form (3NF)

A relation is in 3NF when it is in 2NF and non-key attributes do not depend transitively on a key through another non-key attribute.

Consider:

`PAYMENT_RECORD(transaction_id, user_id, user_name, email, merchant_id, merchant_name, merchant_category, amount, status)`

Functional dependencies include:
- `transaction_id → user_id, merchant_id, amount, status`
- `user_id → user_name, email`
- `merchant_id → merchant_name, merchant_category`

Thus user and merchant descriptive information depends on the transaction key through `user_id` and `merchant_id`. These are transitive dependencies.

### Final 3NF tables

#### USERS

| Column | Description |
|---|---|
| user_id (PK) | Unique user identifier |
| name | User's display name |
| email (UNIQUE) | Login email |
| password_hash | Bcrypt password hash; never plaintext |
| created_at | Account creation timestamp |

#### WALLETS

| Column | Description |
|---|---|
| wallet_id (PK) | Unique wallet identifier |
| user_id (FK, UNIQUE) | Wallet owner; one wallet per user |
| balance | Simulated wallet balance |
| updated_at | Last update timestamp |

#### BIOMETRIC_TEMPLATES

| Column | Description |
|---|---|
| template_id (PK) | Unique enrollment/template identifier |
| user_id (FK) | User who enrolled the template |
| template_reference | Template data or controlled storage reference |
| method | Actual acquisition/processing method used |
| created_at | Enrollment timestamp |

#### MERCHANTS

| Column | Description |
|---|---|
| merchant_id (PK) | Unique merchant identifier |
| name | Merchant name |
| category | Merchant category |
| active | Whether the demo merchant is active |

#### TRANSACTIONS

| Column | Description |
|---|---|
| transaction_id (PK) | Unique simulated payment identifier |
| user_id (FK) | User making the payment |
| merchant_id (FK) | Merchant receiving the payment |
| amount | Payment amount |
| status | Payment status |
| reference | Receipt/reference value |
| created_at | Payment timestamp |

#### AUTH_LOGS

| Column | Description |
|---|---|
| auth_log_id (PK) | Unique authentication-attempt identifier |
| user_id (FK) | User whose attempt is recorded |
| method | For example, ACCOUNT_LOGIN or PALM_VERIFY |
| result | SUCCESS or FAILURE |
| score | Optional biometric comparison score |
| created_at | Attempt timestamp |

The final design stores user details in `USERS`, merchant details in `MERCHANTS`, wallet data in `WALLETS`, enrollment data in `BIOMETRIC_TEMPLATES`, payment data in `TRANSACTIONS`, and authentication attempts in `AUTH_LOGS`. This removes the transitive dependencies from the payment relation.

## 6. Final relationship summary

- `USERS 1 — 1 WALLETS`: one demo wallet per user; enforce with `UNIQUE(WALLETS.user_id)`.
- `USERS 1 — MANY BIOMETRIC_TEMPLATES`: a user can enroll multiple templates.
- `USERS 1 — MANY TRANSACTIONS`: a user can make multiple simulated payments.
- `MERCHANTS 1 — MANY TRANSACTIONS`: a merchant can receive multiple simulated payments.
- `USERS 1 — MANY AUTH_LOGS`: a user can have multiple authentication attempts.

## 7. Why normalization matters in PalmPay

1. **Less duplication:** User and merchant details are not copied into every transaction row.
2. **Update consistency:** A user's email is changed in one place.
3. **Referential integrity:** Foreign keys ensure transactions refer to existing users and merchants.
4. **Payment consistency:** Wallet debit and transaction insertion can be performed atomically.
5. **Clear responsibilities:** Account, biometric, wallet, merchant, transaction and authentication data are separated.

## 8. Implementation notes

- Store password hashes, never plaintext passwords.
- Avoid storing raw palm images or biometric templates unless needed; restrict access and document the chosen storage method.
- Add foreign keys, unique constraints and appropriate indexes in the actual SQL schema.
- Use a SQL transaction for wallet debit and transaction insertion so a failure can be rolled back.
- The acquisition method is still under feasibility investigation. Record the actual method used rather than assuming physical hardware is confirmed.
- This document describes the intended logical design. Update it if the implemented schema differs.

## 9. Conclusion

PalmPay's data is transformed from repeating, multi-valued records into atomic 1NF rows, decomposed to remove partial dependencies in 2NF, and further decomposed to remove transitive dependencies in 3NF. The resulting relational design is easier to maintain and supports consistent account, biometric, wallet and simulated-payment operations.
