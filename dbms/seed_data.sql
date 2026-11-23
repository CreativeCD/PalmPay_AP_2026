-- ============================================================================
-- PalmPay Database Seed Dataset (PostgreSQL)
-- Generates a realistic academic capstone dataset for CP4 Benchmarking
-- ============================================================================

BEGIN;

-- 1. MERCHANTS (10 diverse campus and commercial outlets)
INSERT INTO merchants (name, category, active) VALUES
    ('Campus Cafeteria', 'Dining', TRUE),
    ('University Bookstore', 'Books & Stationery', TRUE),
    ('Student QuickMart', 'Convenience & Grocery', TRUE),
    ('Tech & Print Station', 'Services & Electronics', TRUE),
    ('Campus Coffee Bar', 'Dining', TRUE),
    ('Metro Transit Kiosk', 'Transit', TRUE),
    ('Gym & Recreation Center', 'Health & Fitness', TRUE),
    ('Campus Pharmacy', 'Health & Medicine', TRUE),
    ('Library Copy Center', 'Services', TRUE),
    ('Student Lounge Canteen', 'Dining', TRUE);

-- 2. USERS (2,500 realistic users)
-- Insert specific named users first
INSERT INTO users (name, email, password_hash, created_at) VALUES
    ('Alice Sharma', 'alice@example.com', '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x', '2026-01-15 08:30:00+00'),
    ('Vaibhav Gupta', 'vaibhav.gupta@nst.rishihood.edu.in', '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x', '2026-01-16 09:15:00+00'),
    ('Charan Durga', 'charan.durga@nst.rishihood.edu.in', '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x', '2026-01-16 09:30:00+00'),
    ('Sri Sai Deekshit', 'srisai.deekshit@nst.rishihood.edu.in', '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x', '2026-01-16 10:00:00+00'),
    ('Rusheel Chandra', 'rusheel.chandra@nst.rishihood.edu.in', '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x', '2026-01-16 10:15:00+00');

-- Insert remaining synthetic users up to 2,500
INSERT INTO users (name, email, password_hash, created_at)
SELECT
    'Student ' || i,
    'student' || i || '@palmpay.internal',
    '$2b$12$K8yR2u/pMv9.7x9gC2K9xOx4E2f7Z.4rK8yR2u/pMv9.7x9gC2K9x',
    TIMESTAMPTZ '2026-01-01 00:00:00+00' + (i * INTERVAL '2 hours')
FROM generate_series(6, 2500) AS i;

-- 3. WALLETS (2,500 wallets, strict 1:1 with users)
INSERT INTO wallets (user_id, balance, updated_at)
SELECT
    u.user_id,
    ROUND((100.00 + (random() * 900.00))::numeric, 2),
    u.created_at + INTERVAL '5 minutes'
FROM users u;

-- 4. BIOMETRIC TEMPLATES (2,500 enrolled templates)
INSERT INTO biometric_templates (user_id, template_reference, method, created_at)
SELECT
    u.user_id,
    'vault://palm/templates/nir_v1_user_' || u.user_id || '.bin',
    'NIR_SENSOR_V1',
    u.created_at + INTERVAL '10 minutes'
FROM users u;

-- 5. TRANSACTIONS (25,000 simulated payments across merchants and dates)
INSERT INTO transactions (user_id, merchant_id, amount, status, reference, created_at)
SELECT
    -- Heavy distribution for user_id 1 (Alice) to enable multi-record testing for R11, R13, R15
    CASE 
        WHEN s % 20 = 0 THEN 1 
        ELSE 1 + (s % 2500) 
    END AS user_id,
    1 + (s % 10) AS merchant_id,
    ROUND((5.00 + (random() * 245.00))::numeric, 2) AS amount,
    CASE 
        WHEN s % 30 = 0 THEN 'failed'
        WHEN s % 50 = 0 THEN 'pending'
        ELSE 'completed'
    END AS status,
    'TXN-2026-' || LPAD(s::text, 6, '0') AS reference,
    TIMESTAMPTZ '2026-01-15 00:00:00+00' + ((s * 18) * INTERVAL '1 minute') AS created_at
FROM generate_series(1, 25000) AS s;

-- 6. AUTH_LOGS (15,000 biometric and login verification audit logs)
INSERT INTO auth_logs (user_id, method, result, score, created_at)
SELECT
    CASE 
        WHEN s % 25 = 0 THEN NULL -- Unauthenticated / anonymous attempts
        WHEN s % 15 = 0 THEN 1    -- Frequent logs for user_id 1
        ELSE 1 + (s % 2500)
    END AS user_id,
    CASE 
        WHEN s % 4 = 0 THEN 'PASSWORD'
        WHEN s % 4 = 1 THEN 'PIN'
        ELSE 'NIR_PALM_MATCH'
    END AS method,
    CASE 
        WHEN s % 8 = 0 THEN 'failed'
        ELSE 'passed'
    END AS result,
    ROUND((0.5500 + (random() * 0.4400))::numeric, 4) AS score,
    TIMESTAMPTZ '2026-01-15 00:00:00+00' + ((s * 30) * INTERVAL '1 minute') AS created_at
FROM generate_series(1, 15000) AS s;

COMMIT;

-- Analyze all tables so PostgreSQL optimizer has fresh distribution statistics
VACUUM ANALYZE users;
VACUUM ANALYZE wallets;
VACUUM ANALYZE biometric_templates;
VACUUM ANALYZE merchants;
VACUUM ANALYZE transactions;
VACUUM ANALYZE auth_logs;
