-- Total Row Count
SELECT COUNT(*) AS total_rows FROM case_resolution_fact;

-- Counting the Duplicates
SELECT COUNT(*) FROM (
  SELECT crime_id FROM case_resolution_fact GROUP BY crime_id HAVING COUNT(*) > 1
) x;

-- checking the columns with Null Values
SELECT
  SUM(crime_status IS NULL) AS null_status,
  SUM(case_duration_days IS NULL) AS null_duration,
  SUM(case_duration_days < 0) AS negative_duration,
  SUM(reporting_agency IS NULL) AS null_agency,
  SUM(data_source IS NULL) AS null_source
FROM case_resolution_fact;

-- Sanitisation Check of Crime_status, data_source, Min and Max of case_duration
SELECT DISTINCT crime_status FROM case_resolution_fact;
SELECT DISTINCT data_source FROM case_resolution_fact;
SELECT MIN(case_duration_days), MAX(case_duration_days) FROM case_resolution_fact;

/* Cleaning of the SQL Table */

-- Creating the Cleaner Table of Case_resolution_fact

CREATE TABLE case_resolution_fact_clean AS
SELECT crime_id, crime_status, case_duration_days, reporting_agency, data_source
FROM (
  SELECT *, ROW_NUMBER() OVER (PARTITION BY crime_id ORDER BY crime_id) AS rn
  FROM case_resolution_fact
) t
WHERE rn = 1;

-- Checking the Total Row Count of the cleaned tables
SELECT COUNT(*) FROM case_resolution_fact_clean;  -- expect 950,000

-- Standardisation of Data_source
UPDATE case_resolution_fact_clean
SET data_source = CASE
    WHEN data_source IN ('NationalCrimeDB_v2','NationalCrimeDB_V2') THEN 'NationalCrimeDB_v2'
    WHEN data_source IN ('InterpoolFeed','Interpol_Feed') THEN 'InterpoolFeed'
    WHEN data_source IN ('LocalPD_Report','LocalPD_Reprot') THEN 'LocalPD_Report'
    WHEN data_source IN ('CrimeStat_Sync','crimestat_sync') THEN 'CrimeStat_Sync'
    ELSE data_source
END;

-- Sanity Check for Standardisation of Data_source
SELECT DISTINCT data_source FROM case_resolution_fact_clean;

-- Creating an Alternate Column
ALTER TABLE case_resolution_fact_clean ADD COLUMN invalid_duration_flag TINYINT DEFAULT 0;

UPDATE case_resolution_fact_clean
SET invalid_duration_flag = CASE WHEN case_duration_days < 0 THEN 1 ELSE 0 END,
    case_duration_days = CASE WHEN case_duration_days < 0 THEN NULL ELSE case_duration_days 
END;

-- Sanity Check for Case_duration and Invalid_duration_flag
SELECT MIN(case_duration_days), MAX(case_duration_days) FROM case_resolution_fact_clean;
SELECT invalid_duration_flag, COUNT(*) FROM case_resolution_fact_clean GROUP BY invalid_duration_flag;

-- Checking for the Null values in invalid_duration_flag
SELECT COUNT(*) FROM case_resolution_fact_clean WHERE case_duration_days IS NULL;

SELECT invalid_duration_flag, COUNT(*) 
FROM case_resolution_fact_clean 
GROUP BY invalid_duration_flag;

-- fixing the issue with the two tables
ALTER TABLE case_resolution_fact_clean DROP COLUMN case_duration_days;
ALTER TABLE case_resolution_fact_clean DROP COLUMN invalid_duration_flag;

-- ading the column with correct datatype
ALTER TABLE case_resolution_fact_clean ADD COLUMN case_duration_days DOUBLE;
ALTER TABLE case_resolution_fact_clean ADD COLUMN invalid_duration_flag TINYINT DEFAULT 0;

-- updating the table

/* creating temp table */
CREATE TABLE tmp_duration AS
SELECT crime_id, MIN(case_duration_days) AS case_duration_days
FROM case_resolution_fact
GROUP BY crime_id;

-- adding indexing to the temp table
ALTER TABLE tmp_duration ADD INDEX idx_crime_id (crime_id(10));
ALTER TABLE case_resolution_fact_clean ADD INDEX idx_crime_id (crime_id(10));

-- updaing the clean table
UPDATE case_resolution_fact_clean c
JOIN tmp_duration r ON c.crime_id = r.crime_id
SET c.invalid_duration_flag = CASE WHEN r.case_duration_days < 0 THEN 1 ELSE 0 END,
    c.case_duration_days = CASE WHEN r.case_duration_days < 0 THEN NULL ELSE r.case_duration_days END;

-- Sanity Check 
SELECT MIN(case_duration_days), MAX(case_duration_days) FROM case_resolution_fact_clean;
SELECT invalid_duration_flag, COUNT(*) FROM case_resolution_fact_clean GROUP BY invalid_duration_flag;


/* Final Sanity_CHeck */
SELECT COUNT(*) FROM case_resolution_fact_clean;  -- expect 950,000

SELECT crime_id, COUNT(*) FROM case_resolution_fact_clean GROUP BY crime_id HAVING COUNT(*) > 1;  -- expect 0 rows

SELECT
  SUM(crime_status IS NULL) AS null_status,
  SUM(case_duration_days IS NULL) AS null_duration,
  SUM(reporting_agency IS NULL) AS null_agency,
  SUM(data_source IS NULL) AS null_source
FROM case_resolution_fact_clean;

SELECT DISTINCT crime_status FROM case_resolution_fact_clean;
SELECT DISTINCT data_source FROM case_resolution_fact_clean;

/*
Fixing the Null values that were explicitly excluded
*/

ALTER TABLE case_resolution_fact_clean ADD COLUMN crime_status_imputed_flag TINYINT DEFAULT 0;

UPDATE case_resolution_fact_clean
SET crime_status = 'Unknown', crime_status_imputed_flag = 1
WHERE crime_status IS NULL;

SELECT DISTINCT crime_status FROM case_resolution_fact_clean; -- 5 rows
SELECT crime_status_imputed_flag, COUNT(*) FROM case_resolution_fact_clean GROUP BY crime_status_imputed_flag;
/* Result:
	0	902500
	1	47500
*/

