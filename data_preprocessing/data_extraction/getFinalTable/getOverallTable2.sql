-- Initial code was retrieved https://github.com/arnepeine/ventai/blob/main/sampling_lab_withventparams.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- Code was modified to be campatible with MIMIC IV.

-- This code samples the data within table 'overalltable' with a resolution of 4 hours. 
use mimic4;
SET GLOBAL innodb_buffer_pool_size = 322122547200;

DROP table IF EXISTS `numbers`;

CREATE TABLE numbers (n INT);
DROP PROCEDURE IF EXISTS `InsertNumbers`;

DELIMITER //
CREATE PROCEDURE InsertNumbers()
BEGIN
  DECLARE i INT DEFAULT 0;

  WHILE i <= 4000 DO
    INSERT INTO numbers (n) VALUES (i);
    SET i = i + 1;
  END WHILE;
END;
//
DELIMITER ;

CALL InsertNumbers();



DROP table IF EXISTS `grid`;
CREATE table `grid` as
WITH minmax as(
SELECT subject_id, hadm_id, stay_id , min(charttime) as mint, max(charttime) as maxt
FROM `OverallTable`
GROUP BY stay_id, subject_id, hadm_id
ORDER BY stay_id, subject_id, hadm_id
	)
-- select * from minmax;
-- ,grid as (
-- 	SELECT stay_id, subject_id, hadm_id, CAST(start_time AS DATETIME) as start_time
-- 	FROM minmax, UNNEST(GENERATE_TIMESTAMP_ARRAY(CAST(mint as timestamp), CAST(maxt as timestamp), INTERVAL 4 HOUR)) as start_time
--     ORDER BY stay_id, subject_id, hadm_id,start_time)
SELECT
    stay_id,
    subject_id,
    hadm_id,
    CAST(TIMESTAMPADD(HOUR, 4 * numbers.n, CAST(mint AS DATETIME)) AS DATETIME) AS start_time
FROM minmax JOIN numbers
ON TIMESTAMPADD(HOUR, 4 * numbers.n, CAST(mint AS DATETIME)) <= CAST(maxt AS DATETIME)
ORDER BY
    stay_id, subject_id, hadm_id, start_time;



select count(*) from grid;

CREATE INDEX grid_index_stay_id ON grid (stay_id);
CREATE INDEX grid_index_subject_id ON grid (subject_id);
CREATE INDEX grid_index_hadm_id ON grid (hadm_id);
CREATE INDEX grid_index_start_time ON grid(start_time);




CREATE INDEX OverallTable_index_stay_id2 ON OverallTable(stay_id);
CREATE INDEX OverallTable_index_subject_id2 ON OverallTable (subject_id);
CREATE INDEX OverallTable_index_hadm_id2 ON OverallTable (hadm_id);
CREATE INDEX OverallTable_index_start_time2 ON OverallTable(charttime);



DROP table IF EXISTS `OverallTable2`;
CREATE table `OverallTable2` as
	
SELECT ot.stay_id, ot.subject_id, ot.hadm_id, start_time
     , round(avg(gcs)) as gcs , avg(heartrate) as heartrate , avg(sysbp) as sysbp , avg(diasbp) as diasbp , avg(meanbp) as meanbp
	 , avg(shockindex) as shockindex, avg(RespRate) as RespRate
     , avg(TempC) as TempC , avg(SpO2) as SpO2 
	 -- lab values
	 , avg(POTASSIUM) as POTASSIUM , avg(SODIUM) as SODIUM , avg(CHLORIDE) as CHLORIDE , avg(GLUCOSE) as GLUCOSE
	 , avg(BUN) as BUN , avg(CREATININE) as CREATININE , avg(MAGNESIUM) as MAGNESIUM , avg(CALCIUM) as CALCIUM , avg(ionizedcalcium) ionizedcalcium
	 , avg(CARBONDIOXIDE) as CARBONDIOXIDE , avg(SGOT) as SGOT , avg(SGPT) as SGPT, avg(BILIRUBIN) as BILIRUBIN , avg(ALBUMIN) as ALBUMIN 
	 , avg(HEMOGLOBIN) as HEMOGLOBIN , avg(WBC) as WBC , avg(PLATELET) as PLATELET , avg(PTT) as PTT
     , avg(PT) as PT , avg(INR) as INR , avg(PH) as PH , avg(PaO2) as PaO2 , avg(PaCO2) as PaCO2
     , avg(BASE_EXCESS) as BASE_EXCESS , avg(BICARBONATE) as BICARBONATE , avg(LACTATE) as LACTATE 
	 ,avg(pao2fio2ratio) as pao2fio2ratio, avg(BANDS) as BANDS --  this is only included in order to calculate SIRS score
	 -- ventilation parameters
	 , CAST(avg(mechvent)>0 AS DECIMAL) as MechVent -- as long as at least one flag is 1 at the timepoint make overall as 1
	 , avg(FiO2) as FiO2
	 -- urine output
	 , sum(urineoutput) as urineoutput
	 --  vasopressors
	 , max(rate_norepinephrine) as rate_norepinephrine , max(rate_epinephrine) as rate_epinephrine 
	 , max(rate_phenylephrine) as rate_phenylephrine , max(rate_vasopressin) as rate_vasopressin 
	 , max(rate_dopamine) as rate_dopamine , max(vaso_total) as vaso_total
	 --  intravenous fluids
	 , sum(iv_total) as iv_total
	 --  cumulative fluid balance
	 , avg(cum_fluid_balance) as cum_fluid_balance
	 --  ventilation parameters
	 , max(PEEP) as PEEP, max(tidal_volume) as tidal_volume, max(plateau_pressure) as plateau_pressure
FROM grid g
LEFT JOIN `OverallTable` ot ON ot.charttime >= g.start_time
				   AND ot.charttime <  DATE_ADD(g.start_time, INTERVAL 4 hour)
				   AND ot.stay_id=g.stay_id
				   AND ot.subject_id=g.subject_id
				   AND ot.hadm_id=g.hadm_id

GROUP  BY ot.stay_id,ot.subject_id, ot.hadm_id, start_time
ORDER  BY stay_id,subject_id, hadm_id, start_time;
