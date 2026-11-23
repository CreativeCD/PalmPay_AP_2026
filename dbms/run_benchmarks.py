#!/usr/bin/env python3
"""
PalmPay CP4 Query Benchmarking Runner
Executes every query in dbms/04_queries.sql three times using
EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS) against PostgreSQL 18.6.
Generates:
  - dbms/plans/ (individual execution plan text files per query)
  - dbms/plans/summary.csv
  - dbms/05_query_timings.md
"""

import os
import re
import subprocess
import sys

PSQL_BIN = "/Applications/Postgres.app/Contents/Versions/18/bin/psql"
DB_NAME = "palmpay"
HOST = "localhost"

QUERIES = [
    {
        "id": "R01",
        "alt_id": "R1",
        "type": "READ",
        "desc": "Check if email address is already registered",
        "is_write": False,
        "prep": "",
        "sql": "SELECT user_id, email FROM users WHERE LOWER(email) = LOWER('alice@example.com');"
    },
    {
        "id": "W01",
        "alt_id": "W1",
        "type": "WRITE",
        "desc": "Register a new user account with hashed password",
        "is_write": True,
        "prep": "",
        "sql": "INSERT INTO users (name, email, password_hash) VALUES ('Bench New User', LOWER('bench.newuser@palmpay.internal'), '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x') RETURNING user_id, name, email, created_at;"
    },
    {
        "id": "W02",
        "alt_id": "W2",
        "type": "WRITE",
        "desc": "Provision default demo wallet for newly registered user",
        "is_write": True,
        "prep": "INSERT INTO users (name, email, password_hash) VALUES ('Temp Wallet User', 'temp.wallet.user@palmpay.internal', '$2b$12$hash');",
        "sql": "INSERT INTO wallets (user_id, balance) VALUES (currval('users_user_id_seq'), 1000.00) RETURNING wallet_id, user_id, balance, updated_at;"
    },
    {
        "id": "R02",
        "alt_id": "R2",
        "type": "READ",
        "desc": "Authenticate user login credentials by email",
        "is_write": False,
        "prep": "",
        "sql": "SELECT user_id, name, email, password_hash FROM users WHERE LOWER(email) = LOWER('alice@example.com');"
    },
    {
        "id": "R03",
        "alt_id": "R3",
        "type": "READ",
        "desc": "Get authenticated user profile with wallet summary (JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT u.user_id,
       u.name,
       u.email,
       u.created_at AS member_since,
       w.wallet_id,
       w.balance,
       w.updated_at AS balance_last_updated
  FROM users u
  JOIN wallets w ON u.user_id = w.user_id
 WHERE u.user_id = 1;"""
    },
    {
        "id": "W03",
        "alt_id": "W3",
        "type": "WRITE",
        "desc": "Enroll or update user biometric template",
        "is_write": True,
        "prep": "",
        "sql": "INSERT INTO biometric_templates (user_id, template_reference, method) VALUES (1, 'vault://palm/templates/nir_v1_user_1_bench.bin', 'NIR_SENSOR_V1') RETURNING template_id, user_id, method, created_at;"
    },
    {
        "id": "R04",
        "alt_id": "R4",
        "type": "READ",
        "desc": "Retrieve latest biometric template with user verification (JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT bt.template_id,
       bt.user_id,
       u.name,
       u.email,
       bt.template_reference,
       bt.method,
       bt.created_at
  FROM biometric_templates bt
  JOIN users u ON bt.user_id = u.user_id
 WHERE bt.user_id = 1
 ORDER BY bt.created_at DESC
 LIMIT 1;"""
    },
    {
        "id": "W04",
        "alt_id": "W4",
        "type": "WRITE",
        "desc": "Reset / Delete existing biometric template enrollment",
        "is_write": True,
        "prep": "",
        "sql": "DELETE FROM biometric_templates WHERE user_id = 1;"
    },
    {
        "id": "W05",
        "alt_id": "W5",
        "type": "WRITE",
        "desc": "Insert authentication / biometric audit log record",
        "is_write": True,
        "prep": "",
        "sql": "INSERT INTO auth_logs (user_id, method, result, score) VALUES (1, 'NIR_PALM_MATCH', 'passed', 0.8950) RETURNING auth_log_id, user_id, method, result, score, created_at;"
    },
    {
        "id": "R05",
        "alt_id": "R5",
        "type": "READ",
        "desc": "Retrieve user authentication audit logs with user details (LEFT JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT al.auth_log_id,
       al.user_id,
       COALESCE(u.name, 'Unauthenticated / Anonymous') AS user_name,
       u.email,
       al.method,
       al.result,
       al.score,
       al.created_at
  FROM auth_logs al
  LEFT JOIN users u ON al.user_id = u.user_id
 WHERE al.user_id = 1
 ORDER BY al.created_at DESC;"""
    },
    {
        "id": "R06",
        "alt_id": "R6",
        "type": "READ",
        "desc": "List all active merchants for payment checkout",
        "is_write": False,
        "prep": "",
        "sql": "SELECT merchant_id, name, category FROM merchants WHERE active = TRUE ORDER BY name ASC;"
    },
    {
        "id": "R07",
        "alt_id": "R7",
        "type": "READ",
        "desc": "Validate merchant status for payment processing",
        "is_write": False,
        "prep": "",
        "sql": "SELECT merchant_id, name, category, active FROM merchants WHERE merchant_id = 1 AND active = TRUE;"
    },
    {
        "id": "R08",
        "alt_id": "R8",
        "type": "READ",
        "desc": "Fetch current wallet balance for authenticated user",
        "is_write": False,
        "prep": "",
        "sql": "SELECT wallet_id, user_id, balance, updated_at FROM wallets WHERE user_id = 1;"
    },
    {
        "id": "R09",
        "alt_id": "R9",
        "type": "READ",
        "desc": "Lock wallet row for atomic payment deduction (Concurrency Control)",
        "is_write": True, # Runs in transaction block
        "prep": "",
        "sql": "SELECT wallet_id, user_id, balance FROM wallets WHERE user_id = 1 FOR UPDATE;"
    },
    {
        "id": "W06",
        "alt_id": "W6",
        "type": "WRITE",
        "desc": "Debit wallet balance following successful biometric authorization",
        "is_write": True,
        "prep": "",
        "sql": "UPDATE wallets SET balance = balance - 10.00, updated_at = CURRENT_TIMESTAMP WHERE user_id = 1 AND balance >= 10.00 RETURNING wallet_id, user_id, balance, updated_at;"
    },
    {
        "id": "W07",
        "alt_id": "W7",
        "type": "WRITE",
        "desc": "Record completed payment transaction in audit ledger",
        "is_write": True,
        "prep": "",
        "sql": "INSERT INTO transactions (user_id, merchant_id, amount, status, reference) VALUES (1, 1, 15.00, 'completed', 'TXN-BENCH-ROLLBACK-W7') RETURNING transaction_id, user_id, merchant_id, amount, status, reference, created_at;"
    },
    {
        "id": "R10",
        "alt_id": "R10",
        "type": "READ",
        "desc": "Check transaction reference uniqueness (Idempotency Guard)",
        "is_write": False,
        "prep": "",
        "sql": "SELECT transaction_id, status, amount, created_at FROM transactions WHERE reference = 'TXN-2026-000001';"
    },
    {
        "id": "R11",
        "alt_id": "R11",
        "type": "READ",
        "desc": "Retrieve user transaction history with merchant details (JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT t.transaction_id,
       t.amount,
       t.status,
       t.reference,
       t.created_at,
       m.merchant_id,
       m.name AS merchant_name,
       m.category AS merchant_category
  FROM transactions t
  JOIN merchants m ON t.merchant_id = m.merchant_id
 WHERE t.user_id = 1
 ORDER BY t.created_at DESC;"""
    },
    {
        "id": "R12",
        "alt_id": "R12",
        "type": "READ",
        "desc": "Comprehensive transaction receipt lookup (MULTI-TABLE JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT t.transaction_id,
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
 WHERE t.transaction_id = 1;"""
    },
    {
        "id": "R13",
        "alt_id": "R13",
        "type": "READ",
        "desc": "User expenditure summary aggregated by merchant category (AGGREGATE + JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT m.category,
       COUNT(t.transaction_id) AS total_transactions,
       SUM(t.amount) AS total_spent,
       ROUND(AVG(t.amount), 2) AS avg_transaction_amount
  FROM transactions t
  JOIN merchants m ON t.merchant_id = m.merchant_id
 WHERE t.user_id = 1
   AND t.status = 'completed'
 GROUP BY m.category
 ORDER BY total_spent DESC;"""
    },
    {
        "id": "R14",
        "alt_id": "R14",
        "type": "READ",
        "desc": "Merchant total revenue and transaction volume summary (AGGREGATE + JOIN)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT m.merchant_id,
       m.name AS merchant_name,
       m.category,
       COUNT(t.transaction_id) AS total_sales_count,
       COALESCE(SUM(t.amount), 0.00) AS total_revenue
  FROM merchants m
  LEFT JOIN transactions t ON m.merchant_id = t.merchant_id
                          AND t.status = 'completed'
 WHERE m.active = TRUE
 GROUP BY m.merchant_id, m.name, m.category
 ORDER BY total_revenue DESC;"""
    },
    {
        "id": "R15",
        "alt_id": "R15",
        "type": "READ",
        "desc": "User monthly spending summary (AGGREGATE DATE_TRUNC)",
        "is_write": False,
        "prep": "",
        "sql": """SELECT DATE_TRUNC('month', created_at) AS transaction_month,
       COUNT(transaction_id) AS monthly_transaction_count,
       SUM(amount) AS monthly_total_spent
  FROM transactions
 WHERE user_id = 1
   AND status = 'completed'
 GROUP BY DATE_TRUNC('month', created_at)
 ORDER BY transaction_month DESC;"""
    }
]

def run_psql(cmd_text):
    res = subprocess.run(
        [PSQL_BIN, "-h", HOST, "-d", DB_NAME, "-A", "-t", "-c", cmd_text],
        capture_output=True,
        text=True,
        check=True
    )
    return res.stdout.strip()

def extract_times_and_scans(plan_text):
    exec_match = re.search(r"Execution Time:\s+([0-9.]+)\s+ms", plan_text)
    exec_time = float(exec_match.group(1)) if exec_match else 0.0
    
    plan_match = re.search(r"Planning Time:\s+([0-9.]+)\s+ms", plan_text)
    plan_time = float(plan_match.group(1)) if plan_match else 0.0

    # Extract scan nodes
    scans = set()
    for line in plan_text.splitlines():
        if "Scan on " in line:
            m = re.search(r"((?:Index|Index Only|Bitmap Index|Bitmap Heap|Seq) Scan(?: using \w+)? on \w+)", line)
            if m:
                scans.add(m.group(1).strip())
        elif "Insert on " in line:
            scans.add("Insert")
        elif "Update on " in line:
            scans.add("Update")
        elif "Delete on " in line:
            scans.add("Delete")
            
    scan_str = " | ".join(sorted(scans)) if scans else "Direct Table Operation"
    return exec_time, plan_time, scan_str

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    plans_dir = os.path.join(base_dir, "plans")
    os.makedirs(plans_dir, exist_ok=True)

    results = []

    print("====================================================================")
    print(" PalmPay CP4 Query Benchmarking Suite (PostgreSQL 18.6)")
    print(" Database: palmpay | Host: localhost:5432")
    print("====================================================================")

    for item in QUERIES:
        qid = item["id"]
        alt_id = item["alt_id"]
        qtype = item["type"]
        desc = item["desc"]
        is_write = item["is_write"]
        prep = item["prep"]
        sql = item["sql"]

        print(f"\nBenchmarking [{qid} / {alt_id}] ({qtype}): {desc}...")

        plan_outputs = []
        times = []
        scan_nodes = set()

        for run in range(1, 4):
            if is_write:
                full_cmd = f"BEGIN;\n{prep}\nEXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS) {sql}\nROLLBACK;"
            else:
                full_cmd = f"EXPLAIN (ANALYZE, BUFFERS, VERBOSE, SETTINGS) {sql}"

            out = run_psql(full_cmd)
            # Remove psql transaction boundary echoes (BEGIN/ROLLBACK)
            clean_lines = []
            for line in out.splitlines():
                if line.strip() in ("BEGIN", "ROLLBACK"):
                    continue
                clean_lines.append(line)
            clean_plan = "\n".join(clean_lines).strip()

            exec_time, plan_time, scan_info = extract_times_and_scans(clean_plan)
            times.append(exec_time)
            if scan_info != "Direct Table Operation":
                scan_nodes.add(scan_info)

            plan_outputs.append(f"=== {qid} run {run} ===\n{clean_plan}")
            print(f"  Run {run}: Execution Time = {exec_time:.3f} ms | Planning Time = {plan_time:.3f} ms")

        avg_time = sum(times) / len(times)
        combined_scans = " | ".join(sorted(scan_nodes)) if scan_nodes else "Direct Operation"

        # Write plan file (both R01.txt and R1.txt for complete compatibility)
        plan_content = "\n\n".join(plan_outputs) + "\n"
        with open(os.path.join(plans_dir, f"{qid}.txt"), "w") as f:
            f.write(plan_content)
        with open(os.path.join(plans_dir, f"{alt_id}.txt"), "w") as f:
            f.write(plan_content)

        results.append({
            "id": qid,
            "alt_id": alt_id,
            "type": qtype,
            "desc": desc,
            "run1": times[0],
            "run2": times[1],
            "run3": times[2],
            "avg": avg_time,
            "scans": combined_scans
        })

    # Write summary.csv
    csv_path = os.path.join(plans_dir, "summary.csv")
    with open(csv_path, "w") as f:
        f.write("query_id,alt_id,type,description,run1_ms,run2_ms,run3_ms,avg_ms,scan_nodes\n")
        for r in results:
            f.write(f"{r['id']},{r['alt_id']},{r['type']},\"{r['desc']}\",{r['run1']:.3f},{r['run2']:.3f},{r['run3']:.3f},{r['avg']:.3f},\"{r['scans']}\"\n")

    print("\n✓ Plans saved to dbms/plans/")
    print(f"✓ Summary CSV written to {csv_path}")

    return results

if __name__ == "__main__":
    main()
