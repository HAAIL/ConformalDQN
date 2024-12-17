-- Initial code was retrieved from https://github.com/MIT-LCP/mimic-code/blob/1754d925ba4e96e376dc29858e8df301fcb69a20/concepts/durations/vasopressin-dose.sql
-- Modifications were made when needed for performance improvement, readability or simplification.

CREATE table `vasopressin_dose` as
with vasomv as(select stay_id, linkorderid, max(rate) as vaso_rate, sum(amount) as vaso_amount, min(starttime) as starttime, max(endtime) as endtime
  from `inputevents` where itemid = 222315 -- vasopressin 
  and statusdescription != 'Rewritten'
  group by stay_id, linkorderid)

SELECT stay_id
  , starttime, endtime
  , vaso_rate, vaso_amount
from vasomv
order by stay_id, starttime;

select * from vasopressin_dose;