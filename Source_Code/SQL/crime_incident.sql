
-- 1. Distinct dirty values to standardize
SELECT DISTINCT country FROM crime_incident_fact ORDER BY country;
-- Output: 14 rowa

SELECT DISTINCT crime_type FROM crime_incident_fact ORDER BY crime_type;
-- Output: 165 rowa

SELECT DISTINCT crime_severity FROM crime_incident_fact ORDER BY crime_severity;
-- Output: 6 rows

-- 2. Date format spread (sample)
SELECT incident_date FROM crime_incident_fact ORDER BY RAND() LIMIT 20;
-- Output: 20 rows

-- 3. Year mismatch scale (incident_year vs actual parsed year — flag for later)
SELECT COUNT(*) AS total_rows FROM crime_incident_fact;
-- Output: 973750 rows

-- 4. Severity score outliers
SELECT severity_score, COUNT(*) FROM crime_incident_fact 
WHERE severity_score IN (0, 11) 
GROUP BY severity_score;
-- Output: 11 is 2414 and 9 is 2452

-- 5. Duplicate crime_id count
SELECT COUNT(*) AS duplicate_ids FROM (
  SELECT crime_id FROM crime_incident_fact GROUP BY crime_id HAVING COUNT(*) > 1
) x;
-- Output: 23471 rows


-- ================================================================
-- Cleaning Phase
-- ================================================================

CREATE TABLE crime_incident_fact_clean AS
SELECT DISTINCT * FROM crime_incident_fact;

SELECT COUNT(*) FROM crime_incident_fact_clean;  -- should drop ~23,750 rows back to ~950,000
-- OUTPUT: Affected rows 950000

ALTER TABLE crime_incident_fact_clean ADD COLUMN incident_date_parsed DATE;

/* Parse dates into a proper DATE column */
UPDATE crime_incident_fact_clean
SET incident_date_parsed =
  CASE
    WHEN incident_date LIKE '%-%' THEN STR_TO_DATE(incident_date, '%m-%d-%Y')
    WHEN LENGTH(SUBSTRING_INDEX(incident_date, '/', 1)) = 4 THEN STR_TO_DATE(incident_date, '%Y/%m/%d')
    ELSE STR_TO_DATE(incident_date, '%d/%m/%Y')
  END;
  
  SELECT incident_date, incident_date_parsed FROM crime_incident_fact_clean ORDER BY RAND() LIMIT 10;
  
  ALTER TABLE crime_incident_fact_clean ADD COLUMN year_mismatch_flag TINYINT DEFAULT 0;

/* Replace year/month/day with parsed values, flag mismatches */
UPDATE crime_incident_fact_clean
SET year_mismatch_flag = CASE WHEN incident_year <> YEAR(incident_date_parsed) THEN 1 ELSE 0 END,
    incident_year = YEAR(incident_date_parsed),
    incident_month = MONTH(incident_date_parsed),
    incident_day = DAY(incident_date_parsed);

/* Standardize country*/
    
UPDATE crime_incident_fact_clean
SET country = CASE
    WHEN TRIM(UPPER(country)) IN ('CANADA') THEN 'Canada'
    WHEN TRIM(UPPER(country)) IN ('CHINA') THEN 'China'
    WHEN TRIM(UPPER(country)) IN ('GERMANY') THEN 'Germany'
    WHEN TRIM(UPPER(country)) IN ('INDIA') THEN 'India'
    WHEN TRIM(UPPER(country)) IN ('JAPAN') THEN 'Japan'
    WHEN TRIM(UPPER(country)) IN ('RUSSIA') THEN 'Russia'
    WHEN TRIM(UPPER(country)) IN ('USA','U.S.A','U.S.A.') THEN 'USA'
    ELSE TRIM(country)
END;

