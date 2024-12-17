-- Initial code was retrieved from https://github.com/MIT-LCP/mimic-code/blob/1754d925ba4e96e376dc29858e8df301fcb69a20/concepts/durations/weight-durations.sql
-- Modifications were made when needed for performance improvement, readability or simplification.

-- This query extracts weights for adult ICU patients with start/stop times
-- if an admission weight is given, then this is assigned from intime to outtime

DROP table IF EXISTS `weightdurations`;
CREATE table `weightdurations`as




with wt_stg as
(
    SELECT
        c.stay_id, c.charttime
      , case when c.itemid in (226512,226531) then 'admit'
          else 'daily' end as weight_type
      , case when c.itemid in (226531) then c.valuenum * 0.453592
       else c.valuenum 
       end as weight
    FROM `chartevents` c
    WHERE c.valuenum IS NOT NULL
      AND c.itemid in
      (
         762,226512 -- Admit Wt
         ,226531 -- Admit Wt lbs
        ,763,224639 -- Daily Weight
      )
      AND c.valuenum != 0
      -- exclude rows marked as error
      --  AND c.warning != 1
)
-- assign ascending row number
, wt_stg1 as
(
  select
      stay_id
    , charttime
    , weight_type
    , weight
    , ROW_NUMBER() OVER (partition by stay_id, weight_type order by charttime) as rn
  from wt_stg
)
-- change charttime to starttime - for admit weight, we use ICU admission time
, wt_stg2 as
(
  select
      wt_stg1.stay_id
    , ie.intime, ie.outtime
    , case when wt_stg1.weight_type = 'admit' and wt_stg1.rn = 1
        then ie.intime - interval '2' hour
      else wt_stg1.charttime end as starttime
    , wt_stg1.weight
  from `icustays` ie
  inner join wt_stg1
    on ie.stay_id = wt_stg1.stay_id
  where not (weight_type = 'admit' and rn = 1)
)
, wt_stg3 as
(
  select
    stay_id
    , starttime
    , coalesce(
        LEAD(starttime) OVER (PARTITION BY stay_id ORDER BY starttime),
        outtime + interval '2' hour
      ) as endtime
    , weight
  from wt_stg2
)
-- this table is the start/stop times from admit/daily weight in charted data
, wt1 as
(
  select
      ie.stay_id
    , wt.starttime
    , case when wt.stay_id is null then null
      else
        coalesce(wt.endtime,
        LEAD(wt.starttime) OVER (partition by ie.stay_id order by wt.starttime),
          -- we add a 2 hour "fuzziness" window
        ie.outtime + interval '2' hour)
      end as endtime
    , wt.weight
  from `icustays` ie
  left join wt_stg3 wt
    on ie.stay_id = wt.stay_id
)
-- if the intime for the patient is < the first charted daily weight
-- then we will have a "gap" at the start of their stay
-- to prevent this, we look for these gaps and backfill the first weight
, wt_fix as
(
  select ie.stay_id
    -- we add a 2 hour "fuzziness" window
    , ie.intime - interval '2' hour as starttime
    , wt.starttime as endtime
    , wt.weight
  from `icustays` ie
  inner join
  -- the below subquery returns one row for each unique stay_id
  -- the row contains: the first starttime and the corresponding weight
  (
    select wt1.stay_id, wt1.starttime, wt1.weight
    from wt1
    inner join
      (
        select stay_id, min(Starttime) as starttime
        from wt1
        group by stay_id
      ) wt2
    on wt1.stay_id = wt2.stay_id
    and wt1.starttime = wt2.starttime
  ) wt
    on ie.stay_id = wt.stay_id
    and ie.intime < wt.starttime
)
, wt2 as
(
  select
      wt1.stay_id
    , wt1.starttime
    , wt1.endtime
    , wt1.weight
  from wt1
  UNION ALL
  SELECT
      wt_fix.stay_id
    , wt_fix.starttime
    , wt_fix.endtime
    , wt_fix.weight
  from wt_fix
)

select
  wt2.stay_id, wt2.starttime, wt2.endtime, wt2.weight
from wt2
order by stay_id, starttime, endtime;


