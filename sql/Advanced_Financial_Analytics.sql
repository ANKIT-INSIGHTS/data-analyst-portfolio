/* ============================================================================
   ADVANCED FINANCIAL ANALYTICS — SQL PORTFOLIO PROJECT
   Author: Ankit
   Dialect: PostgreSQL 14+ (uses window functions, FILTER clause, LATERAL joins,
            generate_series, and percentile_cont — flag dialect-specific lines
            if porting to MySQL/SQL Server/Snowflake)

   SCENARIO
   --------
   You are the analyst supporting a digital bank's finance & risk team. You have
   three core tables: customers, accounts, and transactions. Business
   stakeholders keep asking questions that a simple SELECT can't answer well —
   this script demonstrates the advanced SQL patterns (window functions, cohort
   retention, RFM segmentation, anomaly/fraud flagging, and running-balance
   reconciliation) that a junior query can't, with the business question stated
   above every block.
   ============================================================================ */


-- ============================================================================
-- 0. SCHEMA (minimal, documented, reproducible)
-- ============================================================================

DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS accounts;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id     INT PRIMARY KEY,
    signup_date     DATE NOT NULL,
    acquisition_channel VARCHAR(30),           -- 'organic','paid_search','referral','partner'
    country         VARCHAR(2)
);

CREATE TABLE accounts (
    account_id      INT PRIMARY KEY,
    customer_id     INT REFERENCES customers(customer_id),
    account_type    VARCHAR(20),               -- 'checking','savings','credit'
    opened_date     DATE NOT NULL,
    status          VARCHAR(10) DEFAULT 'active' -- 'active','closed','frozen'
);

CREATE TABLE transactions (
    transaction_id  BIGINT PRIMARY KEY,
    account_id      INT REFERENCES accounts(account_id),
    txn_timestamp   TIMESTAMP NOT NULL,
    amount          NUMERIC(12,2) NOT NULL,     -- positive = credit, negative = debit
    merchant_category VARCHAR(30),
    channel         VARCHAR(15)                 -- 'card','ach','wire','p2p','atm'
);

-- Helpful indexes for the window-function queries below
CREATE INDEX idx_txn_account_time ON transactions(account_id, txn_timestamp);
CREATE INDEX idx_accounts_customer ON accounts(customer_id);


/* ============================================================================
   1. RUNNING BALANCE & INTRA-MONTH LIQUIDITY DIPS
   Business question: "Which accounts dipped below $0 (overdraft risk) at any
   point intramonth, even if their end-of-month balance looked healthy?"
   Technique: window function running SUM, not just a period-end aggregate —
   an end-of-month-only view systematically hides overdraft events.
   ============================================================================ */

