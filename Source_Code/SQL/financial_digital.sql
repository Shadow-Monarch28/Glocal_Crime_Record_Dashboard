SELECT COUNT(*) AS total_rows FROM financial_digital_fact;
-- Outcome: 973750 rows

SELECT COUNT(*) FROM (
  SELECT crime_id FROM financial_digital_fact GROUP BY crime_id HAVING COUNT(*) > 1
) x;
-- OUTCOME: 23455 rows

SELECT
  MIN(financial_loss_usd), MAX(financial_loss_usd),
  SUM(financial_loss_usd IS NULL) AS null_loss,
  SUM(financial_loss_usd = -500) AS neg_outlier,
  SUM(financial_loss_usd = 999999999) AS extreme_outlier
FROM financial_digital_fact;
-- OUTCOME: -500	999999999	29015	4869	1954

SELECT digital_crime_flag, COUNT(*) FROM financial_digital_fact GROUP BY digital_crime_flag;
-- OUTCOME: 
/* 
No	450927
Yes	522823
*/

SELECT cross_border_flag, COUNT(*) FROM financial_digital_fact GROUP BY cross_border_flag;
-- OUTCOME:
/*
No	763856
Yes	209894
*/

/*
===================================================
CLEANING PHASE
===================================================
*/

-- Deduplication
CREATE TABLE financial_digital_fact_clean AS
SELECT crime_id, financial_loss_usd, digital_crime_flag, cross_border_flag
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY crime_id ORDER BY crime_id) AS rn
  FROM financial_digital_fact
) t
WHERE rn = 1;

-- Counting the Rows of Clean Table
SELECT COUNT(*) FROM financial_digital_fact_clean;  -- expect 950,000
-- 950000 Rows

--  Fix financial_loss_usd outliers

-- Adding a New Column to Flag nulls and update the invalid data, Total rows affected 6640 rows
ALTER TABLE financial_digital_fact_clean ADD COLUMN invalid_loss_flag TINYINT DEFAULT 0;

UPDATE financial_digital_fact_clean
SET invalid_loss_flag = CASE WHEN financial_loss_usd IN (-500, 999999999) THEN 1 ELSE 0 END,
    financial_loss_usd = CASE WHEN financial_loss_usd IN (-500, 999999999) THEN NULL ELSE financial_loss_usd 
END;

-- Sanity check of Min & Max of Financial loss column
SELECT MIN(financial_loss_usd), MAX(financial_loss_usd) FROM financial_digital_fact_clean;
SELECT invalid_loss_flag, COUNT(*) FROM financial_digital_fact_clean GROUP BY invalid_loss_flag;


/*
===================================================
Sanity Check PHASE
===================================================
*/

SELECT COUNT(*) FROM financial_digital_fact_clean;  
-- Result: 950000 rows

SELECT crime_id, COUNT(*) FROM financial_digital_fact_clean GROUP BY crime_id HAVING COUNT(*) > 1;
-- Result: 0 rows returned

SELECT SUM(financial_loss_usd IS NULL) AS null_loss FROM financial_digital_fact_clean;
-- Result: 34939 rows Returned

SELECT digital_crime_flag, COUNT(*) FROM financial_digital_fact_clean GROUP BY digital_crime_flag;
-- Result:
	/*
    No	439944
	Yes	510056
    */
SELECT cross_border_flag, COUNT(*) FROM financial_digital_fact_clean GROUP BY cross_border_flag;
-- Result:
	/*
    No	745278
	Yes	204722
    */
    
/*
==================================
Checking the Dimensional Tables at the End to make sure FK is actually linked or not
==================================
*/

SELECT COUNT(*) FROM crime_incident_fact_clean a
JOIN victim_suspect_fact_clean b ON a.crime_id = b.crime_id
JOIN case_resolution_fact_clean c ON a.crime_id = c.crime_id
JOIN financial_digital_fact_clean d ON a.crime_id = d.crime_id;

-- Output: 950000 rows (Met the Expectation)

/*
Fixing the Null values that were explicitly excluded
*/

ALTER TABLE victim_suspect_fact_clean ADD COLUMN weapon_used_imputed_flag TINYINT DEFAULT 0;

UPDATE victim_suspect_fact_clean
SET weapon_used = 'Unknown', weapon_used_imputed_flag = 1
WHERE weapon_used IS NULL;

SELECT DISTINCT weapon_used FROM victim_suspect_fact_clean; -- Output: 6 rows (No Null Spoted)

SELECT weapon_used_imputed_flag, COUNT(*) FROM victim_suspect_fact_clean GROUP BY weapon_used_imputed_flag;
 /* OUTPUT:
	0	902500
	1	47500
 */
 
 /*
 Nulls handling (Second Phase)
 */
ALTER TABLE financial_digital_fact_clean ADD INDEX idx_crime_id (crime_id(10));
 
 CREATE TABLE tmp_avg_loss AS
SELECT c.crime_status, AVG(f.financial_loss_usd) AS avg_loss
FROM financial_digital_fact_clean f
JOIN case_resolution_fact_clean c ON f.crime_id = c.crime_id
WHERE f.financial_loss_usd IS NOT NULL
GROUP BY c.crime_status;

ALTER TABLE financial_digital_fact_clean ADD COLUMN financial_loss_imputed_flag TINYINT DEFAULT 0;

UPDATE financial_digital_fact_clean f
JOIN case_resolution_fact_clean c ON f.crime_id = c.crime_id
JOIN tmp_avg_loss t ON c.crime_status = t.crime_status
SET f.financial_loss_usd = ROUND(t.avg_loss, 2),
    f.financial_loss_imputed_flag = 1
WHERE f.financial_loss_usd IS NULL;

DROP TABLE tmp_avg_loss;

/*
do same that we did yesrerday and trasferred to her
*/
SELECT MIN(financial_loss_usd), MAX(financial_loss_usd), AVG(financial_loss_usd) FROM financial_digital_fact_clean;
SELECT financial_loss_imputed_flag, COUNT(*) FROM financial_digital_fact_clean GROUP BY financial_loss_imputed_flag;


-- confirm no unexpected nulls remain anywhere except case_duration_days
SELECT SUM(weapon_used IS NULL) AS wu, SUM(victim_count IS NULL) AS vc, SUM(suspect_count IS NULL) AS sc
FROM victim_suspect_fact_clean;

SELECT SUM(crime_status IS NULL) AS cs, SUM(case_duration_days IS NULL) AS cd
FROM case_resolution_fact_clean;

SELECT SUM(financial_loss_usd IS NULL) AS fl
FROM financial_digital_fact_clean;

-- re-verify join integrity still holds at 950,000 after all these updates
SELECT COUNT(*) FROM crime_incident_fact_clean a
JOIN victim_suspect_fact_clean b ON a.crime_id = b.crime_id
JOIN case_resolution_fact_clean c ON a.crime_id = c.crime_id
JOIN financial_digital_fact_clean d ON a.crime_id = d.crime_id;