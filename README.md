# Data Analytics Portfolio

Finance-focused analytics work spanning statistical inference, machine learning, quantitative risk modeling, advanced SQL, and spreadsheet financial modeling. Every project states the business question first, shows its work (including where a first approach failed or needed correcting), and ends with a decision-ready recommendation — not just a chart.

**[→ Open the Executive Dashboard](dashboard/executive_dashboard.html)** for a one-page summary of every result below.

---

## Why this portfolio is built differently

Most analyst portfolios show a query and a chart. This one is built the way an actual risk/finance team would review the work:

- **Hypotheses are tested, not assumed.** Every claimed relationship is backed by a statistical test (t-test, chi-square) with a reported p-value — including the ones that came back *not* significant, which are reported as findings, not hidden.
- **Mistakes are shown and fixed in the open.** The portfolio-risk notebook's first optimization run put 100% of the portfolio into Bitcoin — a textbook Markowitz instability. Rather than quietly picking better inputs, the notebook keeps that result, explains why it happened, and fixes it properly with a position-cap constraint. That diagnostic instinct is the actual job.
- **Every number ties to a business decision.** The credit risk model doesn't stop at "ROC-AUC = 0.79" — it converts that into a threshold recommendation with an estimated dollar profit impact ($4.3M swing on the test sample).
- **Notebooks are fully executed, not illustrative.** Every chart in every `.ipynb` is a real output from the code in the cell above it — open them and nothing needs to be re-run to see the results.
- **Spreadsheets use live formulas.** The Excel workbook uses `SUMIFS`/`INDEX`-`MATCH` throughout — zero hardcoded results — and was verified to recalculate with zero formula errors.

---

## Repository structure

```
├── flagship-credit-risk/
│   ├── Credit_Risk_Default_Analytics.ipynb   ← full pipeline, executed
│   └── outputs/                              ← exported chart PNGs
├── portfolio-risk-forecasting/
│   ├── Portfolio_Risk_Forecasting.ipynb      ← full pipeline, executed
│   └── outputs/
├── sql/
│   └── Advanced_Financial_Analytics.sql      ← schema + 6 annotated query patterns
├── excel/
│   └── Financial_KPI_Dashboard.xlsx          ← 4-tab live-formula workbook
├── dashboard/
│   └── executive_dashboard.html              ← interactive summary (open in any browser)
└── README.md
```

---

## Flagship Project — Credit Risk & Loan Default Analytics
`flagship-credit-risk/Credit_Risk_Default_Analytics.ipynb`

**Business question:** Can a model-based underwriting policy beat the bank's current "decline if credit score ≤ 620" rule, and by how much?

**Pipeline:** synthetic 10,000-loan portfolio (calibrated to realistic FICO/DTI/utilization distributions) → EDA → Welch's t-tests + chi-square hypothesis testing on every candidate feature → feature engineering → Logistic Regression / Random Forest / Gradient Boosting comparison → ROC-AUC & PR-AUC evaluation → feature importance → profit-curve threshold optimization.

**Headline results:**
| Metric | Result |
|---|---|
| Best model | Gradient Boosting (highest ROC-AUC & PR-AUC of the three) |
| Statistically significant predictors | DTI ratio, revolving utilization, loan-to-income, delinquency history, employment tenure, interest rate (all p < 0.001) |
| Statistically **not** significant | Home ownership (p = 0.92), loan purpose (p = 0.43) — correctly excluded from the scorecard |
| Optimal approval threshold | 0.11 predicted default probability (vs. legacy score cutoff) |
| Estimated profit impact | **-$4.19M → +$0.14M** net profit on the held-out test sample (+$4.33M swing) |

**Why it's more than a classifier:** the notebook explicitly separates statistical significance from business value — a feature can move the model's accuracy without being something underwriting should act on, and vice versa. The final recommendation is a threshold and a dollar estimate, the artifact a credit committee can actually vote on.

---

## Supporting Project 1 — Multi-Asset Portfolio Risk & Volatility Forecasting
`portfolio-risk-forecasting/Portfolio_Risk_Forecasting.ipynb`

**Business question:** What is a 5-asset portfolio's (US equities, EM equities, bonds, gold, Bitcoin) true risk exposure, and is the current allocation close to efficient?

**Pipeline:** correlated 3-year daily-return simulation (Cholesky decomposition against a realistic correlation matrix) → risk/return profiling → efficient frontier via 8,000-portfolio Monte Carlo simulation + exact `scipy.optimize` solves for Max Sharpe / Min Volatility → historical, parametric, and Monte Carlo VaR/CVaR → EWMA (RiskMetrics λ=0.94) volatility forecasting → drawdown analysis → correlation-shock stress test.

