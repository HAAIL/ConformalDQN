--  Initial code for the lab portion was retrieved from https://github.com/arnepeine/ventai/blob/main/overalltable_Lab_withventparams.sql
--  Initial code for the rest was retrieved from https://github.com/arnepeine/ventai/blob/main/overalltable_withoutLab_withventparams.sql
--  Modifications were made when needed for performance improvement, readability or simplification.
-- Code was modified to be campatible with MIMIC IV.

DROP table IF EXISTS `OverallTable`;
CREATE table `OverallTable` AS

SELECT merged.subject_id, hadm_id, stay_id, charttime 
     -- vital signs
	 , avg(gcs) as gcs
     , avg(HeartRate) as HeartRate 
     , avg(SysBP) as SysBP
     , avg(DiasBP) as DiasBP 
     , avg(MeanBP) as MeanBP 
     , avg(SysBP)/avg(HeartRate) as shockindex
     , avg(RespRate) as RespRate
     , avg(TempC) as TempC 
     , avg(SpO2) as SpO2 
	 --  lab values
	 , avg(POTASSIUM) as POTASSIUM 
     , avg(SODIUM) as SODIUM 
     , avg(CHLORIDE) as CHLORIDE 
     , avg(GLUCOSE) as GLUCOSE
	 , avg(BUN) as BUN 
     , avg(CREATININE) as CREATININE 
     , avg(MAGNESIUM) as MAGNESIUM 
     , avg(CALCIUM) as CALCIUM 
     , avg(ionizedcalcium) ionizedcalcium
	 , avg(CARBONDIOXIDE) as CARBONDIOXIDE 
     , avg(SGOT) as SGOT 
     , avg(SGPT) as SGPT 
     , avg(BILIRUBIN) as BILIRUBIN 
     , avg(ALBUMIN) as ALBUMIN 
	 , avg(HEMOGLOBIN) as HEMOGLOBIN 
     , avg(WBC) as WBC 
     , avg(PLATELET) as PLATELET 
     , avg(PTT) as PTT
     , avg(PT) as PT 
     , avg(INR) as INR 
     , avg(PH) as PH 
     , avg(PaO2) as PaO2 
     , avg(PaCO2) as PaCO2
     , avg(BASE_EXCESS) as BASE_EXCESS 
     , avg(BICARBONATE) as BICARBONATE 
     , avg(LACTATE) as LACTATE 
	 --  multiply by 100 because FiO2 is in a % but should be a fraction. This idea is retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/firstday/blood-gas-first-day-arterial.sql
	 , avg(PaO2)/avg(Fio2)*100 as PaO2FiO2ratio 
	 , avg(BANDS) as BANDS 
	 --  fluids
	 , avg(urineoutput) as urineoutput
     , avg(iv_total) as iv_total
     , avg(cum_fluid_balance) as cum_fluid_balance
	 , avg(rate_norepinephrine) as rate_norepinephrine 
     , avg(rate_epinephrine) as rate_epinephrine 
	 , avg(rate_phenylephrine) as rate_phenylephrine 
     , avg(rate_vasopressin) as rate_vasopressin 
	 , avg(rate_dopamine) as rate_dopamine 
     , avg(vaso_total) as vaso_total
	 --  ventilation parameters
	 , CAST((avg(mechvent)>0) AS DECIMAL) as MechVent
     , avg(FiO2) as FiO2
	 , max(PEEP) as PEEP
     , max(tidal_volume) as tidal_volume
     , max(plateau_pressure) as plateau_pressure