/* crime_type standardization */
UPDATE crime_incident_fact_clean
SET crime_type = CASE
    WHEN crime_type IN ('Amred Robbery','Aremd Robbery','Armde Robbery','Arme dRobbery','Armed oRbbery','Armed Rbobery','Armed Robbery','Armed Robbeyr','Armed Robbrey','Armed Robebry','ArmedR obbery') THEN 'Armed Robbery'
    WHEN crime_type IN ('Caiptal Flight','Capiatl Flight','Capita lFlight','Capital Filght','Capital Flgiht','Capital Flight','Capital Fligth','Capital Flihgt','Capital lFight','CapitalF light','Capitla Flight','Captial Flight','Cpaital Flight') THEN 'Capital Flight'
    WHEN crime_type IN ('Coprorate Espionage','Coroprate Espionage','Corpoarte Espionage','Corporaet Espionage','Corporat eEspionage','Corporate Epsionage','Corporate Esiponage','Corporate Espinoage','Corporate Espioange','Corporate Espionaeg','Corporate Espionage','Corporate Espiongae','Corporate Espoinage','Corporate sEpionage','CorporateE spionage','Corportae Espionage','Corproate Espionage','Croporate Espionage') THEN 'Corporate Espionage'
    WHEN crime_type IN ('Crurency Counterfeiting','Curerncy Counterfeiting','Currecny Counterfeiting','Currenc yCounterfeiting','Currency Conuterfeiting','Currency Counetrfeiting','Currency Countefreiting','Currency Counterefiting','Currency Counterfeiitng','Currency Counterfeitign','Currency Counterfeiting','Currency Counterfeitnig','Currency Counterfetiing','Currency Counterfieting','Currency Countrefeiting','Currency Coutnerfeiting','Currency Cuonterfeiting','Currency oCunterfeiting','CurrencyC ounterfeiting','Currenyc Counterfeiting','Currnecy Counterfeiting') THEN 'Currency Counterfeiting'
    WHEN crime_type IN ('Cbyer Warfare','Cybe rWarfare','Cyber aWrfare','Cyber Wafrare','Cyber Warafre','Cyber Warfaer','Cyber Warfare','Cyber Warfrae','Cyber Wrafare','CyberW arfare','Cybre Warfare','Cyebr Warfare') THEN 'Cyber Warfare'
    WHEN crime_type IN ('Drgu Trafficking','Dru gTrafficking','Drug rTafficking','Drug Tarfficking','Drug Traffciking','Drug Trafficikng','Drug Traffickign','Drug Trafficking','Drug Trafficknig','Drug Traffikcing','Drug Trafifcking','Drug Trfaficking','DrugT rafficking','Durg Trafficking') THEN 'Drug Trafficking'
    WHEN crime_type IN ('Ebmezzlement','Embezlzement','Embezzelment','Embezzleemnt','Embezzlement','Embezzlemetn','Embezzlemnet','Embezzlmeent','Embzezlement','Emebzzlement') THEN 'Embezzlement'
    WHEN crime_type IN ('Focrible Abduction','Forcbile Abduction','Forcibel Abduction','Forcibl eAbduction','Forcible Abdcution','Forcible Abduciton','Forcible Abductino','Forcible Abduction','Forcible Abductoin','Forcible Abdutcion','Forcible Abudction','Forcible Adbuction','Forcible bAduction','ForcibleA bduction','Forcilbe Abduction','Foricble Abduction','Frocible Abduction') THEN 'Forcible Abduction'
    WHEN crime_type IN ('Inetntional Homicide','Intenitonal Homicide','Intentinoal Homicide','Intentioanl Homicide','Intentiona lHomicide','Intentional Hmoicide','Intentional Hoimcide','Intentional Homciide','Intentional Homicdie','Intentional Homicide','Intentional Homicied','Intentional Homiicde','Intentional oHmicide','IntentionalH omicide','Intentionla Homicide','Intentoinal Homicide','Intetnional Homicide','Intnetional Homicide','Itnentional Homicide') THEN 'Intentional Homicide'
    WHEN crime_type IN ('Manlsaughter','Mansalughter','Manslaguhter','Manslaughetr','Manslaughter','Manslaughtre','Manslaugther','Manslauhgter','Mansluaghter','Masnlaughter','Mnaslaughter') THEN 'Manslaughter'
    WHEN crime_type IN ('Ranosmware Extortion','Ransmoware Extortion','Ransomawre Extortion','Ransomwaer Extortion','Ransomwar eExtortion','Ransomware Etxortion','Ransomware Exotrtion','Ransomware Extoriton','Ransomware Extortino','Ransomware Extortion','Ransomware Extortoin','Ransomware Extotrion','Ransomware Extrotion','Ransomware xEtortion','RansomwareE xtortion','Ransomwrae Extortion','Ransowmare Extortion','Rasnomware Extortion','Rnasomware Extortion') THEN 'Ransomware Extortion'
    ELSE crime_type
