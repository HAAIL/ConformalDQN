-- Initial code was retrieved https://github.com/arnepeine/ventai/blob/main/sampled_data_with_scdem_withventparams.sql
-- Modifications were made when needed for performance improvement, readability or simplification.
-- Code was modified to be campatible with MIMIC IV.

-- query script to merge the sampled data with the corresponding scores and demographic information

create index idx_OverallTable2_stay_id on OverallTable2(stay_id);
create index idx_idealbodyweight_stay_id on idealbodyweight(stay_id);
create index idx_getWeight_stay_id on getWeight(stay_id);
create index idx_getMainDemographics_stay_id on getMainDemographics(stay_id);
create index idx_SOFA_stay_id on SOFA(stay_id);
create index idx_SIRS_stay_id on SIRS(stay_id);





DROP table IF EXISTS `OverallTable3`;
CREATE table `OverallTable3` AS

SELECT
		samp.stay_id, ic.subject_id , ic.hadm_id, samp.start_time , dem.first_admit_age,
		dem.gender, weig.weight, ideal.ideal_body_weight_kg, 
        dem.icu_readm, dem.elixhauser_score, sf.sofa , sr.sirs ,
		samp.gcs , samp.heartrate , samp.sysbp, samp.diasbp, samp.meanbp,
		samp.shockindex, samp.resprate, samp.tempc, samp.spo2, samp.potassium,
		samp.sodium, samp.chloride, samp.glucose, samp.bun, samp.creatinine, samp.magnesium,
		samp.calcium, samp.ionizedcalcium, samp.carbondioxide, samp.sgot, samp.sgpt, samp.bilirubin, samp.albumin, samp.hemoglobin,
		samp.wbc, samp.platelet, samp.ptt, samp.pt, samp.inr, samp.ph, samp.pao2, samp.paco2, samp.base_excess,
		samp.bicarbonate, samp.lactate, samp.pao2fio2ratio, samp.mechvent, samp.fio2, samp.urineoutput,
		samp.vaso_total, samp.iv_total, samp.cum_fluid_balance, samp.peep, 
        samp.tidal_volume, (samp.tidal_volume/ideal.ideal_body_weight_kg) as adjusted_tidal_volume,
        samp.plateau_pressure, dem.hospmort90day, dem.dischtime, dem.deathtime

FROM `OverallTable2` samp

LEFT JOIN `SIRS` sr
ON samp.stay_id=sr.stay_id AND samp.start_time=sr.start_time

LEFT JOIN `SOFA` sf
ON samp.stay_id=sf.stay_id AND samp.start_time=sf.start_time

LEFT JOIN `getMainDemographics` dem
ON samp.stay_id=dem.stay_id 

LEFT JOIN `getWeight` weig
ON samp.stay_id=weig.stay_id

LEFT JOIN `idealbodyweight` ideal
ON samp.stay_id=ideal.stay_id

INNER JOIN `icustays` ic
ON samp.stay_id=ic.stay_id

ORDER BY samp.stay_id, samp.subject_id, samp.hadm_id, samp.start_time;
