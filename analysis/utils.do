/*******************************************************************************
  utils.do - Define helper functions for analysis.
  These include:
  - _export_table_with_plot: runs csdid for a specified DV, generates an event study plot, and exports results to a .docx report with tables of coefficients and Wald tests.
  - _add_pooled_effects: calculates and exports pooled effects (e.g., average pre-treatment, post-treatment effects) to the .docx report.
  - _treated_control_counts: calculates the number of treated and control units based on a specified shock variable, storing results in return scalars for use in report generation.
  All functions use global number formats defined at the top of the script for consistent formatting across outputs.
*******************************************************************************/

* -----------------------------------------------------------------------------
* PROGRAM: Calculate and export pooled effects for specified sets of event-time coefficients
* OPTIONS:
* vars(string) - list of event-time coefficient variables to include in the pooled effect (e.g., "rel_m3 rel_m2" for pre-treatment effects)
* title(string) - title to display above the pooled effect in the .docx report
* -----------------------------------------------------------------------------
cap program drop _add_pooled_effects
program define _add_pooled_effects
	version 18.0
	syntax , VARS(string) TITLE(string)
	local n: word count(`vars')
	local expr ""
	foreach v of local vars{
		if "`expr'" == "" {
			local expr "`v'"
		}
		else {
			local expr "`expr' + `v'"
		}
	}
	putdocx paragraph, style(Heading3)
	putdocx text ("`title'")
	quietly lincom (`expr')/`n'
	putdocx table eff = (2, 6)
	putdocx table eff(1,1) = ("Coefficient"), bold
	putdocx table eff(1,2) = ("Std. err."), bold
	putdocx table eff(1,3) = ("z"), bold
	putdocx table eff(1,4) = ("p-value"), bold
	putdocx table eff(1,5) = ("95% l"), bold
	putdocx table eff(1,6) = ("95% u"), bold
	putdocx table eff(2,1) = (strofreal(r(estimate), "$NUMFMT"))
	putdocx table eff(2,2) = (strofreal(r(se), "$NUMFMT"))
	putdocx table eff(2,3) = (strofreal(r(z), "$NUMFMT"))
	putdocx table eff(2,4) = (strofreal(r(p), "$NUMFMT"))
	putdocx table eff(2,5) = (strofreal(r(lb), "$NUMFMT"))
	putdocx table eff(2,6) = (strofreal(r(ub), "$NUMFMT"))
end

* -----------------------------------------------------------------------------
* PROGRAM: Run csdid, generate event study plot, and export results to .docx
* OPTIONS:
* dv(string) - specify dependent variable for csdid
* es(string) - specify name of stored csdid estimates to use for plotting and table export
* title(string) - specify title of the report
* outdoc(string) - specify full path to save the .docx file
* ntreat(real) - number of treated units (for reporting in the .docx)
* nctrl(real) - number of control units (for reporting in the .docx)
* -----------------------------------------------------------------------------

cap program drop _export_table_with_plot
program define _export_table_with_plot
    version 18.0
    syntax , DV(string) ES(string) TITLE(string) OUTDOC(string) NTREAT(real) NCTRL(real)
    
    matrix coefs = r(table)
    
    preserve
        * PNG path
        local outpng = subinstr("`outdoc'","tables/","figs/",.)
        local outpng = subinstr("`outpng'",".docx",".png",.)

        coefplot `es', ///
	    keep($relvars) ///
	    xline(3) vertical ///
	    xlabel(1 "-3" 2 "-2" 3 "0" 4 "1" 5 "2" 6 "3" 7 "4" 8 "5") ///
	    ytitle("Effect on `dv'") ///
	    xtitle("Years relative to BRSI shock")
	   
	graph export "`outpng'", replace

        * DOCX export
        putdocx clear
        putdocx begin, pagesize(letter) font("Arial",10)
        putdocx paragraph, style(Heading1)
        putdocx text ("`title'")
	
        putdocx paragraph, style(Heading2)
        putdocx text ("Event-time dynamics (-$L..$H)")
	matrix table_transposed = coefs'
        putdocx table t1 = matrix(table_transposed), rownames colnames nformat("$NUMFMT")
	
	* Pooled effects
        putdocx paragraph, style(Heading2)
	putdocx text ("Pooled effects")
	
	* Pre-trend
	_add_pooled_effects, vars("rel_m3 rel_m2") title("Pre-treatment effects (-3 -2)")
	
	* Post-avg
	_add_pooled_effects, vars("rel_0 rel_1 rel_2 rel_3 rel_4 rel_5") title("Post-treatment effects (0 5)")
	
	* Short-run 
	_add_pooled_effects, vars("rel_0 rel_1") title("Short-run effects (0 1)")
	
	* Medium-run
	_add_pooled_effects, vars("rel_2 rel_3") title("Medium-run effects (2 3)")
	
	* Long-run
	_add_pooled_effects, vars("rel_4 rel_5") title("Long-run effects (4 5)")
	
	* Chi-2 and degrees of freedom
	local chi2 = e(chi2)
	local df = e(df)
	putdocx paragraph, style(Heading2)
	putdocx text ("Chi2: `chi2'")
	putdocx paragraph, style(Heading2)
	putdocx text ("df: `df'")
	
	putdocx paragraph, style(Heading2)
	putdocx text ("Degrees of freedom table")
	matrix dof_table = e(dof_table)
	putdocx table df_table = matrix(dof_table), rownames colnames nformat("$NUMFMT")
	
	* Wald tests
	putdocx paragraph, style(Heading2)
	putdocx text ("Wald Tests. H0: coefs = 0")
	
	* Pre-trend
	putdocx paragraph, style(Heading2)
	putdocx text ("Pre-trend: -3 -2")
	quietly test rel_m3 rel_m2
	putdocx table preWald = (3, 2)
	putdocx table preWald(1,1) = ("chi2"), bold
	putdocx table preWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
	putdocx table preWald(2,1) = ("df"), bold
	putdocx table preWald(2,2) = (strofreal(r(df), "$NUMFMT"))
	putdocx table preWald(3,1) = ("p-value"), bold
	putdocx table preWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	
	* Short-run
	putdocx paragraph, style(Heading2)
	putdocx text ("Short-run: 0 1")
	quietly test rel_0 rel_1
	putdocx table srWald = (3, 2)
	putdocx table srWald(1,1) = ("chi2"), bold
	putdocx table srWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
	putdocx table srWald(2,1) = ("df"), bold
	putdocx table srWald(2,2) = (strofreal(r(df), "$NUMFMT"))
	putdocx table srWald(3,1) = ("p-value"), bold
	putdocx table srWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	
	* Medium-run
	putdocx paragraph, style(Heading2)
	putdocx text ("Medium-run: 2 3")
	quietly test rel_2 rel_3
	putdocx table mrWald = (3, 2)
	putdocx table mrWald(1,1) = ("chi2"), bold
	putdocx table mrWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
	putdocx table mrWald(2,1) = ("df"), bold
	putdocx table mrWald(2,2) = (strofreal(r(df), "$NUMFMT"))
	putdocx table mrWald(3,1) = ("p-value"), bold
	putdocx table mrWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	
	* Long-run
	putdocx paragraph, style(Heading2)
	putdocx text ("Long-run: 4 5")
	quietly test rel_4 rel_5
	putdocx table lrWald = (3, 2)
	putdocx table lrWald(1,1) = ("chi2"), bold
	putdocx table lrWald(1,2) = (strofreal(r(chi2), "$NUMFMT"))
	putdocx table lrWald(2,1) = ("df"), bold
	putdocx table lrWald(2,2) = (strofreal(r(df), "$NUMFMT"))
	putdocx table lrWald(3,1) = ("p-value"), bold
	putdocx table lrWald(3,2) = (strofreal(r(p), "$NUMFMT"))
	
	* Number of observations (total)
	local N = e(N)
	
	* Number of singletons
	local N_singletons = e(num_singletons)
	
	* Number of absorbed fixed effects
	local N_hdfe = e(N_hdfe)
	
	putdocx table obs = (5, 2)
	putdocx table obs(1,1) = ("N Obs"), bold
	putdocx table obs(1,2) = ("`N'")
	putdocx table obs(2,1) = ("N Singletons"), bold
	putdocx table obs(2,2) = ("`N_singletons'")
	putdocx table obs(3,1) = ("N Absorbed Fixed Effects"), bold
	putdocx table obs(3,2) = ("`N_hdfe'")
	putdocx table obs(4,1) = ("N Treated"), bold
	putdocx table obs(4,2) = (strofreal(`ntreat'))
	putdocx table obs(5,1) = ("N Control"), bold
	putdocx table obs(5,2) = (strofreal(`nctrl'))
	
	putdocx paragraph, style(Heading2)
        putdocx text ("Figure saved to: `outpng'")
        putdocx save "`outdoc'", replace
	
    restore
end

* -----------------------------------------------------------------------------
* PROGRAM: Calculate number of treated and control units based on shock variable
* OPTIONS:
* varlist - list of shock variables to check (e.g., shock_j_to_i_year)
* id(varname) - identifier variable for grouping (e.g., dyad_id)
* RETURNS:
* N_treated (scalar) - number of units that experience the shock (ever_shock == 1)
* N_control (scalar) - number of units that never experience the shock (ever_shock == 0)
* -----------------------------------------------------------------------------
capture program drop _treated_control_counts
program define _treated_control_counts, rclass
	syntax varlist, ID(varname)
	di "`varlist'"
	preserve
		keep `id' `varlist'
		bys `id': egen ever_shock = max(`varlist')
		bys `id': keep if _n == 1
		count if ever_shock == 1
		return scalar N_treated = r(N)
		count if ever_shock == 0
		return scalar N_control = r(N)
	restore
end
