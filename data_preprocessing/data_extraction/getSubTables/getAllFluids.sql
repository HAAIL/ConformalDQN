select * from getUrineOutput;

DROP table IF EXISTS `getAllFluids`;
CREATE table `getAllFluids` AS
with 
UrineOutputTable as ( SELECT subject_id, hadm_id, stay_id, charttime
         , urineoutput
         , CAST(null AS DOUBLE) as rate_norepinephrine 
         , CAST(null AS DOUBLE) as rate_epinephrine 
		, CAST(null AS DOUBLE) as rate_phenylephrine 
		, CAST(null AS DOUBLE) as rate_vasopressin 
		, CAST(null AS DOUBLE) as rate_dopamine 
		, CAST(null AS DOUBLE) as vaso_total
		, CAST(null AS DOUBLE) as iv_total
		, CAST(null AS DOUBLE) as cum_fluid_balance
FROM `getUrineOutput`),
VasopressorsTable as ( SELECT ic.subject_id, ic.hadm_id, ic.stay_id, starttime as charttime
         , CAST(null AS DOUBLE) as urineoutput
         , rate_norepinephrine 
         , rate_epinephrine 
		 , rate_phenylephrine 
		 , rate_vasopressin 
		, rate_dopamine 
		, vaso_total
	 , CAST(null AS DOUBLE) as iv_total
	 , CAST(null AS DOUBLE) as cum_fluid_balance
FROM `getVasopressors` vp INNER JOIN `icustays` ic
ON vp.stay_id=ic.stay_id
),
IntravenousTable  as ( SELECT subject_id, hadm_id, stay_id, charttime
         , CAST(null AS DOUBLE) as urineoutput
         , CAST(null AS DOUBLE) as rate_norepinephrine 
         , CAST(null AS DOUBLE) as rate_epinephrine 
		 , CAST(null AS DOUBLE) as rate_phenylephrine 
		 , CAST(null AS DOUBLE) as rate_vasopressin 
		 , CAST(null AS DOUBLE) as rate_dopamine 
		 , CAST(null AS DOUBLE) as vaso_total
		 , amount as iv_total
		 , CAST(null AS DOUBLE) as cum_fluid_balance
FROM `getIntravenous`),

CumFluidTable as ( SELECT subject_id, hadm_id, stay_id, charttime
         , CAST(null AS DOUBLE) as urineoutput
         , CAST(null AS DOUBLE) as rate_norepinephrine 
         , CAST(null AS DOUBLE) as rate_epinephrine 
		 , CAST(null AS DOUBLE) as rate_phenylephrine 
		 , CAST(null AS DOUBLE) as rate_vasopressin 
		 , CAST(null AS DOUBLE) as rate_dopamine 
		 , CAST(null AS DOUBLE) as vaso_total
		 , CAST(null AS DOUBLE) as iv_total
		 , cum_fluid_balance
FROM `getCumFluid`)


-- select * from CumFluidTable union ;


(SELECT subject_id, hadm_id, stay_id, charttime,
	 -- urine output
       avg(urineoutput) as urineoutput
	 -- vasopressors
	 , avg(rate_norepinephrine) as rate_norepinephrine 
     , avg(rate_epinephrine) as rate_epinephrine 
	 , avg(rate_phenylephrine) as rate_phenylephrine 
     , avg(rate_vasopressin) as rate_vasopressin 
	 , avg(rate_dopamine) as rate_dopamine 
     , avg(vaso_total) as vaso_total
	 -- intravenous fluids
	 , avg(iv_total) as iv_total
	 -- cumulated fluid balance
	 , avg(cum_fluid_balance) as cum_fluid_balance
FROM 
( select * from UrineOutputTable 
UNION ALL
  select * from  VasopressorsTable 
UNION ALL
 select * from  IntravenousTable 
UNION ALL
  select * from CumFluidTable 
) as allTables

group by subject_id, hadm_id, stay_id, charttime	
order by subject_id, hadm_id, stay_id, charttime);



select * from getAllFluids ;