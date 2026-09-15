# Data Analytics Portfolio

Finance-focused analytics work spanning statistical inference, machine learning, quantitative risk modeling, advanced SQL, and spreadsheet financial modeling. Each project starts with a business question, shows where an approach needed correcting, and ends with a decision-ready recommendation rather than just a chart.

**[→ Open the Executive Dashboard](https://ankit-insights.github.io/data-analyst-portfolio/dashboard/executive_dashboard.html)** for a one-page summary of every result below.

---

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

## Flagship Project: Credit Risk & Loan Default Analytics
`flagship-credit-risk/Credit_Risk_Default_Analytics.ipynb`

The central question is whether a model-based underwriting policy can improve on the bank's current "decline if credit score ≤ 620" rule, and what that improvement would be worth.

The analysis uses a synthetic 10,000-loan portfolio calibrated to realistic FICO, DTI, and utilization distributions. It moves from EDA and Welch's t-tests plus chi-square tests through feature engineering, a Logistic Regression / Random Forest / Gradient Boosting comparison, ROC-AUC and PR-AUC evaluation, feature importance, and profit-curve threshold optimization. The tests report both significant and null results, so the scorecard is not relying on modeling convenience alone.

The main results are:
| Metric | Result |
|---|---|
| Best model | Gradient Boosting (highest ROC-AUC & PR-AUC of the three) |
| Statistically significant predictors | DTI ratio, revolving utilization, loan-to-income, delinquency history, employment tenure, interest rate (all p < 0.001) |
| Statistically **not** significant | Home ownership (p = 0.92), loan purpose (p = 0.43), correctly excluded from the scorecard |
| Optimal approval threshold | 0.11 predicted default probability (vs. legacy score cutoff) |
| Estimated profit impact | **-$4.19M → +$0.14M** net profit on the held-out test sample (+$4.33M swing) |

The recommendation is operational: use the calibrated probability threshold, review it for drift, and give the credit committee a dollar estimate it can evaluate. A feature may improve predictive accuracy without being appropriate for underwriting, which is why statistical significance and business value are considered separately.

---

## Supporting Project 1: Multi-Asset Portfolio Risk & Volatility Forecasting
`portfolio-risk-forecasting/Portfolio_Risk_Forecasting.ipynb`

This report asks what risk a five-asset portfolio (US equities, EM equities, bonds, gold, and Bitcoin) is actually carrying and whether its allocation is close to efficient.

The notebook builds correlated three-year daily returns with a Cholesky decomposition and a realistic correlation matrix. It then profiles risk and return, estimates the efficient frontier with 8,000 Monte Carlo portfolios and exact `scipy.optimize` solutions for Max Sharpe and Min Volatility, compares historical, parametric, and Monte Carlo VaR/CVaR, forecasts volatility with EWMA (RiskMetrics λ=0.94), and finishes with drawdown and correlation-shock analysis.

One result is deliberately diagnostic. The unconstrained Max Sharpe solve put 100% of the portfolio in Bitcoin, a textbook Markowitz estimation-error instability rather than a recommendation. Applying a 35% position cap produced an allocation that can actually be deployed.

Key figures:
| Metric | Result |
|---|---|
| Unconstrained Max Sharpe allocation | 100% Bitcoin, flagged and diagnosed as Markowitz estimation-error instability, not a real recommendation |
| Corrected allocation (35% position cap) | Sharpe 0.15 vs. 0.21 (uncapped) / -0.11 (equal-weight), deployable and still better than naive 1/N |
| 95% / 99% 1-day VaR (capped portfolio, $10M notional) | $254K / $358K |
| Correlation-shock stress test | 1-day VaR rises **~14%** when correlations move toward a crisis regime |
| Max drawdown (capped portfolio) | -36.5% over the simulated 3-year path |

The failed first optimization is part of the finding. The notebook shows how estimation error gets amplified by mean-variance optimization, then applies the standard practitioner fix instead of quietly cherry-picking a better-looking result.

---

## Supporting Project 2: Advanced SQL for Financial Analytics
`sql/Advanced_Financial_Analytics.sql`

Six annotated query patterns use a documented three-table banking schema (customers / accounts / transactions). Each begins with the business question it answers:

1. **Running-balance overdraft detection:** window-function `SUM() OVER()` catches intramonth overdraft dips a period-end balance would hide.
2. **Monthly cohort retention:** the classic growth "triangle" report, computed correctly on months-since-signup rather than calendar month.
3. **RFM customer segmentation:** `NTILE()`-based Recency/Frequency/Monetary scoring creates actionable marketing tiers without a black-box model.
4. **Fraud/anomaly detection:** per-account rolling z-scores use an account's own baseline, paired with a `LATERAL`-join transaction-velocity check.
5. **Month-over-month net revenue:** `LAG()` and windowed moving averages support board-deck-ready trend reporting.
6. **Customer lifetime value & channel ROI:** a 12-month CLV proxy by acquisition channel uses `FILTER` and `PERCENTILE_CONT` (median, not just mean, to avoid whale distortion).

Every query is annotated with which SQL dialect features it needs and how to port it (Postgres → Snowflake/BigQuery/SQL Server notes included inline).

---

## Supporting Project 3: Financial KPI Dashboard (Excel)
`excel/Financial_KPI_Dashboard.xlsx`

A 4-tab workbook (`Transactions`, `Assumptions`, `Summary`, `Dashboard`) built the way a finance team would actually maintain one:

- **420 simulated transactions** across 8 expense categories + 2 revenue lines, Jan–Sep 2025.
- **Assumptions tab** holds editable budget inputs (blue-font convention for hardcoded inputs, per financial-modeling standard). Change a number there and every downstream figure recalculates.
- **Summary tab** computes KPIs and category-level Actual vs. Budget vs. Variance entirely with `SUMIFS` and `INDEX`/`MATCH`. It has zero hardcoded results and 474 live formulas, verified to recalculate with **zero formula errors**.
- **Dashboard tab** has two native Excel charts (Actual vs. Budget by category; Monthly Revenue vs. Expenses trend) linked directly to the Summary tab.

**Result:** Revenue $1.48M vs. expenses $656K → net income $825K over the sample period, with every expense category tracking within its 9-month budget (largest favorable variances: Office Supplies +17.1%, Utilities +16.3%).

---

## Interactive Executive Dashboard
`dashboard/executive_dashboard.html`

A single self-contained HTML file can be opened directly in any browser. It brings the headline result from every project into one tabbed view covering Credit Risk, Portfolio Risk, and Finance Operations for readers who want the five-minute version before diving into a notebook.

---

## On the use of synthetic data

None of the datasets here are real institutional data. Using an actual bank's loan tape or a real brokerage's positions in a public portfolio would raise privacy, licensing, and confidentiality issues that no legitimate employer would want to ignore. Every dataset is **synthetically generated but explicitly calibrated** to published, realistic industry benchmarks (FICO score distributions, typical unsecured-loan DTI/utilization ranges, asset-class historical return/volatility figures), and every generation function is fully visible in the first code cell of its notebook. Swapping in a real data source is a one-cell change; the rest of each pipeline (statistical testing, modeling, risk calculation, optimization) is written to be data-agnostic.

## Tech stack

`Python` (pandas, NumPy, scikit-learn, SciPy, matplotlib, seaborn) · `SQL` (PostgreSQL dialect, window functions, CTEs, LATERAL joins) · `Excel` (openpyxl-built, formula-driven, native charts) · `HTML/CSS/JS` (Chart.js) for the executive dashboard.

## Reproducing the notebooks

```bash
pip install pandas numpy scikit-learn scipy matplotlib seaborn openpyxl jupyter
jupyter notebook flagship-credit-risk/Credit_Risk_Default_Analytics.ipynb
jupyter notebook portfolio-risk-forecasting/Portfolio_Risk_Forecasting.ipynb
```

Both notebooks set an explicit random seed, so re-running end-to-end reproduces every figure and table in this README exactly.
