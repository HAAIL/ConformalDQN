-- Initial code for the vital sign portion was retrieved from https://github.com/arnepeine/ventai/blob/main/getVitalSigns.sql
-- Initial code for the GCS portion was retrieved from https://github.com/arnepeine/ventai/blob/main/getGCS.sql
-- Modifications were made when needed for performance improvement, readability or simplification.


-- SHOW VARIABLES LIKE 'innodb_buffer_pool_size';
-- SET GLOBAL innodb_buffer_pool_size=1073741824;


DROP table IF EXISTS `getAllVitalSigns`;
CREATE table `getAllVitalSigns` as

--  STEP 1: GET ALL VITAL SIGNS EXCEPT GCS SCORE

with ce as
(
  select ce.stay_id, ce.subject_id, ce.hadm_id, ce.charttime
    , (case when itemid in (211,220045) and valuenum > 0 and valuenum < 300 then valuenum else null end) as HeartRate
    , (case when itemid in (51,442,455,6701,220179,220050) and valuenum > 0 and valuenum < 400 then valuenum else null end) as SysBP
    , (case when itemid in (8368,8440,8441,8555,220180,220051) and valuenum > 0 and valuenum < 300 then valuenum else null end) as DiasBP
    , (case when itemid in (456,52,6702,443,220052,220181,225312) and valuenum > 0 and valuenum < 300 then valuenum else null end) as MeanBP
    , (case when itemid in (615,618,220210,224690) and valuenum > 0 and valuenum < 70 then valuenum else null end) as RespRate
    , (case when itemid in (223761,678) and valuenum > 70 and valuenum < 120 then (valuenum-32)/1.8 --  converted to degC in valuenum call
               when itemid in (223762,676) and valuenum > 10 and valuenum < 50  then valuenum else null end) as TempC
    , (case when itemid in (646,220277) and valuenum > 0 and valuenum <= 100 then valuenum else null end) as SpO2
    -- , (case when itemid in (807,811,1529,3745,3744,225664,220621,226537) and valuenum > 0 then valuenum else null end) as Glucose
  from `chartevents` ce
  where ce.itemid in
  (
  211, 220045, -- Heart Rate
  51,442,455,6701,220179,220050, -- respectively Arterial BP [Systolic], Manual BP [Systolic], NBP [Systolic], Arterial BP #2 [Systolic], Non Invasive BP [Systolic], Arterial BP [Systolic]
  8368,8440,8441,8555,220180,220051, -- 	respectively Arterial BP [Diastolic], Manual BP [Diastolic], NBP [Diastolic], Arterial BP #2 [Diastolic], Non Invasive BP [Diastolic], Arterial BP [Diastolic]
  456,52,6702,443,220052,220181,225312,--  respectively NBP Mean, Arterial BP Mean, Arterial BP Mean #2, Manual BP Mean(calc), Arterial BP mean, Non Invasive BP mean, ART BP mean
  618, 615,220210,224690,--  Respiratory Rate, Resp Rate (Total), Respiratory Rate, Respiratory Rate (Total)
  646, 220277, --  SPO2, peripheral
  223762,676,223761,678 --  respectively Temperature Celsius, Temperature C, Temperature Fahrenheit, Temperature F
)) ,

--  STEP 2: GET THE GCS SCORE

 base as
