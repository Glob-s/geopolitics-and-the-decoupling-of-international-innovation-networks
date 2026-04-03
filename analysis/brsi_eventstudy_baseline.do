/******************************************************
* brsi_eventstudy_baseline.do
* Stacked event-study DiD for BRSI shocks
* Outcomes: co-invention (unordered dyads), citations (directed dyads)
/******************************************************

version 18
clear all
set more off

*******************************************************
* 0. PATHS AND GLOBALS
*******************************************************

* 0.1 Define paths and global variables
global root "."
global data "$root/data"
global figs "$root/figs"
global logs "$root/logs"
global tables "$root/tables"

cap mkdir "$figs"
cap mkdir "$logs"
cap mkdir "$tables"

global NUMFMT "%9.3f"

cap log close
log using "$logs/brsi_eventstudy_baseline.log", replace text

* L = number of pre-shock years in event-study window (relative years -L, ..., -1)
* H = number of post-shock years in event-study window (relative years 0, 1, ..., H)
global L = 3      // pre: -3, -2, -1
global H = 5      // post: 0, 1, 2, 3, 4, 5

* Relative-year dummies to estimate (omit -1 as baseline)
global rel_list -3 -2 0 1 2 3 4 5
global relvars rel_m3 rel_m2 rel_0 rel_1 rel_2 rel_3 rel_4 rel_5

* 0.2 Install required packages

cap which ppmlhdfe
if _rc ssc install ppmlhdfe, replace

cap which reghdfe
if _rc ssc install reghdfe, replace

do "utils.do"

*******************************************************
* 1. CO-INVENTION: stacked event study on collab_brsi_annual
*******************************************************

*------------------------------------------------------
* 1.1 Load data and define dyads and shocks
*------------------------------------------------------

use "$data/collab_brsi_annual.dta", clear

* Expected variables:
*   country_i   country_j   year
*   collaboration_int   edge
*   shock_i_to_j_year   shock_j_to_i_year

keep if inrange(year, 2000, 2023)

* Unordered dyad ID
egen dyad_id = group(country_i country_j), label

* Single shock indicator for dyad in year t
gen shock_ij_year = (shock_i_to_j_year == 1 | shock_j_to_i_year == 1)

_treated_control_counts shock_ij_year, id(dyad_id)
scalar N_treated_collab = r(N_treated)
scalar N_control_collab = r(N_control)

*------------------------------------------------------
* 1.2 Create event list with non-overlapping windows
*------------------------------------------------------

preserve
    keep dyad_id year shock_ij_year
    keep if shock_ij_year == 1
    keep dyad_id year
    rename year event_year
    sort dyad_id event_year

    * Drop events whose windows would overlap within the same dyad
    by dyad_id: gen event_gap = event_year - event_year[_n-1]
    gen keep_event = 1
    replace keep_event = 0 if _n > 1 & event_gap < ($L + $H + 1)

    keep if keep_event == 1
    drop event_gap keep_event

    by dyad_id: gen event_id = _n

    tempfile collab_events
    save `collab_events', replace
restore

tempfile collab_base
save `collab_base', replace

*------------------------------------------------------
* 1.3 Build stacked event-study panel for co-invention
*------------------------------------------------------

use `collab_base', clear
joinby dyad_id using `collab_events'

* Relative year around event
gen rel_year = year - event_year

* Restrict to event-study window
keep if rel_year >= -$L & rel_year <= $H

* For any dyad-year that falls into more than one event window,
* keep the earliest event (smallest event_year)
sort dyad_id year event_year
by dyad_id year: keep if _n == 1

* Event-time dummies; omit rel_year = -1 as baseline

foreach r of global rel_list {
	local relname = cond(`r' < 0, "rel_m" + strofreal(-`r'), "rel_" + strofreal(`r'))
	gen `relname' = (rel_year == `r')
}
drop rel_year

tempfile collab_es
save `collab_es', replace

*------------------------------------------------------
* 1.4 PPML for co-invention intensity
*------------------------------------------------------

use `collab_es', clear

ppmlhdfe collaboration_int ///
    rel_* , ///
    absorb(dyad_id year) ///
    cluster(dyad_id)

estimates store ppml_collab

_export_table_with_plot, dv(collaboration_int) es(ppml_collab) title("PPML for co-invention intensity") outdoc("$tables/eventstudy_collab_ppml.docx") ntreat(`=N_treated_collab') nctrl(`=N_control_collab')

*------------------------------------------------------
* 1.5 LPM for co-invention edge (extensive margin)
*------------------------------------------------------

reghdfe edge ///
    rel_* , ///
    absorb(dyad_id year) ///
    vce(cluster dyad_id)

estimates store lpm_edge

_export_table_with_plot, dv(edge) es(lpm_edge) title("LPM for co-invention edge") outdoc("$tables/eventstudy_collab_edge.docx") ntreat(`=N_treated_collab') nctrl(`=N_control_collab')

*******************************************************
* 2. CITATIONS: stacked event study on citations_brsi_annual
*******************************************************

*------------------------------------------------------
* 2.1 Load data and define IDs and shocks
*------------------------------------------------------

use "$data/citations_brsi_annual.dta", clear

* Expected variables:
*   source_j   target_i   year
*   cite_frac  cite_share  n_citations
*   shock_j_to_i_year

keep if inrange(year, 2000, 2023)

* Directed dyad ID
egen dyad_id = group(source_j target_i), label

* Exporter-year and importer-year IDs
egen source_year = group(source_j year)
egen target_year = group(target_i year)

_treated_control_counts shock_j_to_i_year, id(dyad_id)
scalar N_treated_cites = r(N_treated)
scalar N_control_cites = r(N_control)

*------------------------------------------------------
* 2.2 Create event list with non-overlapping windows
*------------------------------------------------------

preserve
    keep dyad_id year shock_j_to_i_year
    keep if shock_j_to_i_year == 1
    keep dyad_id year
    rename year event_year
    sort dyad_id event_year

    by dyad_id: gen event_gap = event_year - event_year[_n-1]
    gen keep_event = 1
    replace keep_event = 0 if _n > 1 & event_gap < ($L + $H + 1)

    keep if keep_event == 1
    drop event_gap keep_event

    by dyad_id: gen event_id = _n

    tempfile cites_events
    save `cites_events', replace
restore

tempfile cites_base
save `cites_base', replace

*------------------------------------------------------
* 2.3 Build stacked event-study panel for citations
*------------------------------------------------------

use `cites_base', clear
joinby dyad_id using `cites_events'

gen rel_year = year - event_year

keep if rel_year >= -$L & rel_year <= $H

sort dyad_id year event_year
by dyad_id year: keep if _n == 1

foreach r of global rel_list {
	local relname = cond(`r' < 0, "rel_m" + strofreal(-`r'), "rel_" + strofreal(`r'))
	gen `relname' = (rel_year == `r')
}
drop rel_year

tempfile cites_es
save `cites_es', replace

*------------------------------------------------------
* 2.4 PPML for citation flows (fractional counts)
*------------------------------------------------------

use `cites_es', clear

ppmlhdfe cite_frac ///
    rel_* , ///
    absorb(dyad_id source_year target_year) ///
    cluster(dyad_id)

estimates store ppml_cites

_export_table_with_plot, dv(cite_frac) es(ppml_cites) title("PPML for citation flows (fractional counts)") outdoc("$tables/eventstudy_cites_ppml.docx") ntreat(`=N_treated_cites') nctrl(`=N_control_cites')

*******************************************************
* 3. Close log
*******************************************************

log close
exit
