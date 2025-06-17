import os, gzip, json
from io import BytesIO
from datetime import datetime
import azure.functions as func
from azure.storage.blob import BlobServiceClient
from azure.cosmos import CosmosClient

COSMOS_URL = os.environ["COSMOS_URL"]
COSMOS_KEY = os.environ["COSMOS_KEY"]
COSMOS_DB = os.environ["COSMOS_DB"]
INDEX_CONT = os.environ["COSMOS_INDEX_CONTAINER"]

BLOB_CONN = os.environ["BLOB_CONN_STRING"]
BLOB_CONT = os.environ["BLOB_CONTAINER"]

cosmos_client = CosmosClient(COSMOS_URL, COSMOS_KEY)
cosmos_db = cosmos_client.get_database_client(COSMOS_DB)
index_container = cosmos_db.get_container_client(INDEX_CONT)

blob_client = BlobServiceClient.from_connection_string(BLOB_CONN)
archive_container = blob_client.get_container_client(BLOB_CONT)

def compress_json(data: dict) -> bytes:
    b = BytesIO()
    with gzip.GzipFile(fileobj=b, mode="w") as gz:
        gz.write(json.dumps(data).encode("utf-8"))
    return b.getvalue()

def main(documents: func.DocumentList) -> None:
    if not documents:
        return
    for doc in documents:
        if "id" not in doc:
            continue

        compressed = compress_json(doc)
        blob_name = f"bill-{doc['id']}.json.gz"
        archive_container.upload_blob(blob_name, compressed, overwrite=True)

        metadata = {
            "id": doc["id"],
            "partitionKey": doc["partitionKey"],
            "invoiceMonth": doc.get("invoiceMonth"),
            "amount": doc.get("amount"),
            "hasDetails": True,
            "blobUri": f"{archive_container.url}/{blob_name}",
            "archivedUtc": datetime.utcnow().isoformat() + "Z"
        }
        index_container.upsert_item(metadata)
