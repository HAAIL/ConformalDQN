-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getCumFluid.sql
-- Modifications were made when needed for performance improvement, readability or simplification.

DROP table IF EXISTS `getCumFluid`;
CREATE table `getCumFluid` as 

SELECT subject_id, hadm_id, stay_id, charttime, in_amount, in_cum_amt, out_amount, out_cum_amt,
       sum(out_amount) OVER (PARTITION BY in_out.stay_id ORDER BY charttime)
	   -sum(in_amount) OVER (PARTITION BY in_out.stay_id ORDER BY charttime) as cum_fluid_balance
FROM(

SELECT subject_id, hadm_id,merged.stay_id,charttime, in_amount,
       sum(in_amount) OVER (PARTITION BY merged.stay_id ORDER BY charttime) AS in_cum_amt,
	   CAST(null AS DOUBLE) AS out_amount, CAST(null AS DOUBLE) AS out_cum_amt -- ,valueuom
FROM (
	SELECT stay_id, starttime as charttime, 
	-- Some unit conversions that will end up in 'mL'.
	(CASE WHEN amountuom in ('cc','ml') THEN sum(amount) 
	      WHEN amountuom='L'  THEN sum(amount)*0.001 
	      WHEN amountuom='uL' THEN sum(amount)*1000  END) as in_amount
	FROM `inputevents` inevmv
	WHERE amountuom in ('L','ml','uL','cc')
	GROUP BY stay_id,charttime,amountuom) as merged
INNER JOIN `icustays` ic
ON ic.stay_id=merged.stay_id

UNION ALL

-- Output events.

SELECT subject_id, hadm_id,merged.stay_id, charttime, 
       CAST(null AS DOUBLE) AS in_amount, CAST(null AS DOUBLE) AS in_cum_amt, out_amount,
       sum(out_amount) OVER (PARTITION BY merged.stay_id ORDER BY charttime) AS out_cum_amt -- ,valueuom
FROM (
	SELECT stay_id, charttime, sum(value) as out_amount
	FROM `outputevents` outev
	WHERE valueuom in ('mL','ml')
	GROUP BY stay_id,charttime) as merged
INNER JOIN `icustays` ic
ON ic.stay_id=merged.stay_id
	) AS in_out

ORDER BY stay_id,charttime
