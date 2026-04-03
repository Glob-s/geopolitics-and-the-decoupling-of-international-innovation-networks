# BRSI Shock Event-Study (International Innovation Networks): Analysis Pipeline

This folder contains a Stata pipeline that estimates stacked event-study DiD models for BRSI shocks in international innovation networks.

The DiD models implemented here are:

- Poisson Pseudo-Maximum Likelihood (PPML) with multi-way fixed effects, using the `ppmlhdfe` package (Correia, Guimarães, Zylkin (2019a)).
- Linear Model with Multiple Levels of Fixed Effects, using the `reghdfe` package (Correia (2015)).

It covers two outcomes:

- Co-invention links and intensity (country-pair collaboration panel).
- Citation flows (directed source-target country panel).

## Files in this folder

- `brsi_eventstudy_baseline.do`: main analysis script (data prep, stacked event-window construction, estimation, export).
- `utils.do`: helper programs used by the main script for report generation and treated/control counts.
- `figs/`: output figures (event-study plots, `.png`).
- `tables/`: output tables/reports (`.docx`).
- `logs/`: runtime logs (created by the script if missing).

## Required input data

Expected under `analysis/data/`:

- `collab_brsi_annual.dta`
- `citations_brsi_annual.dta`

Minimum expected fields:

| Dataset | Key variables |
| --- | --- |
| `collab_brsi_annual.dta` | `country_i`, `country_j`, `year`, `collaboration_int`, `edge`, `shock_i_to_j_year`, `shock_j_to_i_year` |
| `citations_brsi_annual.dta` | `source_j`, `target_i`, `year`, `cite_frac` (plus optional `cite_share`, `n_citations`), `shock_j_to_i_year` |

## How to run

From this directory, run in Stata:

- `do brsi_eventstudy_baseline.do`

The script automatically loads `utils.do`.

## End-to-end pipeline

### Step 1: setup and configuration (`brsi_eventstudy_baseline.do`)

- Sets paths (`data/`, `figs/`, `tables/`, `logs/`) and creates output folders if needed.
- Starts log file: `logs/brsi_eventstudy_baseline.log`.
- Defines event-study window:
  - Pre: $-3, -2, -1$
  - Post: $0,1,2,3,4,5$
- Defines relative-time regressors with baseline period $-1$ omitted.
- Installs required Stata packages if missing:
  - `ppmlhdfe`
  - `reghdfe`
- Loads helper functions from `utils.do`.

### Step 2: co-invention event study (`brsi_eventstudy_baseline.do`)

- Loads `data/collab_brsi_annual.dta` and restricts to years 2000–2023.
- Builds unordered dyad IDs (`country_i` × `country_j`).
- Creates dyad-level shock indicator:
  - `shock_ij_year = 1` if either directional shock is present.
- Counts treated vs control dyads using `_treated_control_counts`.
- Builds event list and drops overlapping event windows within dyad.
- Constructs stacked event panel with relative-year dummies for estimable event times.
- Estimates:
  - PPML: `collaboration_int` on event-time dummies with dyad and year FE.
  - LPM (via `reghdfe`): `edge` on event-time dummies with dyad and year FE.
- Exports `.docx` tables and `.png` event-study plots.

### Step 3: citation-flow event study (`brsi_eventstudy_baseline.do`)

- Loads `data/citations_brsi_annual.dta` and restricts to years 2000–2023.
- Builds directed dyad IDs (`source_j` → `target_i`).
- Builds additional FE group IDs:
  - `source_year`
  - `target_year`
- Counts treated vs control dyads using `_treated_control_counts`.
- Builds non-overlapping shock-event list and stacked event panel.
- Estimates PPML for `cite_frac` with absorbed FE:
  - dyad FE
  - source-year FE
  - target-year FE
- Exports `.docx` report and `.png` event-study plot.

### Step 4: helper program logic (`utils.do`)

`utils.do` defines three reusable programs:

- `_add_pooled_effects`
  - Computes pooled averages of selected event-time coefficients (via `lincom`).
  - Writes coefficient, SE, test stats, and confidence interval into report tables.

- `_export_table_with_plot`
  - Takes stored estimates and dependent variable metadata.
  - Creates coefficient plot (`coefplot`) for event-time effects.
  - Writes event-time coefficient table, pooled effects, Wald tests, fit/sample stats, and output paths to `.docx`.

- `_treated_control_counts`
  - Computes number of ever-treated vs never-treated units for a given `id()` and shock variable.
  - Returns `N_treated` and `N_control` as scalars.

## Estimation design summary

- Design: stacked event-study around BRSI shock years.
- Event window: $[-3, +5]$ with baseline $-1$ omitted.
- Handling repeated shocks: within-dyad windows are forced non-overlapping.
- Clustering: standard errors clustered at dyad level.
- Models used:
  - `ppmlhdfe` for count/fraction-like outcomes.
  - `reghdfe` for linear probability extensive-margin outcome.

## Main outputs

- Log:
  - `logs/brsi_eventstudy_baseline.log`
- Co-invention outputs:
  - `tables/eventstudy_collab_ppml.docx`
  - `tables/eventstudy_collab_edge.docx`
  - matching figures in `figs/`.
- Citation outputs:
  - `tables/eventstudy_cites_ppml.docx`
  - matching figure in `figs/`.

## Assumptions and safeguards

- Analysis sample is restricted to 2000–2023.
- Overlapping event windows within the same dyad are removed.
- Event-time baseline is fixed at relative year $-1$.
- If packages are missing, the script attempts automatic installation via SSC.
