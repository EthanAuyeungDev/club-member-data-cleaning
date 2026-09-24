-- ============================================================
-- Project  : Club Membership Data Cleaning
-- Layer    : DWD (Data Warehouse Detail)
-- File     : 02_member_info_cleaning_dwd.sql
--
-- Purpose:
--   1. Copy raw data from ODS to DWD
--   2. Identify and eliminate duplicate records to ensure uniqueness
--   3. Clean up extraneous whitespace and invalid characters
--   4. Split or merge values (e.g., full name, full address) for consistency
--   5. Validate that key values (age, dates) fall within expected ranges
--   6. Detect and handle outliers that may skew analysis
--   7. Correct spelling mistakes and input errors in categorical fields
--   8. Handle null or empty values to maintain data completeness
--   9. Validate the cleaned data before publishing
-- ============================================================


USE club_member_dwd;

-- ============================================================
-- Step 1: Copy ODS -> DWD using CTAS
-- ============================================================

DROP TABLE IF EXISTS member_info_dwd;

CREATE TABLE member_info_dwd AS
SELECT 
    member_id,
    
    -- Name field cleanup
	-- Note: In this dataset, special characters only appear in first names,
	-- so they can be removed with a single regex.
    REGEXP_REPLACE(SUBSTRING_INDEX(LOWER(TRIM(full_name)), ' ', 1), '[^a-zA-Z]', '') AS first_name,
    SUBSTRING(LOWER(TRIM(full_name)), LOCATE(' ', TRIM(full_name)) + 1) AS last_name,
    
    -- Some ages were entered with an extra trailing digit.
	-- When a 3-digit age is found, keep only the first 2 digits.
    CASE 
        WHEN LENGTH(age) = 0 THEN NULL
        WHEN LENGTH(age) = 3 THEN SUBSTRING(age, 1, 2)
        ELSE age
    END AS age,
    CASE 
        WHEN LENGTH(martial_status) = 0 THEN NULL 
        ELSE martial_status
    END AS martial_status,
    
    LOWER(TRIM(email)) AS member_email,
    
    CASE 
        WHEN TRIM(phone) = '' THEN NULL 
        WHEN LENGTH(TRIM(phone)) < 11 THEN NULL 
        ELSE TRIM(phone)
    END AS phone,
    
    -- Lowercase, trim, and split the full address into street, city, and state.
    SUBSTRING_INDEX(LOWER(TRIM(full_address)), ',', 1) AS street_address,
    SUBSTRING_INDEX(SUBSTRING_INDEX(LOWER(TRIM(full_address)), ',', 2), ',', -1) AS city,
    SUBSTRING_INDEX(SUBSTRING_INDEX(LOWER(TRIM(full_address)), ',', 3), ',', -1) AS state,
    
    -- Clean job_title into occupation: trim, nullify empties, and convert roman numeral levels to numeric.
    -- Trim and lowercase job_title, then use REGEXP_REPLACE to convert roman numeral levels to numeric descriptors.
    CASE 
        WHEN TRIM(job_title) = '' THEN NULL 
        ELSE 
            CASE 
                WHEN LOWER(TRIM(job_title)) REGEXP ' i$'   THEN REGEXP_REPLACE(LOWER(TRIM(job_title)), ' i$', ', level 1')
                WHEN LOWER(TRIM(job_title)) REGEXP ' ii$'  THEN REGEXP_REPLACE(LOWER(TRIM(job_title)), ' ii$', ', level 2')
                WHEN LOWER(TRIM(job_title)) REGEXP ' iii$' THEN REGEXP_REPLACE(LOWER(TRIM(job_title)), ' iii$', ', level 3')
                WHEN LOWER(TRIM(job_title)) REGEXP ' iv$'  THEN REGEXP_REPLACE(LOWER(TRIM(job_title)), ' iv$', ', level 4')
                ELSE LOWER(TRIM(job_title))
            END
    END AS occupation,
    
    -- A few members show membership_date year in the 1900's.  Change the year into the 2000's.
    CASE 
        WHEN YEAR(membership_date) < 2000 
            THEN STR_TO_DATE(
                CONCAT(
                    REPLACE(CAST(YEAR(membership_date) AS CHAR), '19', '20'),
                    DATE_FORMAT(membership_date, '-%m-%d')
                ),
                '%Y-%m-%d'
            )
        ELSE membership_date
    END AS membership_date
FROM club_member_ods.member_info_ods;

-- ============================================================
-- Step 2: Data profiling after initial load
-- ============================================================

SELECT * FROM club_member_dwd.member_info_dwd;

-- Note: The following TRUNCATE is kept for reference but commented
-- out to avoid accidental data loss. Uncomment only if needed.
-- TRUNCATE TABLE club_member_dwd.member_info_dwd;

-- Explore duplicate candidates
SELECT
    first_name,
    last_name,
    member_email,
    COUNT(*) OVER (PARTITION BY first_name, last_name, age, member_email) AS dup_count
FROM club_member_dwd.member_info_dwd
ORDER BY dup_count DESC;

SELECT * FROM club_member_dwd.member_info_dwd;
SELECT COUNT(*) FROM club_member_dwd.member_info_dwd;

-- Preview rows that will be deleted (duplicate emails with smaller member_id)
SELECT 
    c1.member_id,
    c1.first_name,
    c1.last_name,
    c2.member_id,
    c2.first_name,
    c2.last_name
FROM club_member_dwd.member_info_dwd AS c1 
JOIN club_member_dwd.member_info_dwd AS c2
    ON c1.member_email = c2.member_email 
   AND c1.member_id < c2.member_id
ORDER BY c1.member_id;

-- ============================================================
-- Step 3: Deduplication (keep the latest member_id per email)
-- ============================================================

BEGIN;

DELETE c1
FROM club_member_dwd.member_info_dwd AS c1 
JOIN club_member_dwd.member_info_dwd AS c2
    ON c1.member_email = c2.member_email 
   AND c1.member_id < c2.member_id;

-- Check the result before committing
-- ROLLBACK;   -- use this if something is wrong
COMMIT;

-- ============================================================
-- Step 4: Fix typos and inconsistent values
-- ============================================================

-- Fix marital status typo
UPDATE club_member_dwd.member_info_dwd 
SET martial_status = 'divorced'
WHERE martial_status = 'divored';

-- Trim state values
UPDATE club_member_dwd.member_info_dwd 
SET state = TRIM(state)
WHERE state != TRIM(state);

-- Fix state name typos
UPDATE club_member_dwd.member_info_dwd
SET state = 'kansas'
WHERE state = 'kansus';

UPDATE club_member_dwd.member_info_dwd 
SET state = 'district of columbia'
WHERE state = 'districts of columbia';

UPDATE club_member_dwd.member_info_dwd 
SET state = 'north carolina'
WHERE state = 'northcarolina';

UPDATE club_member_dwd.member_info_dwd 
SET state = 'california'
WHERE state = 'kalifornia';

UPDATE club_member_dwd.member_info_dwd
SET state = 'texas'
WHERE state = 'tejas';

UPDATE club_member_dwd.member_info_dwd
SET state = 'texas'
WHERE state = 'tej+f823as';

UPDATE club_member_dwd.member_info_dwd
SET state = 'tennessee'
WHERE state = 'tennesseeee';

UPDATE club_member_dwd.member_info_dwd
SET state = 'new york'
WHERE state = 'newyork';

UPDATE club_member_dwd.member_info_dwd
SET state = 'puerto rico'
WHERE state = ' puerto rico';