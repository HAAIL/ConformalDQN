-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getLabValues.sql and https://github.com/arnepeine/ventai/blob/main/getOthers.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
use mimic4;
select * from labevents limit 10;
select * from icustays limit 10;

select * from labevents where subject_id =10001884;

DROP table IF EXISTS `getAllLabvalues`;
CREATE table `getAllLabvalues` as

with le as
(
  select ic.intime,ic.outtime,le.subject_id , le.hadm_id, ic.stay_id
    , le.charttime
    , (CASE WHEN itemid = 50862 and valuenum>0 and valuenum <    10 THEN valuenum else null end) as ALBUMIN --  g/dL 'ALBUMIN')
    , (CASE WHEN itemid = 50868 and valuenum>0 and valuenum < 10000 THEN valuenum ELSE null end) as ANIONGAP --  mEq/L 'ANION GAP'
    , (CASE WHEN itemid = 51144 and valuenum>0 and valuenum <100 THEN valuenum else null end) as BANDS --  immature band forms, %
    -- , (CASE WHEN itemid = 51144 and valuenum >   100 THEN null --  immature band forms, %
    , (CASE WHEN itemid = 50882 and valuenum>0 and valuenum <10000 THEN valuenum else null end) as BICARBONATE --  mEq/L 'BICARBONATE'
    , (CASE WHEN itemid = 50885 and valuenum>0 and valuenum <150 THEN valuenum else null end) as BILIRUBIN --  mg/dL 'BILIRUBIN'
    , (CASE WHEN itemid in (50806, 50902) and valuenum>0 and valuenum <10000 THEN valuenum else null end) as CHLORIDE --  mEq/L 'CHLORIDE'
    -- , (CASE WHEN itemid = 50902 and valuenum > 10000 THEN null --  mEq/L 'CHLORIDE'
    , (CASE WHEN itemid = 50912 and valuenum>0 and valuenum <150 THEN valuenum else null end) as CREATININE--  mg/dL 'CREATININE'
    , (CASE WHEN itemid in (50809,50931) and valuenum>0 and valuenum <10000 THEN valuenum else null end) as GLUCOSE --  mg/dL 'GLUCOSE'
    -- , (CASE WHEN itemid = 50931 and valuenum > 10000 THEN null --  mg/dL 'GLUCOSE'
    , (CASE WHEN itemid in (50810,51221) and valuenum>0 and valuenum <100 THEN valuenum else null end) as HEMATOCRIT --  % 'HEMATOCRIT'
    -- , (CASE WHEN itemid = 51221 and valuenum >   100 THEN null --  % 'HEMATOCRIT'
    , (CASE WHEN itemid in (50811,51222) and valuenum>0 and valuenum <50 THEN valuenum else null end) as HEMOGLOBIN --  g/dL 'HEMOGLOBIN'
    -- , (CASE WHEN itemid = 51222 and valuenum >    50 THEN null --  g/dL 'HEMOGLOBIN'
    , (CASE WHEN itemid = 50813 and valuenum>0 and valuenum <50 THEN valuenum else null end) as LACTATE --  mmol/L 'LACTATE'
    , (CASE WHEN itemid = 51265 and valuenum>0 and valuenum <10000 THEN valuenum else null end) as PLATELET --  K/uL 'PLATELET'
    , (CASE WHEN itemid in (50822,50971) and valuenum>0 and valuenum <30 THEN valuenum else null end) as POTASSIUM --  mEq/L 'POTASSIUM'
    -- , (CASE WHEN itemid = 50971 and valuenum >    30 THEN null --  mEq/L 'POTASSIUM'
    , (CASE WHEN itemid = 51275 and valuenum>0 and valuenum <150 THEN valuenum else null end) as PTT --  sec 'PTT'
    , (CASE WHEN itemid = 51237 and valuenum>0 and valuenum <50 THEN valuenum else null end) as INR --  'INR'
    , (CASE WHEN itemid = 51274 and valuenum>0 and valuenum <150 THEN valuenum else null end) as PT --  sec 'PT'
    , (CASE WHEN itemid in (50824,50983) and valuenum>0 and valuenum <200 THEN valuenum else null end) as SODIUM --  mEq/L == mmol/L 'SODIUM'
    --   WHEN itemid = 50983 and valuenum >   200 THEN null --  mEq/L == mmol/L 'SODIUM'
    , (CASE WHEN itemid = 51006 and valuenum>0 and valuenum <300 THEN valuenum else null end) as BUN --  'BUN'
    , (CASE WHEN itemid in (51300,51301) and valuenum>0 and valuenum <1000 THEN valuenum else null end) as WBC --  'WBC'
    --   WHEN itemid = 51301 and valuenum >  1000 THEN null --  'WBC'
	, (CASE WHEN itemid in (50960) and valuenum>0  THEN valuenum else null end) as MAGNESIUM --  mEq/L == mmol/L 'MAGNESIUM' (units taken from loinc code 2601-3, code is given in d_labitems, could not find an upper limit)
	, (CASE WHEN itemid in (50804) and valuenum>0  THEN valuenum else null end) as CARBONDIOXIDE --  mEq/L == mmol/L 'CARBONDIOXIDE' (units taken from loinc code 34728-6, code is given in d_labitems, could not find an upper limit)
	, (CASE WHEN itemid in (50802) and valuenum>-10 and valuenum<10  THEN valuenum else null end) as BASE_EXCESS --  mEq/L == mmol/L 'BASE_EXCESS' (units taken from loinc code 11555-0, code is given in d_labitems, this can be negative, according to loinc site range is [-2,3])
	, (CASE WHEN itemid in (50893) and valuenum>0 THEN valuenum else null end) as CALCIUM --  mEq/L == mmol/L 'CALCIUM' (units taken from loinc code 2000-8, code is given in d_labitems, could not find an upper limit)
	, (CASE WHEN itemid in (50820) and valuenum>7 and valuenum<8 THEN valuenum else null end) as pH
	, (CASE WHEN itemid in (50821) and valuenum>70 and valuenum<110 THEN valuenum else null end) as PaO2--  mmHg 'PaO2' (units taken from loinc code 11556-8, this actually corresponds to PO2(not PaO2 where 'a' stands for arterial) but couls not find any other related value)
	, (CASE WHEN itemid in (50818) and valuenum>22 and valuenum<58 THEN valuenum else null end) as PaCO2--  mmHg 'PaCO2' (units taken from loinc code 11557-6, this actually corresponds to PCO2(not PaCO2 where 'a' stands for arterial) but couls not find any other related value)
	
    -- ELSE le.valuenum
  from `labevents` le
	--  LABEVENTS do not have a stay_id recorded. However, that can be obtained using clues such as the subject_id and hadm_id; and comparing the charttime of the measurement with an icustay time.
	--  This idea of adding icustays has been retrieved from https://github.com/MIT-LCP/mimic-code/blob/master/concepts/firstday/blood-gas-first-day.sql.
		left join `icustays` ic
		on le.subject_id = ic.subject_id and le.hadm_id = ic.hadm_id
		and le.charttime between (ic.intime - interval '6' hour) and (ic.outtime + interval '1' day )
  -- where ce.error IS DISTINCT FROM 1
  where le.itemid in
  (
  --  comment is: LABEL | CATEGORY | FLUID | NUMBER OF ROWS IN LABEVENTS
    50868, --  ANION GAP | CHEMISTRY | BLOOD | 769895
    50862, --  ALBUMIN | CHEMISTRY | BLOOD | 146697
    51144, --  BANDS - hematology
    50882, --  BICARBONATE | CHEMISTRY | BLOOD | 780733
    50885, --  BILIRUBIN, TOTAL | CHEMISTRY | BLOOD | 238277
    50912, --  CREATININE | CHEMISTRY | BLOOD | 797476
    50902, --  CHLORIDE | CHEMISTRY | BLOOD | 795568
    50806, --  CHLORIDE, WHOLE BLOOD | BLOOD GAS | BLOOD | 48187
    50931, --  GLUCOSE | CHEMISTRY | BLOOD | 748981
    50809, --  GLUCOSE | BLOOD GAS | BLOOD | 196734
    51221, --  HEMATOCRIT | HEMATOLOGY | BLOOD | 881846
    50810, --  HEMATOCRIT, CALCULATED | BLOOD GAS | BLOOD | 89715
    51222, --  HEMOGLOBIN | HEMATOLOGY | BLOOD | 752523
    50811, --  HEMOGLOBIN | BLOOD GAS | BLOOD | 89712
    50813, --  LACTATE | BLOOD GAS | BLOOD | 187124
    51265, --  PLATELET COUNT | HEMATOLOGY | BLOOD | 778444
    50971, --  POTASSIUM | CHEMISTRY | BLOOD | 845825
    50822, --  POTASSIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 192946
    51275, --  PTT | HEMATOLOGY | BLOOD | 474937
    51237, --  INR(PT) | HEMATOLOGY | BLOOD | 471183
    51274, --  PT | HEMATOLOGY | BLOOD | 469090
    50983, --  SODIUM | CHEMISTRY | BLOOD | 808489
    50824, --  SODIUM, WHOLE BLOOD | BLOOD GAS | BLOOD | 71503
    51006, --  UREA NITROGEN | CHEMISTRY | BLOOD | 791925
    51301, --  WHITE BLOOD CELLS | HEMATOLOGY | BLOOD | 753301
    51300,  --  WBC COUNT | HEMATOLOGY | BLOOD | 2371
	
	50960, -- MAGNESIUM
	50804, --  CARBONDIOXIDE
	50802, --  BASE_EXCESS
	50893, --  CALCIUM TOTAL
	50820, --  pH
	50821, --  pO2
	50818 --  pCO2
	
	 )   
)

-- select count(*) from le where stay_id is not null;


, ce as
(
  select ce.stay_id, ce.subject_id, ce.hadm_id, ce.charttime
    , (case when itemid in (3801)  then valuenum else null end) as SGOT
    , (case when itemid in (3802)  then valuenum else null end) as SGPT
    , (case when itemid in (816,1350,3766,8177,8325,225667)  then valuenum else null end) as IonizedCalcium
  from `chartevents` ce where  ce.itemid in
  (3801,3802, --  SGOT and SGPT
   816,1350,3766,8177,8325,225667 --  Ionized Calcium
))

-- select * from ce;

,others as(
  select subject_id, hadm_id, ce.stay_id, ce.charttime, avg(SGOT) as SGOT, avg(SGPT) as SGPT, avg(IonizedCalcium) as IonizedCalcium
  from ce
  group by ce.subject_id,ce.hadm_id,ce.stay_id, ce.charttime
)


,joined_tables as (
  (select
  	le.subject_id as subject_id, le.hadm_id as hadm_id, le.stay_id as stay_id, le.charttime as charttime,  ALBUMIN , ANIONGAP , 
       BANDS ,  BASE_EXCESS , BICARBONATE,  BILIRUBIN ,  CHLORIDE ,
      CARBONDIOXIDE , CALCIUM , CREATININE, GLUCOSE , HEMATOCRIT
     , HEMOGLOBIN, LACTATE, MAGNESIUM, PH, PLATELET, POTASSIUM, 
  PTT, INR, PT,  SODIUM,  BUN, WBC, PaO2, PaCO2,
  others.SGOT,  others.SGPT, others.IonizedCalcium
  from le LEFT JOIN others ON (le.stay_id = others.stay_id) AND (le.charttime = others.charttime))
  union
  (select
  	others.subject_id as subject_id, others.hadm_id as hadm_id, others.stay_id as stay_id, others.charttime as charttime,  ALBUMIN , ANIONGAP , 
       BANDS ,  BASE_EXCESS , BICARBONATE,  BILIRUBIN ,  CHLORIDE ,
      CARBONDIOXIDE , CALCIUM , CREATININE, GLUCOSE , HEMATOCRIT
     , HEMOGLOBIN, LACTATE, MAGNESIUM, PH, PLATELET, POTASSIUM, 
  PTT, INR, PT,  SODIUM,  BUN, WBC, PaO2, PaCO2,
  others.SGOT,  others.SGPT, others.IonizedCalcium
  from le Right JOIN others ON (le.stay_id = others.stay_id) AND (le.charttime = others.charttime)
  where le.subject_id is null
  )
)



 -- select * from joined_tables limit 10;





  select
  	subject_id , hadm_id , stay_id , charttime as charttime, avg(ALBUMIN) as ALBUMIN , avg(ANIONGAP) as ANIONGAP , 
      avg(BANDS) as BANDS , avg(BASE_EXCESS) as BASE_EXCESS , avg(BICARBONATE) as BICARBONATE, avg(BILIRUBIN) as BILIRUBIN , avg(CHLORIDE) as CHLORIDE ,
      avg(CARBONDIOXIDE) as CARBONDIOXIDE , avg(CALCIUM) as CALCIUM , avg(CREATININE) as CREATININE, avg(GLUCOSE) as GLUCOSE , avg(HEMATOCRIT) as HEMATOCRIT
  , avg(HEMOGLOBIN) as HEMOGLOBIN, avg(LACTATE) as LACTATE, avg(MAGNESIUM) as MAGNESIUM, avg(PH) as PH, avg(PLATELET) as PLATELET, avg(POTASSIUM) as POTASSIUM, 
  avg(PTT) as PTT, avg(INR) as INR, avg(PT) as PT, avg(SODIUM) as SODIUM, avg(BUN) as BUN, avg(WBC) as WBC, avg(PaO2) as PaO2, avg(PaCO2) as PaCO2,
  avg(SGOT) as SGOT, avg(SGPT) as SGPT, avg(IonizedCalcium) as IonizedCalcium
  from joined_tables
  group by stay_id,subject_id,hadm_id,charttime 
  order by stay_id,subject_id,hadm_id,charttime;



select * from getAllLabvalues limit 10;