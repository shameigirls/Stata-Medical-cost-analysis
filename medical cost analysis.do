**************************************************
** Project Name: Medical Cost Regression Analysis
** Author: Chen Wang
** Date: 02/10/2020
** Modified Date: 06/29/2020
** Data Source: US Census Bureau
**************************************************

/* Define Macro */
global path "/Users/chenwang/File/"

clear
set more off
capture log close

/* Set Directory */
cd "$path"
log using medical_record, smcl replace

import excel "insurance.xlsx", sheet(Sheet1) firstrow clear
levelsof SheetName, local(sheetlist)
display `sheetlist'
 
foreach l of local sheetlist {
display "`l'"
import excel "insurance.xlsx", sheet("`l'") firstrow clear                 

** Section 1. Outlier Check, Data Clearning, and ID Creation
	hist charge
	sum charge

	gen outlier_charge = (charge > r(mean)+2*r(sd) | charge < r(mean)-2*r(sd))
	sum charge if outlier_charge == 0 

	drop if age > 110
	drop if age < 0
	drop if bmi < 0
	drop if children != int(children)
	replace region = lower(region)
	tab region
	replace region = "northwest" if region == "norhwest"
	replace region = "northwest" if region == "nowest"
	replace region = "southwest" if region == "souhwest"
	replace region = "northeast" if region == "norseast"
	replace region = "southwest" if region == "southwests"

	sort age bmi children
	gen bmi_int = int(bmi)
	egen group = group(age bmi_int)
	bysort group: egen id_last_digit = seq()
	gen id = string(age) + string(bmi_int) + string(id_last_digit)
	isid id
	drop bmi_int group id_last_digit
	

** Section 2. Data Labeling
	capture drop smoker_n sex_n region_n
	encode smoker, gen(smoker_n)
	encode sex, gen(sex_n)
	encode region, gen(region_n)
	label list

	ren sex_n male
	recode male (1=0)(2=1)
	label define malelabel 0 "female" 1 "male"
	label values male malelabel
	
	recode smoker_n (1=0)(2=1)
	label define smokerabel 0 "no" 1 "yes"
	label values smoker_n smokerabel
	
	recode region_n (1=0)(2=1)(3=2)(4=3)
	label define regionlabel 0 "northeast" 1 "northwest" 2 "southeast" 3 "southwest"
	label values region_n regionlabel


	label var age "Age of the primary beneficiary"
	label var sex "raw sex"
	label var bmi "Body mass index"
	label var children "Number of children covered by health insurance"
	label var smoker "raw smoker"
	label var region "raw region"
	label var charges "Individual medical costs billed by health insurance"
	label var smoker_n "encoded smoker"
	label var region_n "encoded region"
	label var male "encoded sex"
	label var id "ID"
	label var outlier_charge "index to define if charge is outlier"


** Section 3. Descriptive Analysis

	************
	** By region
	************
	save "temp_descriptive_`l'", replace                                          
	preserve
	collapse (mean) age bmi charge, by(region) 
	gen statistics = "mean"
	tempfile forappend_region
	save `forappend_region', replace
	restore

	local list max min sd

	foreach x of local list {
	preserve
	collapse (`x') age bmi charge, by(region) 
	gen statistics = "`x'"
	append using `forappend_region'
	save `forappend_region', replace
	restore
	}

	use `forappend_region', clear
	export excel using chart.xlsx, sheet("region_`l'") sheetreplace firstrow(variables)   


	************
	** By male
	************
	use "temp_descriptive_`l'", clear    

	preserve
	collapse (mean) age bmi charge, by(male) 
	gen statistics = "mean"
	tempfile forappend_male
	save `forappend_male', replace
	restore

	local list max min sd

	foreach x of local list {
	preserve
	collapse (`x') age bmi charge, by(region) 
	gen statistics = "`x'"
	append using `forappend_male'
	save `forappend_male', replace
	restore
	}

	use `forappend_male', clear                                                
	export excel using chart.xlsx, sheet("male_`l'") sheetreplace firstrow(variables)    


	************
	** By smoker
	************
	use "temp_descriptive_`l'", clear    

	preserve
	collapse (mean) age bmi charge, by(smoker_n) 
	gen statistics = "mean"
	tempfile forappend_smoker
	save `forappend_smoker', replace
	restore

	local list max min sd

	foreach x of local list {
	preserve
	collapse (`x') age bmi charge, by(smoker_n) 
	gen statistics = "`x'"
	append using `forappend_smoker'
	save `forappend_smoker', replace
	restore
	}

	use `forappend_smoker', clear                                                
	export excel using chart.xlsx, sheet("smoker_`l'") sheetreplace firstrow(variables)  


	************
	** By male and region
	************
	use "temp_descriptive_`l'", clear 
	
	preserve
	collapse (mean) age bmi charge, by(male region) 
	gen statistics = "mean"
	tempfile forappend_male_region
	save `forappend_male_region', replace
	restore

	local list max min sd

	foreach x of local list {
	preserve
	collapse (`x') age bmi charge, by(male region) 
	gen statistics = "`x'"
	append using `forappend_male_region'
	save `forappend_male_region', replace
	restore
	}

	use `forappend_male_region', clear
	export excel using chart.xlsx, sheet("male_region_`l'") sheetreplace firstrow(variables) 

	use "temp_descriptive_`l'", clear 
	hist charge
	graph export "histcharge_`l'.png", replace                                                
	hist charge if outlier_charge != 1 
	graph export "histcharge2sd_`l'.png", replace                                              


** Section 4. Correlation Analysis
	use temp_descriptive_`l', clear                                            
	twoway (scatter bmi age) (lfit bmi age)
	graph export bmi_age_`l'.png, replace                                                
	twoway (scatter charge bmi) (lfit charge bmi)
	graph export bmi_charge_`l'.png, replace                                                 
	twoway (scatter charge age) (lfit charge age)
	graph export age_charge_`l'.png, replace                                             

	display in red "finished one loop"
	// correlation matrix
	corr age bmi children smoker charges

** Section 5. Regression Analysis
	gen lncharge =ln(charge)
	label var lncharge "ln charge"
	reg lncharge age bmi children smoker_n
	estimates store reg_1
	reg lncharge age bmi children
	estimates store reg_2
	reg lncharge age bmi smoker_n
	estimates store reg_3
	reg lncharge bmi  children smoker_n 
	estimates store reg_4
	reg lncharge bmi children smoker_n
	estimates store reg_5
	predict yhat

	esttab reg_* using "regression_`l'.csv", order(lncharge age bmi children smoker_n) star (* 0.10 ** 0.05 *** 0.01) p r2 label lines replace
}

exit