**Headline results:**
| Metric | Result |
|---|---|
| Unconstrained Max Sharpe allocation | 100% Bitcoin — flagged and diagnosed as Markowitz estimation-error instability, not a real recommendation |
| Corrected allocation (35% position cap) | Sharpe 0.15 vs. 0.21 (uncapped) / -0.11 (equal-weight) — deployable and still better than naive 1/N |
| 95% / 99% 1-day VaR (capped portfolio, $10M notional) | $254K / $358K |
| Correlation-shock stress test | 1-day VaR rises **~14%** when correlations move toward a crisis regime |
| Max drawdown (capped portfolio) | -36.5% over the simulated 3-year path |

**Why it's more than a backtest:** the notebook treats a failed naive optimization as the finding it is — most portfolio pieces quietly cherry-pick a result that looks good; this one shows the instability, explains the mechanism (estimation error amplification under mean-variance optimization), and applies the standard practitioner fix.

---

## Supporting Project 2 — Advanced SQL for Financial Analytics
`sql/Advanced_Financial_Analytics.sql`

Six annotated query patterns against a documented 3-table banking schema (customers / accounts / transactions), each opening with the business question it answers:

1. **Running-balance overdraft detection** — window-function `SUM() OVER()` catches intramonth overdraft dips a period-end balance would hide.
2. **Monthly cohort retention** — the classic growth "triangle" report, computed correctly on months-since-signup rather than calendar month.
3. **RFM customer segmentation** — `NTILE()`-based Recency/Frequency/Monetary scoring into actionable marketing tiers, no black-box model required.
4. **Fraud/anomaly detection** — per-account rolling z-scores (an account's own baseline, not the whole customer base) plus a `LATERAL`-join transaction-velocity check.
5. **Month-over-month net revenue** — `LAG()` and windowed moving averages for board-deck-ready trend reporting.
6. **Customer lifetime value & channel ROI** — 12-month CLV proxy by acquisition channel using `FILTER` and `PERCENTILE_CONT` (median, not just mean, to avoid whale distortion).

Every query is annotated with which SQL dialect features it needs and how to port it (Postgres → Snowflake/BigQuery/SQL Server notes included inline).

---

## Supporting Project 3 — Financial KPI Dashboard (Excel)
`excel/Financial_KPI_Dashboard.xlsx`

A 4-tab workbook (`Transactions`, `Assumptions`, `Summary`, `Dashboard`) built the way a finance team would actually maintain one:

- **420 simulated transactions** across 8 expense categories + 2 revenue lines, Jan–Sep 2025.
- **Assumptions tab** holds editable budget inputs (blue-font convention for hardcoded inputs, per financial-modeling standard) — change a number there and every downstream figure recalculates.
- **Summary tab** computes KPIs and category-level Actual vs. Budget vs. Variance entirely with `SUMIFS` and `INDEX`/`MATCH` — zero hardcoded results, 474 live formulas, verified to recalculate with **zero formula errors**.
- **Dashboard tab** has two native Excel charts (Actual vs. Budget by category; Monthly Revenue vs. Expenses trend) linked directly to the Summary tab.

**Result:** Revenue $1.48M vs. expenses $656K → net income $825K over the sample period, with every expense category tracking within its 9-month budget (largest favorable variances: Office Supplies +17.1%, Utilities +16.3%).

---

## Interactive Executive Dashboard
`dashboard/executive_dashboard.html`

A single self-contained HTML file (open directly in any browser, no server needed) that pulls the headline result from every project above into one tabbed view — Credit Risk / Portfolio Risk / Finance Operations — for a reader who wants the five-minute version before diving into any notebook.

---

## On the use of synthetic data

None of the datasets here are real institutional data — using an actual bank's loan tape or a real brokerage's positions in a public portfolio would raise privacy, licensing, and confidentiality issues no legitimate employer would want to see waved away. Every dataset is **synthetically generated but explicitly calibrated** to published, realistic industry benchmarks (FICO score distributions, typical unsecured-loan DTI/utilization ranges, asset-class historical return/volatility figures), and every generation function is fully visible in the first code cell of its notebook. Swapping in a real data source is a one-cell change — the rest of each pipeline (statistical testing, modeling, risk calculation, optimization) is written to be data-agnostic.

## Tech stack

`Python` (pandas, NumPy, scikit-learn, SciPy, matplotlib, seaborn) · `SQL` (PostgreSQL dialect, window functions, CTEs, LATERAL joins) · `Excel` (openpyxl-built, formula-driven, native charts) · `HTML/CSS/JS` (Chart.js) for the executive dashboard.

## Reproducing the notebooks

```bash
pip install pandas numpy scikit-learn scipy matplotlib seaborn openpyxl jupyter
jupyter notebook flagship-credit-risk/Credit_Risk_Default_Analytics.ipynb
jupyter notebook portfolio-risk-forecasting/Portfolio_Risk_Forecasting.ipynb
```

Both notebooks set an explicit random seed, so re-running end-to-end reproduces every figure and table in this README exactly.
