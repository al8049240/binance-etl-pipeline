

Architecture Diagram
---

              +--------------------+
              |  Binance API       |
              +---------+----------+
                        |
                        v
              +--------------------+
              |  BigQuery RAW      |
              |  (transactions,     |
              |   users, rates)     |
              +---------+----------+
                        |
                        v
        +----------------------------------+
        |     STAGING (BRONZE)            |
        |  - Clean column names           |
        |  - Cast correct data types      |
        |  - Light transformations        |
        +---------------+------------------+
                        |
                        v
        +----------------------------------+
        |   INTERMEDIATE (SILVER)         |
        |  - Join tables                  |
        |  - Deduplicate                  |
        |  - Filter invalid records       |
        |  - Intermediate aggregations    |
        |  - Materialized tables/views    |
        +---------------+------------------+
                        |
                        v
        +----------------------------------+
        |       GOLD (MARTS)              |
        |  - Business-ready datasets      |
        |  - Final aggregations           |
        |  - Dashboard tables             |
        +----------------------------------+


---

## Project Directory Structure


```
my_dbt_project/
│
├── README.md # Project overview
├── dbt_project.yml # dbt config
├── profiles.yml # dbt connection profiles (not committed)
│
├── data/ # Optional: raw CSVs for local development
│ ├── transactions.csv
│ ├── users.csv
│ └── rates.json # if saved locally
│
├── scripts/ # Python scripts
│ └── fetch_binance_klines.py # your crawling script
│
├── models/ # dbt models
│ ├── staging/ # Bronze Layer
│ │ ├── staging_transactions.sql
│ │ ├── staging_users.sql
│ │ └── staging_rates.sql
│ │
│ ├── intermediate/ # Silver Layer
│ │ └── fact_transactions.sql
│ │
│ ├── marts/ # Gold Layer
│ │ └── agg_ttl_by_kyc_lvl.sql
│ │
│ └── schema.yml # tests for all models
│
├── macros/ # Optional custom macros and custom test
│
├── tests/ # Optional extra dbt tests
│
└── docs/ # Architecture / docs
└── ARCHITECTURE.md
---

## Notes

1. **Bronze Layer** → `staging/` folder, cleans and standardizes raw sources.  
2. **Silver Layer** → `intermediate/` folder, enriches data (e.g., join rates, historical KYC).  
3. **Gold Layer** → `marts/` folder, aggregates for business reporting (daily/monthly/quarterly + KYC).  
4. **Snapshots** → `snapshots/` folder to capture historical KYC levels over time.  
5. **crawling_binance_data** → Python scripts for data ingestion from external APIs (e.g., Binance).  
6. **Docs** → `ARCHITECTURE.md` or other documentation.  

---

## Transformation & Data Modeling

### Bronze Layer - staging :

- The staging layer performs the essential cleanup and standardization needed before deeper transformations:
- Convert data types (e.g., timestamps, numerics).
- Rename columns according to engineering naming conventions.
- Apply small preprocessing logic. 
- Ensure consistent schemas for downstream joins. 
- Add basic tests (e.g., not_null, unique, accepted_values).


### Silver Layer — intermediate:

- The silver layer prepares data for analytics and is optimized for performance and usability:
- Join related tables (e.g., transactions ↔ users ↔ rates).
- Remove duplicates and invalid records.
- Perform intermediate aggregations before the final business layer.
- Add materialized tables/views to reduce compute costs for BI workloads.
- Store slowly changing dimension logic (e.g., historical KYC level SCD-2).
- This layer significantly improves the reliability and speed of the gold layer.

### Gold Layer — marts

- The gold layer provides final, business-ready data:
- Perform final level-of-detail aggregations (daily/monthly/quarterly).
- Produce fact tables and dimension tables.
- Provide curated datasets for BI teams and dashboards.
- Support use cases such as:
- Total trade volume in USD.
- Completed transactions by KYC level.
- Historical user KYC level at the time of each transaction.
- This is the layer consumed directly by analytics and reporting tools.


### Testing
- Basic Data Quality Tests: Validate null constraints, ensure required fields are present, and enforce correct data types.
- Uniqueness Tests: Check for unique primary keys and unique key combinations to prevent duplicates.
- Referential Integrity Tests: Ensure foreign key relationships between facts and dimensions are valid.
- Float Precision Tests: Verify numeric precision and scale, especially for amount columns with financial impact.
- USD Conversion Logic Tests: Confirm that currency conversion is calculated correctly and that all required currencies exist in the dataset.
- Custom Business Logic Tests: Apply dbt custom tests to validate transformation rules, thresholds, and other logic defined by the data engineering team.



### The reasons for chosing this model: 3-tier architecture (Bronze → Silver → Gold) with a star schema
- Perfect for implementing SCD on dimension tables (especially dim_user for historical KYC level).
- High maintainability and flexibility: each layer has a clear responsibility; changes are isolated.
- Ensures data quality and performance:
  - Silver layer standardizes & cleans data
  - Gold layer is optimized for BI / analytics queries
- Easy to scale and adapt to new business changes.
- Simple to monitor because each layer has controlled inputs and outputs.


### tracking KYC level history method
- Solution: Implement SCD Type 2 on dim_user
  - The dim_user table includes:
    - kyc_level 
    - effective_from 
    - effective_to
    - is_current
  - Whenever the KYC level changes:
    - The current record is closed
    - effective_to = current_timestamp 
    - is_current = false
  - A new record is inserted
    - Updated kyc_level
    - effective_from = current_timestamp
    - effective_to = null
    - is_current = true
  - Query transaction created time between effective_from and effective_to (here in the sql code I used created_at and updated_at as an example)
- Example 
- dim_user (SCD2)
----------------------------------------------------------
user_id | kyc_level | effective_from | effective_to | is_current
----------------------------------------------------------
123     | basic     | 2024-01-01     | 2024-03-10   | false
123     | plus      | 2024-03-10     | 2024-09-01   | false
123     | premium   | 2024-09-01     | NULL         | true


## Architecture and Storage 
### Data Warehouse Selection: 
- If implementing this project in a real environment, I would choose Google BigQuery as the Data Warehouse.
Reasons:
- Serverless & fully managed: No infrastructure management required, with automatic scaling and a separation of storage and compute.
- Excellent support for semi-structured data: Native handling of JSON, arrays, and UNNEST operations—very useful for Binance API data.
- Strong integration with dbt: BigQuery offers one of the best-supported dbt adapters, including robust materializations and incremental models.
- High performance & low operational overhead: Ideal for ELT workloads and large datasets that grow over time.
- Rich ecosystem integration: Works seamlessly with GCP services such as Cloud Composer (Airflow), Cloud Scheduler, Cloud Functions, and GCS.
- Additional powerful features: Time Travel, stored procedures, and metadata query capabilities (helpful for cost optimization).

### Materialization Strategy in dbt
a. Staging Layer (Bronze)
- Materialization: view 
- Staging tables only perform lightweight transformations (cast types, rename columns, normalize structure).
- No need to store data physically.
- Keep storage cost low and allow fast iteration.
- This can change based on the requirement of PO 

b. Intermediate Layer (Silver)
- Materialization: table
- Intermediate layer joins multiple staging tables, computes new fields (e.g., USD conversion), filters data, and removes duplicates.
- Persisting intermediate models improves performance for downstream gold models.
- Reduces repeated computation when running dbt.
- Implement intermediate agg to reduce the processed data in gold layer
Optional:
- For large datasets, some intermediate models can use incremental materialization (cached queries).
- Using Ephemeral Models for small logic blocks reused in multiple places, macros or small calculation helpers

c. Gold Layer (Business Aggregates)
- Materialization: table (or incremental for large facts)
- Gold models are final business outputs (daily metrics, summaries, dashboards).
- Should be fast to query for BI tools.
- Should not recompute full history every time.
- Incremental logic can be applied if daily data loads are append-only.


## Orchestration Schedule
- Because this project requires both Python-based API extraction and SQL transformations using dbt, I will use Apache Airflow (or Cloud Composer on GCP) to orchestrate the pipeline. Airflow allows clear dependency management, scheduling, observability, retries, and modular task design.
- Pipeline Overview

The daily pipeline includes:

Task 1: Extract Binance API → Load raw tables

Task 2: dbt transformations (staging → intermediate → gold)

Task 3: Run dbt tests after each stage to ensure data quality

DAG Structure & Task Dependencies

       [Extract Binance API]
                |
        [Load to GCS/BigQuery]
                |
         [Run dbt Staging]
                |
      [Test dbt Staging Models]
                |
      [Run dbt Intermediate]
                |
     [Test dbt Intermediate Models] 
                |
         [Run dbt Gold]
                |
        [Test dbt Gold Models]


Task Descriptions
1. extract_binance_api

- Python script calls the Binance public API.

- Extracts 3 datasets: transactions, users, and rates.

Saves data to GCS as JSON or loads directly into raw BigQuery tables.
(The final file format and storage method may vary depending on production data volume and performance requirements.)

2. load_raw_to_bigquery

- Loads JSON/CSV files from GCS into BigQuery raw (bronze) tables.

- Ensures the raw layer is fully refreshed before running dbt.

3. dbt_run_staging

- Runs only staging models:
- dbt run --select staging

- Performs basic transformations such as type casting, renaming, and schema normalization.

- 3.1 test_staging

- Runs tests on staging models first.

- Pipeline continues only if all tests pass.

4. dbt_run_intermediate

- Runs intermediate (silver) models:
- dbt run --select intermediate

- Joins staging tables, enriches the data, removes duplicates, and prepares data for the gold layer.

- 4.1 test_intermediate

- Tests intermediate models for data quality, consistency, and logic correctness.

- Pipeline stops immediately if any test fails.

5. dbt_run_gold

- Runs final business-ready models:
- dbt run --select marts
- Computes final aggregations and metrics used by analysts or dashboards.
- 5.1 test_gold
- Ensures the gold layer meets all quality requirements before BI tools consume the data.

6. dbt_test (Optional)

- Optionally, run a full test suite:
- dbt test
- This can be used to validate everything in a single step, or as a final safety check after all stages complete.
- Depending on business requirements, tests can:
- run all at once, or
- run after each layer for stricter data quality and earlier error detection.


