-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getIntravenous.sql
-- Modifications were made when needed for performance improvement, readability or simplification.


DROP table IF EXISTS `getIntravenous`;
CREATE table  `getIntravenous` AS

WITH intra as (SELECT * 
FROM `inputevents`
WHERE ordercategoryname IN ('03-IV Fluid Bolus','02-Fluids (Crystalloids)','04-Fluids (Colloids)','07-Blood Products')
	OR secondaryordercategoryname IN ('03-IV Fluid Bolus','02-Fluids (Crystalloids)','04-Fluids (Colloids)','07-Blood Products')
 )
 
SELECT subject_id, hadm_id , stay_id, starttime as charttime
	 , avg(totalamount) as amount
FROM intra

group by subject_id, hadm_id  , stay_id, charttime
order by subject_id, hadm_id , stay_id, charttime