END;

-- Standardize crime_severity + fix severity_score outliers
UPDATE crime_incident_fact_clean
SET crime_severity = CASE
    WHEN UPPER(TRIM(crime_severity)) IN ('CRITICAL','CRTICAL') THEN 'Critical'
    WHEN UPPER(TRIM(crime_severity)) IN ('HIGH') THEN 'High'
    WHEN UPPER(TRIM(crime_severity)) IN ('MEDIUM','MED') THEN 'Medium'
    WHEN UPPER(TRIM(crime_severity)) IN ('LOW') THEN 'Low'
    ELSE crime_severity
END;

ALTER TABLE crime_incident_fact_clean ADD COLUMN severity_score_outlier_flag TINYINT DEFAULT 0;

UPDATE crime_incident_fact_clean
SET severity_score_outlier_flag = CASE WHEN severity_score IN (0, 11) THEN 1 ELSE 0 END,
    severity_score = 
    CASE WHEN severity_score = 0 THEN 1
    WHEN severity_score = 11 THEN 10
    ELSE severity_score 
END;

-- Drop the now-redundant raw text date column, keep the parsed one                          
ALTER TABLE crime_incident_fact_clean DROP COLUMN incident_date;
ALTER TABLE crime_incident_fact_clean CHANGE incident_date_parsed incident_date DATE;

select count(severity_score_outlier_flag) from crime_incident_fact_clean;


/* SANITY CHECK */

-- Row count & structure --
SELECT COUNT(*) AS total_rows FROM crime_incident_fact_clean;  -- expect 950,000
DESCRIBE crime_incident_fact_clean;

/* Null check */
SELECT
  SUM(crime_id IS NULL) AS null_crime_id,
  SUM(incident_date IS NULL) AS null_incident_date,
  SUM(incident_year IS NULL) AS null_incident_year,
  SUM(incident_month IS NULL) AS null_incident_month,
  SUM(incident_day IS NULL) AS null_incident_day,
  SUM(country IS NULL) AS null_country,
  SUM(city IS NULL) AS null_city,
  SUM(region_code IS NULL) AS null_region_code,
  SUM(latitude IS NULL) AS null_latitude,
  SUM(longitude IS NULL) AS null_longitude,
  SUM(crime_type IS NULL) AS null_crime_type,
  SUM(crime_severity IS NULL) AS null_crime_severity,
  SUM(severity_score IS NULL) AS null_severity_score,
  SUM(year_mismatch_flag IS NULL) AS null_year_mismatch_flag,
  SUM(severity_score_outlier_flag IS NULL) AS null_outlier_flag
FROM crime_incident_fact_clean;

-- Standardization check — should return exactly 7 / 11 / 4 clean values
SELECT DISTINCT country FROM crime_incident_fact_clean ORDER BY country;
SELECT DISTINCT crime_type FROM crime_incident_fact_clean ORDER BY crime_type;
SELECT DISTINCT crime_severity FROM crime_incident_fact_clean ORDER BY crime_severity;

-- Date range & any parse failures
SELECT MIN(incident_date), MAX(incident_date) FROM crime_incident_fact_clean;

-- rows where parsing failed (should be 0)
SELECT COUNT(*) FROM crime_incident_fact_clean WHERE incident_date IS NULL;

-- Outlier / flag counts (for your data-quality talking points)
SELECT severity_score, COUNT(*) FROM crime_incident_fact_clean GROUP BY severity_score ORDER BY severity_score;
SELECT year_mismatch_flag, COUNT(*) FROM crime_incident_fact_clean GROUP BY year_mismatch_flag;
SELECT severity_score_outlier_flag, COUNT(*) FROM crime_incident_fact_clean GROUP BY severity_score_outlier_flag;

-- Duplicate check (should be 0 now)
SELECT crime_id, COUNT(*) FROM crime_incident_fact_clean GROUP BY crime_id HAVING COUNT(*) > 1;


/*
Fixing the Null values that were explicitly excluded
*/