(
  select  ce.subject_id,ce.stay_id,ce.hadm_id, ce.charttime
  --  pivot each value into its own column
  , max(case when ce.ITEMID in (223901) then ce.valuenum else null end) as GCSMotor
  , max(case when ce.ITEMID in (223900) then ce.valuenum else null end) as GCSVerbal
  , max(case when ce.ITEMID in (220739) then ce.valuenum else null end) as GCSEyes
  --  convert the data into a number, reserving a value of 0 for ET/Trach
  , max(case
      --  endotrach/vent is assigned a value of 0, later parsed specially
      when ce.ITEMID = 223900 and ce.VALUE = 'No Response-ETT' then 1 --  
    else 0 end)
    as endotrachflag
  , ROW_NUMBER ()
          OVER (PARTITION BY ce.stay_id ORDER BY ce.charttime ASC) as rn
  from `chartevents` ce
  --  Isolate the desired GCS variables
  where ce.ITEMID in
  (
    --  GCS components, Metavision
     223900, 223901, 220739
  )

  group by ce.subject_id,ce.stay_id,ce.hadm_id, ce.charttime
)
, gcs as (
  select b.*
  , b2.GCSVerbal as GCSVerbalPrev
  , b2.GCSMotor as GCSMotorPrev
  , b2.GCSEyes as GCSEyesPrev
  --  Calculate GCS, factoring in special case when they are intubated and prev vals
  --  note that the coalesce are used to implement the following if:
  --   if current value exists, use it
  --   if previous value exists, use it
  --   otherwise, default to normal
  , case
      --  replace GCS during sedation with 15
      when b.GCSVerbal = 0
        then 15
      when b.GCSVerbal is null and b2.GCSVerbal = 0
        then 15
      --  if previously they were intub, but they aren't now, do not use previous GCS values
      when b2.GCSVerbal = 0
        then
            coalesce(b.GCSMotor,6)
          + coalesce(b.GCSVerbal,5)
          + coalesce(b.GCSEyes,4)
      --  otherwise, add up score normally, imputing previous value if none available at current time
      else
            coalesce(b.GCSMotor,coalesce(b2.GCSMotor,6))
          + coalesce(b.GCSVerbal,coalesce(b2.GCSVerbal,5))
          + coalesce(b.GCSEyes,coalesce(b2.GCSEyes,4))
      end as GCS

  from base b
  --  join to itself within 6 hours to get previous value
  left join base b2
    on b.stay_id = b2.stay_id
    and b.rn = b2.rn+1
    and b2.charttime > b.charttime - interval '6' hour
)
--  combine components with previous within 6 hours
--  filter down to cohort which is not excluded
--  truncate charttime to the hour
, gcs_stg as
(
  select  gs.subject_id,gs.stay_id,gs.hadm_id, gs.charttime
  , GCS
  , coalesce(GCSMotor,GCSMotorPrev) as GCSMotor
  , coalesce(GCSVerbal,GCSVerbalPrev) as GCSVerbal
  , coalesce(GCSEyes,GCSEyesPrev) as GCSEyes
  , case when coalesce(GCSMotor,GCSMotorPrev) is null then 0 else 1 end
  + case when coalesce(GCSVerbal,GCSVerbalPrev) is null then 0 else 1 end
  + case when coalesce(GCSEyes,GCSEyesPrev) is null then 0 else 1 end
    as components_measured
  , EndoTrachFlag
  from gcs gs
)
--  priority is:
--   (i) complete data, (ii) non-sedated GCS, (iii) lowest GCS, (iv) charttime
, gcs_priority as
(
  select subject_id,stay_id,hadm_id
    , charttime
    , GCS
    , GCSMotor
    , GCSVerbal
    , GCSEyes
    , EndoTrachFlag
    , ROW_NUMBER() over
      (
        PARTITION BY stay_id, charttime
        ORDER BY components_measured DESC, endotrachflag, gcs, charttime DESC
      ) as rn
  from gcs_stg
)



, getGCS as (select subject_id as subject_id,  hadm_id as hadm_id ,stay_id as stay_id, charttime as charttime, GCS, GCSMotor, GCSVerbal, GCSEyes, EndoTrachFlag
FROM gcs_priority gs where rn = 1
ORDER BY stay_id, charttime)

--  STEP 3: Get vital signs including GCS in one table
,get_all_signs as  ((SELECT   ce.subject_id,
  ce.hadm_id,
  ce.stay_id,
  ce.charttime,
  ce.HeartRate,
  ce.SysBP,
  ce.DiasBP,
  ce.MeanBP,
  ce.RespRate,
  ce.TempC,
  ce.SpO2,
  getGCS.gcs
  FROM ce
 LEFT JOIN getGCS ON ce.stay_id = getGCS.stay_id AND ce.charttime = getGCS.charttime)
UNION
(SELECT getGCS.subject_id,
  getGCS.hadm_id,
  getGCS.stay_id,
  getGCS.charttime,
  ce.HeartRate,
  ce.SysBP,
  ce.DiasBP,
  ce.MeanBP,
  ce.RespRate,
  ce.TempC,
  ce.SpO2,
  getGCS.gcs
  FROM ce
 RIGHT JOIN getGCS ON ce.stay_id = getGCS.stay_id AND ce.charttime = getGCS.charttime
 WHERE ce.subject_id IS NULL))



SELECT
  subject_id,
  hadm_id,
  stay_id,
  charttime,
  gcs,
  AVG(HeartRate) AS HeartRate,
  AVG(SysBP) AS SysBP,
  AVG(DiasBP) AS DiasBP,
  AVG(MeanBP) AS MeanBP,
  AVG(RespRate) AS RespRate,
  AVG(TempC) AS TempC,
  AVG(SpO2) AS SpO2
FROM get_all_signs
GROUP BY subject_id, hadm_id, stay_id, charttime, gcs
ORDER BY stay_id, hadm_id,  charttime;

;

