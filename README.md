# Club Membership Data Cleaning Project

## Project Overview

This project demonstrates a practical SQL data-cleaning workflow using a club membership dataset. It is designed as a portfolio project to show how raw, inconsistent data can be transformed into a cleaner and more analysis-ready dataset using MySQL.

The project follows a simple **ODS → DWD** layered data architecture:

- **ODS (Operational Data Store)** stores the imported raw membership data with relatively loose data types and minimal transformation.
- **DWD (Data Warehouse Detail)** contains the cleaned and standardized member-level data prepared for downstream analysis.

Instead of treating data cleaning as a collection of isolated SQL operations, this project organizes the work as a repeatable pipeline:

```text
Raw CSV
   ↓
ODS Layer
   ↓
Initial Data Profiling
   ↓
Field Standardization
   ↓
Missing / Empty Value Handling
   ↓
Data Transformation
   ↓
Deduplication
   ↓
Typo & Value Correction
   ↓
Data Validation
   ↓
DWD Analysis-Ready Data
```

The dataset intentionally contains a variety of common data-quality problems, including inconsistent capitalization, extra spaces, malformed values, duplicate records, spelling mistakes, invalid or incomplete phone numbers, inconsistent state names, and dates that require correction.

The purpose of the project is therefore not simply to "make the data look clean", but to demonstrate the reasoning and SQL techniques required to identify data-quality problems, define appropriate cleaning rules, apply transformations safely, and validate the resulting dataset.

This project focuses on the **data preparation stage that typically happens before business analysis, reporting, or visualization**.

## Project Purpose

The main goals are:

1. **Understand ODS and DWD data layering**  
   Keep raw imported data separate from transformed data so that the cleaning process remains traceable and reproducible.

2. **Practice real-world SQL data cleaning**  
   Apply SQL techniques for string normalization, missing-value handling, data transformation, deduplication, typo correction, and validation.

3. **Work with messy, imperfect source data**  
   Handle problems that are commonly found in manually entered or externally supplied datasets rather than relying on an already-clean dataset.

4. **Build a reproducible cleaning workflow**  
   Separate ODS creation/loading from DWD transformation so the workflow can be rerun when the raw source data is refreshed.

5. **Demonstrate practical Data Analyst skills**  
   Show the ability to profile raw data, identify quality issues, translate business/data-quality rules into SQL, and validate the cleaned result.

6. **Create a portfolio-ready SQL project**  
   Demonstrate practical use of MySQL features that are relevant to Data Analyst work, including CTE/CTAS-style transformations, window functions, regular expressions, string functions, conditional logic, joins, transactions, and safe update/delete patterns.

## Dataset

- **Name**: Club Member Information
- **Source**: Internal CSV file (`club_member_info.csv`)
- **Format**: CSV
- **Database**: MySQL
- **Purpose**: Simulated club membership data for practicing data cleaning

### Main Fields

The raw dataset contains:

- Member ID
- Full name
- Age
- Marital status
- Email
- Phone
- Full address
- Job title
- Membership date

### Known Data Quality Issues

The raw data contains several deliberately introduced or observed issues:

- Inconsistent capitalization and extra whitespace
- Age values containing unexpected three-digit values
- Marital status typo such as `divored`
- Invalid or incomplete phone numbers
- Full address stored as a single string
- Job titles containing Roman numeral levels such as `I`, `II`, `III`, and `IV`
- Membership dates containing years in the 1900s
- Duplicate records associated with the same email
- State-name spelling and formatting errors such as:
  - `kansus`
  - `kalifornia`
  - `tejas`
  - `tennesseeee`
  - `newyork`
  - `northcarolina`

These issues provide opportunities to demonstrate different types of SQL cleaning rather than repeatedly applying the same transformation.

## Data Cleaning Workflow

### 1. Create the ODS Layer

The `01_create_member_info_ods.sql` script:

- Creates the `club_member_ods` and `club_member_dwd` databases.
- Creates the raw ODS table.
- Uses relatively loose field definitions to avoid unnecessary import failures.
- Loads the CSV file with `LOAD DATA LOCAL INFILE`.
- Converts the raw membership-date string into a MySQL `DATE`.
- Performs initial data profiling.

The ODS layer acts as the starting point for the cleaning workflow and keeps the imported data separate from the transformed DWD data.

### 2. Create the DWD Layer

The `02_member_info_cleaning_dwd.sql` script creates the cleaned DWD table using a CTAS-style transformation.

During this step, several fields are transformed directly from the ODS data.

#### Name Cleaning

The full name is normalized by:

- Trimming whitespace
- Converting text to lowercase
- Separating first and last names
- Removing non-alphabetic characters from the first-name field

Example techniques:

```sql
LOWER()
TRIM()
SUBSTRING_INDEX()
SUBSTRING()
LOCATE()
REGEXP_REPLACE()
```

#### Age Cleaning

The script handles empty age values and addresses three-digit age entries by retaining the first two digits according to the project's cleaning rule.

```sql
CASE
    WHEN LENGTH(age) = 0 THEN NULL
    WHEN LENGTH(age) = 3 THEN SUBSTRING(age, 1, 2)
    ELSE age
END
```

