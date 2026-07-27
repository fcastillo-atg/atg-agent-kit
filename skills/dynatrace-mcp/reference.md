# Dynatrace MCP — Reference (accumulated learnings)

Append a new entry after each session. Keep entries dated and concise.

---

## 2026-06-01 — Initial session (connection validation + log querying)

### Connection

- Server type: **HTTP MCP** (not stdio). No local process needed.
- Validate with a JSON-RPC `initialize` call — returns `200` + protocol version on success.
- Server protocol version: `2025-06-18`. Capabilities: `resources` + `tools`.

### Critical DQL gotcha: `//` is a comment character

The reference query circulating on the team is:

```
fetch logs //, scanLimitGBytes: 500, samplingRatio: 1000
```

The `//` makes everything after it a **comment**. `scanLimitGBytes` and `samplingRatio`
are silently ignored. The effective query is just `fetch logs`.

**Impact**: When those params are used correctly (e.g. `fetch logs, samplingRatio: 1000`),
`samplingRatio: 1000` means "use 1/1000 records" — near-zero results.
Without the params (comment strips them), Dynatrace uses its defaults and scans everything.

**Rule**: Never copy those params from the reference query. Write `fetch logs, from: now()-Xm`
with only the `from:` timeframe parameter.

### DQL summarize syntax

`sort` inside `summarize` is not supported — use a separate `| sort` after `| summarize`:

```dql
| summarize count(), by: {class}
| sort count() desc   ← this is a separate pipe stage, not inside summarize
| limit 20
```

`limit` is also a separate pipe stage, not a `summarize` parameter.

### Log field map for wavebid-a2o-service

Fields available on parsed log records (2026-06-01 observation):

| Field | Notes |
|---|---|
| `timestamp` | ISO 8601 UTC |
| `class` | Logger class name (e.g. `com.sellerportal.api.s3events.S3EventNotificationRecordListener`) |
| `level` | `DEBUG`, `INFO`, `WARN`, `ERROR` |
| `message` | Log message body |
| `thread` | JVM thread name |
| `userId` | Set to `"null"` string when not in a user context |
| `houseId` | Auction house ID |
| `auctionId` | Auction ID |
| `lotId` | Lot ID |
| `requestId` | HTTP request trace ID (UUIDv7) |
| `correlationId` | Correlation ID (UUIDv7) |
| `k8s.cluster.name` | `a2o-dev` for dev |
| `k8s.container.name` | `wavebid-a2o-service` |
| `k8s.namespace.name` | `seller-portal` (main), or `seller-portal-WBPR-XXXX-*` for feature branches |
| `k8s.pod.name` | Full pod name |
| `rabbitConsumerQueue` | RabbitMQ queue name, when relevant |
| `rabbitReceivedRoutingKey` | RabbitMQ routing key |
| `content` | Raw JSON log line (full structured log as string) |

### S3/SNS upload pipeline log sequence

Each file upload through the SNS→S3 path produces this log sequence (same timestamp cluster):

1. `HttpLoggingFilter` — `Processing HTTP Request`
2. `SnsMessageMethodArgumentResolver` — `Parsed SNS message <id> type: Notification`
3. `SignatureVerifier` — `Decoded signature length: 256` / `Using signature version: SHA1`
4. `SignatureVerifier` — `Signature verification result: true`
5. `S3EventSnsMessageService` — `Handling SNS notification: Notification(messageId=...)`
6. `S3EventSnsMessageService` — `Published S3EventNotificationRecord with routing key : <s3-key>`
7. `HttpLoggingFilter` — `Finished HTTP Request`
8. `S3EventNotificationRecordListener` — `Processing S3EventNotificationRecord: <bucket:key>`
9. `S3FileService` — `getting metadata for <bucket:key>`
10. `S3FileService` — `metadata for <bucket:key>; content length: ...`
11. `S3FileService` — `found tags: {...}` (includes `rabbitmqVhost`, `correlationId`, `attachmentId`, or `originalFilename`)
12. `S3EventNotificationRecordListener` — `Published FileUploadedEvent with routing key file-uploaded: <bucket:key>`
13. `AttachmentFileUploadedEventHandler` — `Processing FileUploadedEvent for key <key>`
14. `AttachmentFileUploadedEventHandler` — `Ignoring...` (if not attachment) or `Successfully processed...`
15. `BunnyCdnCachePurgeListener` — `Skipping CDN purge for new upload: <key>`

To trace a single upload use `| filter contains(message, "<s3-key-prefix>")`.

### Namespaces

- `seller-portal` — the main dev namespace
- `seller-portal-WBPR-XXXX-*` — per-ticket feature branch namespaces (commented out in reference query, uncomment when needed)

---

## 2026-06-02 — PR preview env debugging + structured-field vs raw-content gotchas

### PR preview namespace casing

PR preview namespaces look like `seller-portal-fc-WBPR-4315-stuck-image-sweeper` (mixed case: `fc-WBPR`).
`matchesValue(k8s.namespace.name, "seller-portal-fc-WBPR-4315-stuck-image-sweeper")` works — `matchesValue` is case-insensitive.
`k8s.namespace.name == "..."` is case-sensitive and will match nothing if the case is wrong; always prefer `matchesValue` for namespace filters.

### samplingRatio: 1000 silently kills WARN/ERROR queries

`fetch logs, samplingRatio: 1000` (correctly placed, not commented) means Dynatrace samples 1 in every 1000 records. On a feature-branch namespace with low traffic, this returns zero results even when real WARN/ERROR logs exist. **Never use samplingRatio when debugging — only for volume/aggregation queries.**

### raw `content` field vs structured fields

Two ways to query logs — pick the right one:

| Approach | When to use | Pitfall |
|---|---|---|
| `filter contains(content, "someText")` | Quick grep when you don't know the field | Returns nginx access logs too; their `loglevel` can appear as "WARN"/"ERROR" even for HTTP 200s |
| `filter startsWith(class, "com.sellerportal")` + `filter level == "ERROR"` | Always for app-level errors | Only returns real app logs; misses nothing that matters |

**Key gotcha**: Dynatrace parses nginx ingress access logs and assigns `loglevel: ERROR` to some of them even when the HTTP status code is 200. This creates false positives when filtering raw `loglevel` or searching `content`. The structured `level` field (from the app's JSON log output) does not have this problem — it only appears on lines where `k8s.container.name == "wavebid-a2o-service"` and `class` starts with `com.sellerportal` or `com.atg`.

### Extend time window when debugging CSV import or async flows

The default `from: now()-30m` misses events if the import happened earlier. Use `from: now()-2h` or longer for async pipelines (lot import image download runs via RabbitMQ and can lag).

### Lot import image download failure pattern

When a CSV image URL returns HTTP 404 the sequence is:
1. `LotImportImageFetchClient` WARN: `<url> returned 404 Not Found`
2. `LotImportImageDownloadService` WARN: `permanent failure for attachment <id>: code=HTTP_CLIENT_ERROR, url=<url>, message=Image not found at URL (HTTP 404)`

The attachment ends up with `uploaded=false, failed=true` in the DB. **This is correct backend behaviour** — the frontend must check `failed` to avoid treating these as still-uploading.
