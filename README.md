
# binance-etl-pipeline

# How to Run the Project

## Install necessary library 
```
pip install -r requirements.txt
pip install dbt-core
pip install dbt-bigquery
``` 

## Get credential from google cloud (here I use BigQuery for dbt)
- You can use default account or using service account file
- if using service account, I recommend granting big query admin role

```
gcloud auth login
gcloud auth application-default login
```

- After that create dataset 'raw' on big query to contain raw data

## Running python script: 
'''
cd crawling_binance_data

python fetch_binance_klines.py \
    --project_id your-gcp-project-id \
    --dataset raw \
    --credentials /path/to/your-service-account.json
'''
## Configure dbt for BigQuery
- Create folder:
```
mkdir ~/.dbt
```
- Create file:
```
nano ~/.dbt/profiles.yml
```
```
📌 profiles.yml example
bigquery_project:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      project: your-project-id
      dataset: staging
      threads: 4
      timeout_seconds: 300
      location: asia-southeast1
      priority: interactive
```

- Switch dbt project to use this profile

## Run dbt Transformations
- In dbt_project.yml: 
profile: bigquery_project
```
- Test dbt connection
dbt debug

- Update packages
dbt deps

- Run all models
dbt run

- Or run by layer
Bronze (staging)
dbt run --select staging

Silver (intermediate)
dbt run --select intermediate

Gold (marts)
dbt run --select marts

Run tests
dbt test