#### Email Standardization

Email values are standardized by trimming whitespace and converting them to lowercase.

```sql
LOWER(TRIM(email))
```

#### Phone Validation

Phone values are trimmed, empty strings are converted to `NULL`, and values shorter than the project's minimum expected length are treated as invalid.

#### Address Parsing

The original full address is stored as a single string. The cleaning process separates it into:

- `street_address`
- `city`
- `state`

using `SUBSTRING_INDEX()`.

This demonstrates a common data-cleaning task: converting a denormalized text field into more useful analytical attributes.

#### Job Title Standardization

Job titles are normalized by:

- Trimming whitespace
- Converting text to lowercase
- Converting Roman numeral levels into numeric descriptions

For example:

```text
software engineer II
        ↓
software engineer, level 2
```

This makes similar job titles more consistent for downstream grouping and analysis.

#### Membership Date Correction

Some membership dates contain years in the 1900s. The project applies a specific transformation rule to convert those years into the 2000s while preserving the month and day.

## Deduplication

Duplicate records are profiled before deletion.

The project uses a window function to identify potential duplicate groups:

```sql
COUNT(*) OVER (
    PARTITION BY first_name, last_name, age, member_email
)
```

Duplicate records are then previewed before deletion.

The final deduplication step uses a self-join on `member_email` and keeps the record with the larger `member_id`, based on the project's assumption that the larger ID represents the latest record.

The deletion is wrapped in a transaction:

```sql
BEGIN;

DELETE ...

COMMIT;
```

A commented `ROLLBACK` is retained in the script so the deletion can be reviewed and reversed before committing when necessary.

This part of the project demonstrates an important practical principle:

> **Preview potentially destructive changes before applying them, and use transactions when appropriate.**

## Data Standardization and Error Correction

After deduplication, categorical values are standardized.

Examples include:

- Correcting `divored` → `divorced`
- Trimming state values
- Correcting state-name spelling errors
- Standardizing inconsistent state representations

The cleaning rules are implemented with targeted `UPDATE` statements so that each transformation is explicit and easy to review.

## Data Validation

The project includes profiling and validation queries to inspect the cleaned dataset.

Examples include:

- Reviewing the complete DWD table
- Counting records
- Inspecting potential duplicates
- Previewing records before deletion
- Reviewing cleaned categorical values

The goal is to validate the data after transformation rather than assuming that successful SQL execution automatically means the data is correct.

## SQL Techniques Demonstrated

This project demonstrates practical use of:

### Data Transformation

- `LOWER()`
- `TRIM()`
- `SUBSTRING()`
- `SUBSTRING_INDEX()`
- `LOCATE()`
- `LENGTH()`
- `CASE`
- `STR_TO_DATE()`
- `DATE_FORMAT()`
- `YEAR()`
- `REGEXP_REPLACE()`
- `REGEXP`

### Data Quality

- Empty-string detection
- `NULL` handling
- Invalid-value detection
- Categorical standardization
- Typo correction
- Duplicate detection
- Data profiling
- Post-cleaning validation

### Advanced SQL

- Window functions
- `PARTITION BY`
- `COUNT(*) OVER (...)`
- Self-joins
- CTAS-style table creation
- Transactions
- Safe `DELETE` / `UPDATE` workflows

## Tech Stack

- **Database**: MySQL 8.0+
- **Client**: DBeaver
- **Language**: SQL
- **Version Control**: Git / GitHub

## Directory Structure

```text
club-membership-data-cleaning/
├── sql/
│   ├── 01_create_member_info_ods.sql
│   └── 02_member_info_cleaning_dwd.sql
├── data/
│   └── club_member_info.csv   -- Raw data (not uploaded)
├── README.md
└── .gitignore
```

## How to Run

### 1. Prepare the CSV

Place the raw CSV file on your local machine.

The raw dataset is intentionally not included in this repository.

### 2. Update the CSV Path

Open:

```text
sql/01_create_member_info_ods.sql
```

Replace:

```sql
LOAD DATA LOCAL INFILE '/path/to/your/club_member_info.csv'
```

with the actual local path to the CSV file.

`LOAD DATA LOCAL INFILE` requires `local_infile` to be enabled on the MySQL server/client environment.

### 3. Run the ODS Script

Execute:

```text
sql/01_create_member_info_ods.sql
```

This creates the databases, creates the ODS table, imports the raw data, and performs initial profiling.

### 4. Run the DWD Cleaning Script

Execute:

```text
sql/02_member_info_cleaning_dwd.sql
```

This creates and cleans the DWD table and performs deduplication, standardization, and validation.

## Portfolio Focus

This project is intended to demonstrate more than knowledge of individual SQL functions.

The main focus is the ability to work through a realistic data-cleaning problem from beginning to end:

```text
Understand the raw data
        ↓
Profile data quality
        ↓
Define cleaning rules
        ↓
Transform the data
        ↓
Remove / correct invalid records
        ↓
Validate the result
        ↓
Produce analysis-ready data
```

This workflow reflects the practical role of SQL in data analyst work: **SQL is not only used to query clean data, but also to make raw data trustworthy enough to analyze.**
