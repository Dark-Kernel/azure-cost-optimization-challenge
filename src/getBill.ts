import { CosmosClient } from "@azure/cosmos";
import { BlobServiceClient } from "@azure/storage-blob";
import { gunzipSync } from "node:zlib";
import Redis from "ioredis";

const cosmos = new CosmosClient(process.env.COSMOS_CONN!);
const hot = cosmos.database("billingdb").container("billing_hot");
const idx = cosmos.database("billingdb").container("billing_index");

const blobSvc = BlobServiceClient.fromConnectionString(process.env.BLOB_CONN!);
const cache = new Redis(process.env.REDIS_URL!); // optional

export async function getBill(id: string, pKey: string) {
  const cacheKey = `bill:${id}`;
  const cached = await cache.get(cacheKey);
  if (cached) return JSON.parse(cached);

  try {
    const { resource } = await hot.item(id, pKey).read();
    await cache.setex(cacheKey, 300, JSON.stringify(resource));
    return resource;
  } catch {
    /* not found in hot */
  }

  const { resource: meta } = await idx.item(id, pKey).read();
  if (!meta?.hasDetails) throw new Error("bill missing");

  const blob = blobSvc.getBlobClient(meta.blobUri);
  const buf = await blob.downloadToBuffer();
  const full = JSON.parse(gunzipSync(buf).toString());

  await cache.setex(cacheKey, 86400, JSON.stringify(full));
  return full;
}
