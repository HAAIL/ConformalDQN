-- Code was modified to be campatible with MIMIC IV.

use mimic4;

 DROP table IF EXISTS `getMainDemographics` ;
 CREATE table `getMainDemographics` as
WITH first_admission_time AS
(
  SELECT
      p.subject_id, a.hadm_id, i.stay_id, p.anchor_year, p.gender, p.dod, MIN(a.admittime) AS first_admittime
      ,MIN(ROUND(CAST(YEAR(a.admittime) - p.anchor_year + p.anchor_age AS DECIMAL), 2))
          AS first_admit_age
	  -- This part is retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/cookbook/mortality.sql
	  ,(CASE WHEN p.dod > i.intime AND p.dod < i.outtime THEN 1 ELSE 0 END) AS ICUMort
	  , hospital_expire_flag AS HospMort
	  , (CASE WHEN dod < admittime + interval '28' day THEN 1 ELSE 0 END)  AS HospMort28day
	  , (CASE WHEN dod < admittime + interval '90' day THEN 1 ELSE 0 END)  AS HospMort90day
	  , a.dischtime , a.deathtime
	
  FROM `icustays` i -- , mimiciii.chartevents ce
 
  INNER JOIN `admissions` a
  ON a.hadm_id = i.hadm_id
  INNER JOIN `patients` p
  ON p.subject_id = i.subject_id
  GROUP BY p.subject_id, p.anchor_year, p.gender, p.dod, a.admittime, /*ce.itemid, ce.valuenum,*/a.hadm_id , a.dischtime, a.deathtime,a.hospital_expire_flag,i.stay_id,i.intime, i.outtime
  ORDER BY p.subject_id
),

-- select * from first_admission_time;

hos_admissions as
(SELECT DISTINCT(subject_id)
 , (CASE WHEN COUNT(stay_id)>1 then 1 else 0 end) as ICU_readm
FROM first_admission_time
GROUP By subject_id)

-- SELECT * FROM first_admission_time LIMIT 19;

SELECT
    f.subject_id , f.hadm_id, f.stay_id, f.first_admit_age, 
	f.gender, /*admit_weight_kg,*/  h.ICU_readm
	,eli.elixhauser_vanwalraven as elixhauser_score
	, f.ICUMort, f.HospMort, f.HospMort28day, f.HospMort90day, f.dischtime, f.deathtime
	
FROM first_admission_time f
INNER JOIN hos_admissions h
ON f.subject_id=h.subject_id
INNER JOIN `getElixhauserScore` eli
ON f.subject_id=eli.subject_id AND  f.hadm_id=eli.hadm_id
ORDER BY subject_id, hadm_id;


select * from getMainDemographics;