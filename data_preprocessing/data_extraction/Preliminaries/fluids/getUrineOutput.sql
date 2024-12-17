-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getUrineOutput.sql
-- Modifications were made when needed for performance improvement, readability or simplification.



 DROP table IF EXISTS `getUrineOutput`;
CREATE table `getUrineOutput` AS
select
  subject_id , hadm_id , stay_id, charttime, sum(UrineOutput) as UrineOutput
from
(select oe.subject_id , oe.hadm_id , oe.stay_id, oe.charttime
  , case
      when oe.itemid = 227488 and oe.value > 0 then -1*oe.value else oe.value
    end as UrineOutput
  from `outputevents` oe
  where  itemid in
  (
  -- these are the most frequently occurring urine output observations
  226559, -- "Foley"
  226560, -- "Void"
  226561, -- "Condom Cath"
  226584, -- "Ileoconduit"
  226563, -- "Suprapubic"
  226564, -- "R Nephrostomy"
  226565, -- "L Nephrostomy"
  226567, -- "Straight Cath"
  226557, -- R Ureteral Stent
  226558, -- L Ureteral Stent
  227488, -- GU Irrigant Volume In
  227489  -- GU Irrigant/Urine Volume Out
  )
) t1
group by t1.subject_id, t1.hadm_id , t1.stay_id, t1.charttime
order by t1.subject_id, t1.hadm_id , t1.stay_id, t1.charttime;
