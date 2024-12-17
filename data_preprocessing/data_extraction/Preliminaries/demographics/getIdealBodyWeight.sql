-- Code retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/demographics/HeightWeightQuery.sql
-- Code was modified to be campatible with MIMIC IV.

-- Modifications were made when needed for performance improvement, readability or simplification.

use mimic4;

DROP table IF EXISTS `idealbodyweight`;
CREATE table `idealbodyweight` AS
WITH FirstVRawData AS
  (SELECT c.charttime,
    c.itemid,c.subject_id,c.stay_id,
    CASE
      WHEN c.itemid IN (762, 763, 3723, 3580, 3581, 3582, 226512)  -- Admission Weight (Kg) 226512
        THEN 'WEIGHT'
      WHEN c.itemid IN (920, 1394, 4187, 3486, 3485, 4188, 226707) -- Height 226707
        THEN 'HEIGHT'
    END AS parameter,
    -- Ensure that all weights are in kg and heights are in centimeters
    CASE
      WHEN c.itemid   IN (3581, 226531)
        THEN c.valuenum * 0.45359237
      WHEN c.itemid   IN (3582)
        THEN c.valuenum * 0.0283495231
      WHEN c.itemid   IN (920, 1394, 4187, 3486, 226707)
        THEN c.valuenum * 2.54
      ELSE c.valuenum
    END AS valuenum
  FROM `chartevents` c
  WHERE c.valuenum   IS NOT NULL
  -- exclude rows marked as error
  AND c.warning != 1
  AND ( ( c.itemid  IN (762, 763, 3723, 3580, -- Weight Kg
    3581,                                     -- Weight lb
    3582,                                     -- Weight oz
    920, 1394, 4187, 3486,                    -- Height inches
    3485, 4188                               -- Height cm
    -- Metavision
    , 226707 -- Height (measured in inches)
    , 226512 -- Admission Weight (Kg)

    -- note we intentionally ignore the below ITEMIDs in metavision
    -- these are duplicate data in a different unit
    -- , 226531 -- Admission Weight (lbs.)
    -- , 226730 -- Height (cm)
    )
  AND c.valuenum <> 0 )
    ) )
  -- )

 --  select * from FirstVRawData;
, SingleParameters AS (
  SELECT DISTINCT subject_id,
         stay_id,
         parameter,
         first_value(valuenum) over
            (partition BY subject_id, stay_id, parameter
             order by charttime ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
             AS first_valuenum,
         MIN(valuenum) over
            (partition BY subject_id, stay_id, parameter
            order by charttime ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
            AS min_valuenum,
         MAX(valuenum) over
            (partition BY subject_id, stay_id, parameter
            order by charttime ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING)
            AS max_valuenum
    FROM FirstVRawData

--   ORDER BY subject_id,
--            stay_id,
--            parameter
  )
-- select * from SingleParameters;
, PivotParameters AS (SELECT subject_id, stay_id,
    MAX(case when parameter = 'HEIGHT' then first_valuenum else NULL end) AS height_first,
    MAX(case when parameter = 'HEIGHT' then min_valuenum else NULL end)   AS height_min,
    MAX(case when parameter = 'HEIGHT' then max_valuenum else NULL end)   AS height_max,
    MAX(case when parameter = 'WEIGHT' then first_valuenum else NULL end) AS weight_first,
    MAX(case when parameter = 'WEIGHT' then min_valuenum else NULL end)   AS weight_min,
    MAX(case when parameter = 'WEIGHT' then max_valuenum else NULL end)   AS weight_max
  FROM SingleParameters
  GROUP BY subject_id,
    stay_id
  ),ideal_weight_tmp as
  (
SELECT f.stay_id,
  f.subject_id,
  pat.gender,
  ROUND( cast(f.height_first as decimal), 2) AS height_first,
  ROUND(cast(f.height_min as decimal),2) AS height_min,
  ROUND(cast(f.height_max as decimal),2) AS height_max,
  ROUND(cast(f.weight_first as decimal), 2) AS weight_first,
  ROUND(cast(f.weight_min as decimal), 2)   AS weight_min,
  ROUND(cast(f.weight_max as decimal), 2)   AS weight_max,
   (CASE when gender='M' then 50 + (f.height_first/100*3.28-5)*12*2.3
        when gender='F' then 45.5 + (f.height_first/100*3.28-5)*12*2.3 end) as ideal_body_weight_kg

FROM PivotParameters f
LEFT JOIN `patients` pat
ON f.subject_id=pat.subject_id
	  )
-- SELECT * from SingleParameters where stay_id =39765666  ;    
      
SELECT 
  stay_id,
  subject_id,
  gender,
  height_first,
  height_min,
  height_max,
  weight_first,
  weight_min,
  weight_max,
  -- If ideal body weight is null (i.e. height info not available) or if it is negative, put the first weight.
  (CASE WHEN ideal_body_weight_kg IS NULL OR ideal_body_weight_kg<0 THEN weight_first*0.82
  -- 0.82 was found to be the mean ratio ideal_body_weight_kg/weight_first
  		ELSE ideal_body_weight_kg END) as ideal_body_weight_kg
FROM ideal_weight_tmp
ORDER BY stay_id,subject_id;