WITH running_balance AS (
    SELECT
        account_id,
        txn_timestamp,
        amount,
        SUM(amount) OVER (
            PARTITION BY account_id
            ORDER BY txn_timestamp
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS running_balance
    FROM transactions
)
SELECT
    account_id,
    MIN(running_balance)                        AS lowest_intramonth_balance,
    COUNT(*) FILTER (WHERE running_balance < 0)  AS negative_balance_events
FROM running_balance
GROUP BY account_id
HAVING MIN(running_balance) < 0
ORDER BY lowest_intramonth_balance ASC;


/* ============================================================================
   2. MONTHLY COHORT RETENTION (classic triangle report)
   Business question: "Of customers who signed up in month X, what % were
   still transacting N months later?" — the single most-requested growth
   metric and the one most often computed wrong (using calendar month instead
   of months-since-cohort-start).
   ============================================================================ */

WITH cohorts AS (
    SELECT
        c.customer_id,
        DATE_TRUNC('month', c.signup_date) AS cohort_month
    FROM customers c
),
activity AS (
    SELECT DISTINCT
        a.customer_id,
        DATE_TRUNC('month', t.txn_timestamp) AS activity_month
    FROM transactions t
    JOIN accounts a   ON a.account_id  = t.account_id
),
cohort_activity AS (
    SELECT
        co.cohort_month,
        co.customer_id,
        (DATE_PART('year', ac.activity_month)  - DATE_PART('year', co.cohort_month)) * 12
      + (DATE_PART('month', ac.activity_month) - DATE_PART('month', co.cohort_month)) AS months_since_signup
    FROM cohorts co
    JOIN activity ac ON ac.customer_id = co.customer_id
    WHERE ac.activity_month >= co.cohort_month
),
cohort_size AS (
    SELECT cohort_month, COUNT(DISTINCT customer_id) AS cohort_customers
    FROM cohorts
    GROUP BY cohort_month
)
SELECT
    ca.cohort_month,
    ca.months_since_signup,
    COUNT(DISTINCT ca.customer_id)                                   AS active_customers,
    cs.cohort_customers,
    ROUND(100.0 * COUNT(DISTINCT ca.customer_id) / cs.cohort_customers, 1) AS retention_pct
FROM cohort_activity ca
JOIN cohort_size cs ON cs.cohort_month = ca.cohort_month
GROUP BY ca.cohort_month, ca.months_since_signup, cs.cohort_customers
ORDER BY ca.cohort_month, ca.months_since_signup;


/* ============================================================================
   3. RFM CUSTOMER SEGMENTATION (Recency, Frequency, Monetary)
   Business question: "Segment customers into value tiers for the retention/
   marketing team without a black-box model — something a growth marketer can
   actually act on this week."
   Technique: NTILE() window function for independent quintile scoring, then
   a simple rule-based tier from the combined RFM score.
   ============================================================================ */

WITH customer_txns AS (
    SELECT
        a.customer_id,
        MAX(t.txn_timestamp)                       AS last_txn_date,
        COUNT(*)                                    AS frequency,
        SUM(CASE WHEN t.amount > 0 THEN t.amount ELSE 0 END) AS monetary_inflow
    FROM transactions t
    JOIN accounts a ON a.account_id = t.account_id
    GROUP BY a.customer_id
),
rfm_scored AS (
    SELECT
        customer_id,
        last_txn_date,
        frequency,
        monetary_inflow,
        -- NOTE: NTILE(5) ordering direction matters — recency wants MOST
        -- recent = best score, so we order ascending on "days since" (i.e.
        -- descending on last_txn_date) to give recent customers score 5.
        NTILE(5) OVER (ORDER BY last_txn_date ASC)      AS recency_score,
        NTILE(5) OVER (ORDER BY frequency ASC)           AS frequency_score,
        NTILE(5) OVER (ORDER BY monetary_inflow ASC)     AS monetary_score
    FROM customer_txns
)
SELECT
    customer_id,
    recency_score, frequency_score, monetary_score,
    (recency_score + frequency_score + monetary_score)                AS rfm_total,
    CASE
        WHEN (recency_score + frequency_score + monetary_score) >= 13 THEN 'Champion'
        WHEN (recency_score + frequency_score + monetary_score) >= 10 THEN 'Loyal'
        WHEN (recency_score + frequency_score + monetary_score) >= 7  THEN 'At Risk'
        ELSE 'Dormant / Win-back'
    END AS segment
FROM rfm_scored
ORDER BY rfm_total DESC;


/* ============================================================================
   4. ANOMALY / FRAUD-PATTERN DETECTION
   Business question: "Flag transactions that look statistically unusual for
   THAT specific account (not vs. the whole customer base) — a $2,000 charge
   is normal for one account and alarming for another."
   Technique: per-account rolling z-score using window AVG/STDDEV, plus a
   velocity check (too many transactions in too short a window) using a
   LATERAL self-join on a time range.
   ============================================================================ */

-- 4a. Per-account z-score outliers
WITH account_stats AS (
    SELECT
        account_id,
        AVG(ABS(amount))    OVER (PARTITION BY account_id) AS avg_abs_amount,
        STDDEV(ABS(amount)) OVER (PARTITION BY account_id) AS stddev_abs_amount,
        transaction_id,
        txn_timestamp,
        amount
    FROM transactions
)
SELECT
    transaction_id,
    account_id,
    txn_timestamp,
    amount,
    ROUND((ABS(amount) - avg_abs_amount) / NULLIF(stddev_abs_amount, 0), 2) AS z_score
FROM account_stats
WHERE stddev_abs_amount > 0
  AND ABS(amount) > avg_abs_amount + 3 * stddev_abs_amount     -- > 3 std devs from account's own norm
ORDER BY z_score DESC;

-- 4b. Velocity check: 4+ transactions on the same account within any 10-minute window
SELECT
    t1.account_id,
    t1.transaction_id AS first_txn_id,
    t1.txn_timestamp   AS window_start,
    COUNT(t2.transaction_id) AS txns_in_window
FROM transactions t1
JOIN LATERAL (
    SELECT t2.transaction_id
    FROM transactions t2
    WHERE t2.account_id = t1.account_id
      AND t2.txn_timestamp BETWEEN t1.txn_timestamp AND t1.txn_timestamp + INTERVAL '10 minutes'
) t2 ON TRUE
GROUP BY t1.account_id, t1.transaction_id, t1.txn_timestamp
HAVING COUNT(t2.transaction_id) >= 4
ORDER BY txns_in_window DESC;


/* ============================================================================
   5. MONTH-OVER-MONTH NET REVENUE & VOLATILITY (finance reporting)
   Business question: "Give finance a monthly net-flow trend with MoM % change
   and a 3-month moving average to smooth noise for the board deck."
   Technique: LAG() for period-over-period comparison, windowed AVG for
   moving average, all in a single pass.
   ============================================================================ */

WITH monthly_net AS (
    SELECT
        DATE_TRUNC('month', txn_timestamp) AS month,
        SUM(amount)                         AS net_flow
    FROM transactions
    GROUP BY DATE_TRUNC('month', txn_timestamp)
)
SELECT
    month,
    net_flow,
    LAG(net_flow) OVER (ORDER BY month)                                   AS prior_month_net_flow,
    ROUND(100.0 * (net_flow - LAG(net_flow) OVER (ORDER BY month))
          / NULLIF(ABS(LAG(net_flow) OVER (ORDER BY month)), 0), 1)       AS mom_pct_change,
    ROUND(AVG(net_flow) OVER (
        ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2)                                                                  AS moving_avg_3mo
FROM monthly_net
ORDER BY month;


/* ============================================================================
   6. CUSTOMER LIFETIME VALUE (CLV) PROXY & CHANNEL ROI
   Business question: "Which acquisition channel brings in customers worth
   the most over their first 12 months, so marketing spend can be reallocated?"
   Technique: correlated subquery + FILTER, then percentile_cont to give
   finance the median (not just the mean, which whales distort) CLV by channel.
   ============================================================================ */

WITH first_year_value AS (
    SELECT
        c.customer_id,
        c.acquisition_channel,
        SUM(t.amount) FILTER (
            WHERE t.txn_timestamp <= c.signup_date + INTERVAL '365 days'
              AND t.amount > 0
        ) AS twelve_month_inflow
    FROM customers c
    JOIN accounts a ON a.customer_id = c.customer_id
    JOIN transactions t ON t.account_id = a.account_id
    GROUP BY c.customer_id, c.acquisition_channel
)
SELECT
    acquisition_channel,
    COUNT(*)                                                        AS customers,
    ROUND(AVG(twelve_month_inflow), 2)                              AS mean_12mo_clv,
    ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY twelve_month_inflow), 2) AS median_12mo_clv
FROM first_year_value
GROUP BY acquisition_channel
ORDER BY median_12mo_clv DESC;


/* ============================================================================
   NOTES FOR REVIEWERS
   - Every query above states the business question it answers before the SQL,
     matching how a stakeholder-facing analyst should document work — not just
     "here's a query," but "here's why it exists."
   - `FILTER (WHERE ...)` and `PERCENTILE_CONT` are Postgres/ANSI SQL:2003
     features; on Snowflake/BigQuery use conditional SUM(CASE WHEN...) and
     PERCENTILE_CONT(...) OVER() respectively. On SQL Server, replace FILTER
     with SUM(CASE WHEN ...) and STRING_AGG-style windowing as needed.
   - LATERAL joins (#4b) are supported in Postgres, and via CROSS APPLY in
     SQL Server; BigQuery/Snowflake need a self-join with a BETWEEN predicate
     instead of LATERAL syntax.
   ============================================================================ */
