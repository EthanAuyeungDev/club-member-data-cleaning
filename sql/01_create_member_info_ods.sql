-- ============================================================
-- Project  : Club Membership Data Cleaning
-- Layer    : ODS (Operational Data Store)
-- File     : 01_create_member_info_ods.sql
-- Purpose  :
--   1. Create ODS and DWD databases
--   2. Create the ODS table for raw club member data
--   3. Load the raw CSV file into the ODS table
--   4. Perform initial data profiling
--
-- Notes:
--   - LOAD DATA LOCAL INFILE requires local_infile enabled
--     on both server and client sides.
--   - Replace the CSV path with your own local path.
--   - ODS layer keeps loose data types and is append-only,
--     so raw data remains traceable.
-- ============================================================

-- ============================================================
-- Step 1: Create databases
-- ============================================================

DROP DATABASE IF EXISTS club_member_ods;
DROP DATABASE IF EXISTS club_member_dwd;

CREATE DATABASE IF NOT EXISTS club_member_ods
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

CREATE DATABASE IF NOT EXISTS club_member_dwd
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

-- ============================================================
-- Step 2: Create ODS raw table
-- ------------------------------------------------------------
-- Design principles:
--   - All fields use VARCHAR to avoid import failures
--   - Auto-increment id as primary key
--   - Table name ends with _ods to indicate its layer
-- ============================================================

USE club_member_ods;
DROP TABLE IF EXISTS member_info_ods;

CREATE TABLE IF NOT EXISTS member_info_ods (
    member_id       INT UNSIGNED AUTO_INCREMENT PRIMARY KEY COMMENT 'Auto-increment primary key',
    full_name       VARCHAR(100) COMMENT 'Full name (raw)',
    age             VARCHAR(10)  COMMENT 'Age (raw text)',
    martial_status  VARCHAR(20)  COMMENT 'Marital status (raw, may contain typos)',
    email           VARCHAR(50)  COMMENT 'Email address (raw)',
    phone           VARCHAR(50)  COMMENT 'Phone number (raw)',
    full_address    VARCHAR(150) COMMENT 'Full address (raw)',
    job_title       VARCHAR(100) COMMENT 'Job title (raw)',
    membership_date DATE         COMMENT 'Membership date'
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8mb4
  COLLATE = utf8mb4_unicode_ci
  COMMENT = 'Raw club member information (ODS layer)';

-- ============================================================
-- Step 3: Load local CSV file
-- ------------------------------------------------------------
-- Replace the path below with your own CSV file path.
-- Field delimiter : comma
-- Enclosed by     : double quote
-- Line delimiter  : \n
-- Skip 1 header row
-- ============================================================

LOAD DATA LOCAL INFILE '/path/to/your/club_member_info.csv'
INTO TABLE member_info_ods
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(full_name, age, martial_status, email, phone, full_address, job_title, @membership_date_str)
SET membership_date = STR_TO_DATE(@membership_date_str, '%m/%d/%Y');

-- ============================================================
-- Step 4: Initial data profiling
-- ============================================================

SELECT @membership_date_str;

SELECT * FROM member_info_ods;

SELECT COUNT(*) FROM member_info_ods;

SELECT * FROM member_info_ods WHERE full_name != TRIM(full_name);