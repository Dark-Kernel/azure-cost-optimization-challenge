# Billing Data Archival Architecture

```mermaid
graph TD
  CosmosHot[billing_hot<br>Cosmos DB] --Change Feed--> Archiver[Azure Function<br>archive_billing_trigger]
  Archiver --> Blob[Blob Storage<br>cold/bill-id.json.gz]
  Archiver --> MetaIdx[billing_index<br>Cosmos DB]
  API[getBill] --> CosmosHot
  API --> MetaIdx
  MetaIdx --> Blob
```


```
Client ──► API Mgmt ──► FunctionApp
                      │
                      ├─► Cosmos DB (hot, TTL 90d)
                      │        ▲
Change Feed ──────────┘        │
           │                   │
           ▼                   │
Archive Function ──► Blob Storage (cold, Parquet)
```

## Directory Structure

- infra/
  - create_resources.sh
  - index-off.json
- function/archive_billing_trigger/
  - __init__.py
  - function.json
  - local.settings.sample.json
- src/
  - getBill.ts
