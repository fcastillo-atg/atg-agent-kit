---
name: dynatrace-mcp
description: Use when querying Dynatrace logs, metrics, or problems for wavebid-a2o-service via the dynatrace-mcp MCP server.
---

# Dynatrace MCP Skill

Use this skill whenever the user asks to query logs, check metrics, inspect problems,
or work with Dynatrace data for this project.

## Step 0 — Load reference

Always read the companion reference file before writing any DQL query or making any tool call:

```
/Users/fcastilloatg/ATG/wavebid-a2o/.cursor/skills/atg/dynatrace-mcp/reference.md
```

This file contains accumulated gotchas, working query patterns, and field notes.
Never skip this step — it prevents re-learning the same lessons.

## Connection

The `dynatrace-mcp` server is configured in `.mcp.json` at the service root.
It uses HTTP transport with a Bearer token (not stdio).
Validate with an `initialize` JSON-RPC call if you need to confirm the server is live.

Available tools (call via JSON-RPC `tools/call`):

| Tool | Purpose |
|---|---|
| `execute-dql` | Run any DQL query; returns records + metadata |
| `create-dql` | Generate a DQL query from a natural language prompt |
| `query-problems` | Fetch open Dynatrace problems |
| `get-problem-by-id` | Drill into a specific problem |
| `get-events-for-kubernetes-cluster` | K8s events |
| `get-vulnerabilities` | Security vulnerabilities |

## Calling execute-dql

```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "tools/call",
  "params": {
    "name": "execute-dql",
    "arguments": {
      "dqlQueryString": "<your DQL here>"
    }
  }
}
```

POST to:
`https://zgs19810.apps.dynatrace.com/platform-reserved/mcp-gateway/v0.1/servers/dynatrace-mcp/mcp`

Header: `Authorization: Bearer <token from .mcp.json>`

## Standard log query pattern for wavebid-a2o-service

```dql
fetch logs, from: now()-30m
| filter k8s.cluster.name == "a2o-dev"
| filter k8s.container.name == "wavebid-a2o-service"
| filter startsWith(class, "com.sellerportal") or startsWith(class, "com.atg")
| filter k8s.namespace.name == "seller-portal"
| sort timestamp desc
| fields timestamp, class, level, message, thread, userId, houseId, auctionId, lotId, requestId, correlationId
| limit 100
```

**Do NOT include `samplingRatio` or `scanLimitGBytes` parameters** — see reference.md for why.

To filter only errors:
```dql
| filter level == "ERROR" or level == "WARN"
```

To trace a single upload end-to-end by S3 key prefix:
```dql
| filter contains(message, "<s3-key-prefix>")
```

## After each Dynatrace session

Update `reference.md` with any new learnings:
- DQL syntax quirks discovered
- New field names or patterns observed
- Filters or queries that worked well
- Errors encountered and their fixes

Keep entries dated and concise.
