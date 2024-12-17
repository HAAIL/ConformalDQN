-- Initial code was retrieved from https://github.com/arnepeine/ventai/blob/main/getVentilationParams.sql 
-- https://github.com/arnepeine/ventai/blob/main/vent_parameters.sql 
-- and https://github.com/MIT-LCP/mimic-code/blob/1754d925ba4e96e376dc29858e8df301fcb69a20/concepts/durations/ventilation-durations.sql
-- Modifications were made when needed for performance improvement, readability or simplification.

SET GLOBAL innodb_buffer_pool_size = 214748364800;


select * from d_items where itemid in (223848,223849) or abbreviation like '%pcv%' or label like '%relief%';
select * from d_items where label like '%Plateau%';

select * from chartevents where itemid in(224419,224750,227187) limit 10;


DROP table IF EXISTS `data_` ;
CREATE table `data_` as(
select
  ce.stay_id, ce.subject_id, ce.hadm_id, ce.charttime
    , (case when itemid in (60,437,505,506,686,220339,224700) THEN valuenum else null end) as PEEP --  PEEP
	, (case when itemid in (639, 654, 681, 682, 683, 684,224685,224684,224686) THEN valuenum else null end) as tidal_volume --  tidal volume
	, (case when itemid in (224696) THEN valuenum else null end) as plateau_pressure --  PlateauPressure  
	FROM `chartevents` ce WHERE ce.value is not null  AND ce.itemid in
	(60,437,505,506,686,220339,224700, --  PEEP
	 639, 654, 681, 682, 683, 684,224685,224684,224686, --  tidal volume
	 224696 --  PlateauPressure
	));

CREATE INDEX data_index_charttime
ON data_ (charttime);

CREATE INDEX data_index_stay_id
ON data_ (stay_id);

CREATE INDEX data_index_stay_id_charttime
ON data_ (stay_id,charttime);

DROP table IF EXISTS `ce_vent_param` ;
CREATE table `ce_vent_param` as(
 select ce.SUBJECT_ID, ce.HADM_ID, ce.stay_id, ce.CHARTTIME,ce.itemid,data_.tidal_volume,data_.plateau_pressure,data_.PEEP,ce.valuenum,ce.value
   from `chartevents` ce 
  LEFT JOIN data_ ON (data_.stay_id = ce.stay_id) AND (data_.charttime = ce.charttime)
  where ce.value is not null 

);
CREATE INDEX ce_vent_param_index_subject_id_hadm_id_stay_id_charttime
ON ce_vent_param(subject_id, hadm_id, stay_id, charttime);

DROP table IF EXISTS `getAllVentilationParams` ;
CREATE table `getAllVentilationParams` as


select SUBJECT_ID, HADM_ID, stay_id, CHARTTIME
--  STEP 2: Get the FiO2
    , max(
        case
          when itemid in (223835,223769,223770)
            then case
              when valuenum > 0 and valuenum <= 1 then valuenum * 100
              when valuenum > 1 and valuenum < 21 then null --  improperly input data - looks like O2 flow in litres
              when valuenum >= 21 and valuenum <= 100 then valuenum
              else null end
        when itemid in (3420, 3422) then valuenum
        when itemid = 190 and valuenum > 0.20 and valuenum < 1 then valuenum * 100
      else null end
    ) as fio2_chartevents
--  STEP 3: Get mechanical ventilation
  , max(
    case
       when itemid is null or value is null then 0 --  can't have null values
      when itemid = 720 and value != 'Other/Remarks' THEN 1  --  VentTypeRecorded
      when itemid = 223848 and value != 'Other' THEN 1
      when itemid = 223849 then 1 --  ventilator mode
      when itemid = 467 and value = 'Ventilator' THEN 1 --  O2 delivery device == ventilator
      when itemid in
        (
        445, 448, 449, 450, 1340, 1486, 1600, 224687 --  minute volume
        , 639, 654, 681, 682, 683, 684,224685,224684,224686 --  tidal volume
        , 218,436,535,444,459,224697,224695,224696,224746,224747 --  High/Low/Peak/Mean/Neg insp force ("RespPressure")
        , 221,1,1211,1655,2000,226873,224738,224419,224750,227187 --  Insp pressure
        , 224696 --  PlateauPressure
        , 5865,5866,224707,224709,224705,224706 --  APRV pressure
        , 60,437,505,506,686,220339,224700 --  PEEP
        , 3459 --  high pressure relief
        , 501,502,503,224702 --  PCV
        , 223,667,668,669,670,671,672 --  TCPCV
        , 224701 --  PSVlevel
        )
        THEN 1
      else 0
    end
    ) as MechVent,
    avg(PEEP) as PEEP, avg(tidal_volume) as tidal_volume, avg(plateau_pressure) as plateau_pressure

  from ce_vent_param
  group by subject_id, hadm_id, stay_id, charttime
  ORDER BY subject_id, hadm_id, stay_id, charttime;




select * from ce_vent_param   limit 10;
 