FROM
(
SELECT lab.subject_id, lab.hadm_id, lab.stay_id, lab.charttime
	--  vital signs
	 , CAST(null AS DOUBLE) as gcs
     , CAST(null AS DOUBLE) as heartrate
     , CAST(null AS DOUBLE) as sysbp
     , CAST(null AS DOUBLE) as diasbp
     , CAST(null AS DOUBLE) as meanbp
     ,  CAST(null AS DOUBLE) as resprate
     , CAST(null AS DOUBLE) as tempc
     , CAST(null AS DOUBLE) as spo2 
	--  lab values 
	 , POTASSIUM 
     , SODIUM 
     , CHLORIDE 
     , GLUCOSE 
     , BUN 
     , CREATININE 
     , MAGNESIUM 
     , CALCIUM 
     , CARBONDIOXIDE 
	 , BILIRUBIN 
     , ALBUMIN 
     , HEMOGLOBIN 
     , WBC 
     , PLATELET 
     , PTT 
     , PT 
     , INR 
     , PH 
     , PaO2 
     , PaCO2
     , BASE_EXCESS 
     , BICARBONATE 
     , LACTATE 
     , BANDS
     , SGOT 
     , SGPT 
     , IONIZEDCALCIUM
	--  fluids
	 , CAST(null AS DOUBLE) as urineoutput, CAST(null AS DOUBLE) as iv_total, CAST(null AS DOUBLE) as cum_fluid_balance
	 , CAST(null AS DOUBLE) as rate_norepinephrine , CAST(null AS DOUBLE) as rate_epinephrine 
	 , CAST(null AS DOUBLE) as rate_phenylephrine , CAST(null AS DOUBLE) as rate_vasopressin 
	 , CAST(null AS DOUBLE) as rate_dopamine , CAST(null AS DOUBLE) as vaso_total
	--  ventilation parameters
	 , CAST(null AS DECIMAL) as MechVent , CAST(null AS DOUBLE) as FiO2
	 , CAST(null AS DOUBLE) as PEEP, CAST(null AS DOUBLE) as tidal_volume, CAST(null AS DOUBLE) as plateau_pressure
FROM `getAllLabvalues` lab 
UNION ALL
SELECT subject_id, hadm_id, stay_id, charttime
	 --  vital signs
	 , gcs, heartrate, sysbp, diasbp, meanbp, resprate, tempc, spo2 
	 --  lab values
	 , CAST(null AS DOUBLE) as POTASSIUM 
     , CAST(null AS DOUBLE) as SODIUM 
     , CAST(null AS DOUBLE) as CHLORIDE 
     , CAST(null AS DOUBLE) as GLUCOSE 
     , CAST(null AS DOUBLE) as BUN 
     , CAST(null AS DOUBLE) as CREATININE 
     , CAST(null AS DOUBLE) as MAGNESIUM 
     , CAST(null AS DOUBLE) as IONIZEDCALCIUM 
     , CAST(null AS DOUBLE) as CALCIUM 
     , CAST(null AS DOUBLE) as CARBONDIOXIDE 
	 , CAST(null AS DOUBLE) as SGOT 
     , CAST(null AS DOUBLE) as SGPT 
     , CAST(null AS DOUBLE) as BILIRUBIN 
     , CAST(null AS DOUBLE) as ALBUMIN 
     , CAST(null AS DOUBLE) as HEMOGLOBIN 
     , CAST(null AS DOUBLE) as WBC 
     , CAST(null AS DOUBLE) as PLATELET 
     , CAST(null AS DOUBLE) as PTT 
     , CAST(null AS DOUBLE) as PT 
     , CAST(null AS DOUBLE) as INR 
     , CAST(null AS DOUBLE) as PH 
     , CAST(null AS DOUBLE) as PaO2 
     , CAST(null AS DOUBLE) as PaCO2
     , CAST(null AS DOUBLE) as BASE_EXCESS 
     , CAST(null AS DOUBLE) as BICARBONATE 
     , CAST(null AS DOUBLE) as LACTATE 
     , CAST(null AS DOUBLE) as BANDS
	--  fluids
	 , CAST(null AS DOUBLE) as urineoutput
     , CAST(null AS DOUBLE) as iv_total
     , CAST(null AS DOUBLE) as cum_fluid_balance
	 , CAST(null AS DOUBLE) as rate_norepinephrine , CAST(null AS DOUBLE) as rate_epinephrine 
	 , CAST(null AS DOUBLE) as rate_phenylephrine , CAST(null AS DOUBLE) as rate_vasopressin 
	 , CAST(null AS DOUBLE) as rate_dopamine , CAST(null AS DOUBLE) as vaso_total
	-- ventilation parameters
	 , CAST(null AS DECIMAL) as MechVent , CAST(null AS DOUBLE) as FiO2
	 , CAST(null AS DOUBLE) as PEEP, CAST(null AS DOUBLE) as tidal_volume, CAST(null AS DOUBLE) as plateau_pressure		
FROM `getAllVitalSigns` vit
UNION ALL
SELECT subject_id, hadm_id, stay_id, charttime
	--  vital signs
	 , null as gcs, null as heartrate, null as sysbp, null as diasbp, null as meanbp,  null as resprate, null as tempc, null as spo2 
     -- lab values
	 , CAST(null AS DOUBLE) as POTASSIUM , CAST(null AS DOUBLE) as SODIUM , CAST(null AS DOUBLE) as CHLORIDE , CAST(null AS DOUBLE) as GLUCOSE , CAST(null AS DOUBLE) as BUN , CAST(null AS DOUBLE) as CREATININE , CAST(null AS DOUBLE) as MAGNESIUM , CAST(null AS DOUBLE) as IONIZEDCALCIUM , CAST(null AS DOUBLE) as CALCIUM , CAST(null AS DOUBLE) as CARBONDIOXIDE 
	 , CAST(null AS DOUBLE) as SGOT , CAST(null AS DOUBLE) as SGPT , CAST(null AS DOUBLE) as BILIRUBIN , CAST(null AS DOUBLE) as ALBUMIN , CAST(null AS DOUBLE) as HEMOGLOBIN , CAST(null AS DOUBLE) as WBC , CAST(null AS DOUBLE) as PLATELET , CAST(null AS DOUBLE) as PTT , CAST(null AS DOUBLE) as PT , CAST(null AS DOUBLE) as INR , CAST(null AS DOUBLE) as PH , CAST(null AS DOUBLE) as PaO2 , CAST(null AS DOUBLE) as PaCO2
     , CAST(null AS DOUBLE) as BASE_EXCESS , CAST(null AS DOUBLE) as BICARBONATE , CAST(null AS DOUBLE) as LACTATE , CAST(null AS DOUBLE) as BANDS
	--  fluids
	 , urineoutput
     , iv_total
     , cum_fluid_balance
	 , rate_norepinephrine 
     , rate_epinephrine 
     , rate_phenylephrine 
	 , rate_vasopressin 
     , rate_dopamine 
     , vaso_total
	-- ventilation parameters
	 , CAST(null AS DECIMAL) as MechVent 
     , CAST(null AS DOUBLE) as FiO2
	 , CAST(null AS DOUBLE) as PEEP
     , CAST(null AS DOUBLE) as tidal_volume
     , CAST(null AS DOUBLE) as plateau_pressure
FROM `getAllFluids` fl	
UNION ALL
SELECT subject_id, hadm_id, stay_id, charttime
	 --  vital signs
	 , null as gcs
     , null as heartrate
     , null as sysbp
     , null as diasbp
     , null as meanbp
     , null as resprate
     , null as tempc
     , null as spo2 
	 -- lab values
	 , CAST(null AS DOUBLE) as POTASSIUM 
     , CAST(null AS DOUBLE) as SODIUM 
     , CAST(null AS DOUBLE) as CHLORIDE 
     , CAST(null AS DOUBLE) as GLUCOSE 
     , CAST(null AS DOUBLE) as BUN 
     , CAST(null AS DOUBLE) as CREATININE 
     , CAST(null AS DOUBLE) as MAGNESIUM 
     , CAST(null AS DOUBLE) as IONIZEDCALCIUM 
     , CAST(null AS DOUBLE) as CALCIUM 
     , CAST(null AS DOUBLE) as CARBONDIOXIDE 
	 , CAST(null AS DOUBLE) as SGOT 
     , CAST(null AS DOUBLE) as SGPT 
     , CAST(null AS DOUBLE) as BILIRUBIN 
     , CAST(null AS DOUBLE) as ALBUMIN 
     , CAST(null AS DOUBLE) as HEMOGLOBIN 
     , CAST(null AS DOUBLE) as WBC 
     , CAST(null AS DOUBLE) as PLATELET 
     , CAST(null AS DOUBLE) as PTT 
     , CAST(null AS DOUBLE) as PT 
     , CAST(null AS DOUBLE) as INR 
     , CAST(null AS DOUBLE) as PH 
     , CAST(null AS DOUBLE) as PaO2 
     , CAST(null AS DOUBLE) as PaCO2
     , CAST(null AS DOUBLE) as BASE_EXCESS 
     , CAST(null AS DOUBLE) as BICARBONATE 
     , CAST(null AS DOUBLE) as LACTATE 
     , CAST(null AS DOUBLE) as BANDS
	--  fluids
	 , CAST(null AS DOUBLE) as urineoutput
     , CAST(null AS DOUBLE) as iv_total
     , CAST(null AS DOUBLE) as cum_fluid_balance
	 , CAST(null AS DOUBLE) as rate_norepinephrine 
     , CAST(null AS DOUBLE) as rate_epinephrine 
	 , CAST(null AS DOUBLE) as rate_phenylephrine 
     , CAST(null AS DOUBLE) as rate_vasopressin 
	 , CAST(null AS DOUBLE) as rate_dopamine 
     , CAST(null AS DOUBLE) as vaso_total
	-- ventilation parameters
	 , MechVent 
     , fio2_chartevents as FiO2
	 , PEEP as PEEP
     , tidal_volume as tidal_volume
     , plateau_pressure as plateau_pressure	
FROM `getAllVentilationParams` cumflu

) merged 


group by subject_id, hadm_id, stay_id, charttime	
order by subject_id, hadm_id, stay_id, charttime
