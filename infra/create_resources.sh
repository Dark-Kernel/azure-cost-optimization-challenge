#!/usr/bin/env bash
set -euo pipefail

# variables
RG=cost-demo-rg
LOC=eastus2
COSMOS_ACCT=costdemo-cosmos
DB=billingdb
HOT_CONT=billing_hot
IDX_CONT=billing_index
STOR_ACCT=costdemostore
BLOB_CONT=cold

az group create --name $RG --location $LOC

# Cosmos DB account (Core SQL API, analytical store on)
az cosmosdb create \
  --name $COSMOS_ACCT \
  --resource-group $RG \
  --locations regionName=$LOC failoverPriority=0 \
  --kind GlobalDocumentDB \
  --default-consistency-level Session \
  --enable-analytical-storage true

# SQL database
az cosmosdb sql database create \
  --account-name $COSMOS_ACCT \
  --resource-group $RG \
  --name $DB

# hot-data container: autoscale 40k RU/s upper bound
az cosmosdb sql container create \
  --account-name $COSMOS_ACCT \
  --resource-group $RG \
  --database-name $DB \
  --name $HOT_CONT \
  --partition-key-path "/partitionKey" \
  --throughput-type Autoscale \
  --max-throughput 40000

# minimal indexing policy for metadata index
cat > index-off.json <<'EOF'
{
  "indexingMode": "consistent",
  "automatic": true,
  "includedPaths": [],
  "excludedPaths": [
    { "path": "/*" }
  ]
}
EOF

# metadata-index container: manual 400 RU/s, indexing disabled
az cosmosdb sql container create \
  --account-name $COSMOS_ACCT \
  --resource-group $RG \
  --database-name $DB \
  --name $IDX_CONT \
  --partition-key-path "/partitionKey" \
  --throughput 400 \
  --idx @index-off.json

# storage account set to Cool default tier
az storage account create \
  --name $STOR_ACCT \
  --resource-group $RG \
  --location $LOC \
  --sku Standard_ZRS \
  --kind StorageV2 \
  --access-tier Cool

# blob container for compressed JSON archives
az storage container create \
  --account-name $STOR_ACCT \
  --auth-mode login \
  --name $BLOB_CONT
