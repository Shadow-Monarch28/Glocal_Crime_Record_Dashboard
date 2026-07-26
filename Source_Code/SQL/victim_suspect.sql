-- VERIFYING THE TOTAL ROWS
SELECT COUNT(*) AS total_rows FROM victim_suspect_fact;

-- Checking the Datatype of the Columns
describe victim_suspect_fact;

-- Counting depulicate crime_id
SELECT COUNT(*) FROM (
  SELECT crime_id FROM victim_suspect_fact GROUP BY crime_id HAVING COUNT(*) > 1
) x;

-- CHecking for the Null Values
SELECT
  SUM(victim_count IS NULL) AS null_victim,
  SUM(victim_count < 0) AS negative_victim,
  SUM(suspect_count IS NULL) AS null_suspect,
  SUM(suspect_count < 0) AS negative_suspect,
  SUM(arrested_flag IS NULL) AS null_arrested,
  SUM(weapon_used IS NULL) AS null_weapon
FROM victim_suspect_fact;

-- Standardisation Check of Arrested_flag and Weapon_used column
SELECT DISTINCT arrested_flag FROM victim_suspect_fact;
SELECT DISTINCT weapon_used FROM victim_suspect_fact;

-- Min and Max of Victim_count and Suspect_count
SELECT MIN(victim_count), MAX(victim_count) FROM victim_suspect_fact;
SELECT MIN(suspect_count), MAX(suspect_count) FROM victim_suspect_fact;

/* Sanitisation of Victim_suspect_fact Table */

-- Creating Clean Victim_suspect_fact Table
CREATE TABLE victim_suspect_fact_clean AS
SELECT crime_id, victim_count, suspect_count, arrested_flag, weapon_used
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY crime_id ORDER BY crime_id) AS rn
  FROM victim_suspect_fact
) t
WHERE rn = 1;

-- Checking the total rows 
SELECT COUNT(*) FROM victim_suspect_fact_clean;  -- expect 950,000

-- STANDARDISATION PART
UPDATE victim_suspect_fact_clean
SET arrested_flag = CASE
    WHEN arrested_flag IN ('Yes','y','1') THEN 'Yes'
    WHEN arrested_flag IN ('No','N','0') THEN 'No'
    ELSE arrested_flag
END;

-- Verifying the changes
SELECT DISTINCT arrested_flag FROM victim_suspect_fact_clean;

-- Adding new Colummn to Fix the negative values in Victim_count
ALTER TABLE victim_suspect_fact_clean ADD COLUMN invalid_victim_count_flag TINYINT DEFAULT 0;

UPDATE victim_suspect_fact_clean
SET invalid_victim_count_flag = CASE WHEN victim_count < 0 THEN 1 ELSE 0 END,
    victim_count = CASE WHEN victim_count < 0 THEN NULL ELSE victim_count 
END;

SELECT MIN(victim_count), MAX(victim_count) FROM victim_suspect_fact_clean;
SELECT invalid_victim_count_flag, COUNT(*) FROM victim_suspect_fact_clean GROUP BY invalid_victim_count_flag;

/* 
==================================
SANITY CHECK
===================================
*/

SELECT COUNT(*) AS total_rows FROM victim_suspect_fact_clean;
-- OUTPUT: 950000

SELECT crime_id, COUNT(*) FROM victim_suspect_fact_clean GROUP BY crime_id HAVING COUNT(*) > 1;  -- expect 0 rows
-- OUTPUT: 0

SELECT
  SUM(victim_count IS NULL) AS null_victim,
  SUM(suspect_count IS NULL) AS null_suspect,
  SUM(arrested_flag IS NULL) AS null_arrested,
  SUM(weapon_used IS NULL) AS null_weapon
FROM victim_suspect_fact_clean;

SELECT MIN(suspect_count), MAX(suspect_count) FROM victim_suspect_fact_clean; -- OUTPUT: Min: 0, Max: 20

SELECT DISTINCT weapon_used FROM victim_suspect_fact_clean; 

/*
Fixing the Null values that were explicitly excluded
*/

-- Adding INDEX to avoid the Run Time error while update the values with JOIN
ALTER TABLE crime_incident_fact_clean ADD INDEX idx_crime_id (crime_id(10));
ALTER TABLE victim_suspect_fact_clean ADD INDEX idx_crime_id (crime_id(10));

-- Shutting down the Safe Update
SET SQL_SAFE_UPDATES = 0;

-- Creating temp avg. suspect table to update the nulls
CREATE TABLE tmp_avg_suspect AS
SELECT ci.crime_type, AVG(vs.suspect_count) AS avg_suspect
FROM victim_suspect_fact_clean vs
JOIN crime_incident_fact_clean ci ON vs.crime_id = ci.crime_id
WHERE vs.suspect_count IS NOT NULL
GROUP BY ci.crime_type;

-- Updating the clean table
UPDATE victim_suspect_fact_clean vs
JOIN crime_incident_fact_clean ci ON vs.crime_id = ci.crime_id
JOIN tmp_avg_suspect t ON ci.crime_type = t.crime_type
SET vs.suspect_count = ROUND(t.avg_suspect, 0),
    vs.suspect_count_imputed_flag = 1
WHERE vs.suspect_count IS NULL;

-- Drop  the Temp Table
DROP TABLE tmp_avg_suspect;

-- Turning on the Safe Update
SET SQL_SAFE_UPDATES = 1;

-- Sanity Check of the action
SELECT SUM(suspect_count IS NULL) FROM victim_suspect_fact_clean; 
-- OUTCOME: 0

SELECT suspect_count_imputed_flag, COUNT(*) FROM victim_suspect_fact_clean GROUP BY suspect_count_imputed_flag; 
-- OUTCOME: 1-> 912000, 0 -> 38000