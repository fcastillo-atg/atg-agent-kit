# Profile: sales-order

| Key | Value |
|---|---|
| `id` | `sales-order` |
| `detect` | `sales-order.go` at the git toplevel |
| `detect-paths` | `sales-order.go` |
| `code-root` | `.` — the Dockerfile builds `go build -o /sales-order .` from the repo root |
| `branch-pattern` | `{TICKET}-{slug}` or bare `{TICKET}`, no author prefix (e.g. `UPS-5429-processing-fee`, `UPS-5468`, `PI-2220-support-refund`) |
| `story-root` | `bin/stories/` at the git toplevel |
| `plans-path` | `none` — `.claude/` is gitignored wholesale here, so no plan file under it can ever be committed, and the repo has no other tracked plan convention |
| `rules-dir` | `none` — no `.claude/rules/` or `.cursor/rules/` in this repo; lean on `atg-conventions-go` and `atg-cross-cutting-go` |
| `pr-template` | `pull_request_template.md` at the repo root |
| `pr-body-anchor` | `## How Has This Been Tested?` |
| `changeset` | `none` — no `.changeset/` infrastructure |
| `feature-flag` | `none` — no rollout-flag mechanism exists (see Notes on `AtgPayFeatureGatewayer`, which is not one) |
| `migrations-path` | `none` — no migration mechanism in the repo; the accounting DB schema is owned elsewhere |
| `source-ext` | `.go` |
| `conventions-skill` | `atg-conventions-go` |
| `cross-cutting-skill` | `atg-cross-cutting-go` |
| `dynatrace-container` | `none` — unverified, see Notes |
| `dynatrace-cluster` | `none` — unverified, see Notes |
| `dynatrace-filters` | `none` |
| `ticket-prefixes` | `UPS-*`, `BUGS-*`, `OP-*`, `ITOP-*`, `PI-*`, `WBPR-*` — all six appear in `git log`; `UPS-*` dominates. CircleCI's `lambda/ticket_in_title` job enforces a key in every PR title |
| `service-start` | `PORT=8080 DEPLOYMENT=stage RUN_LOCAL=true go run sales-order.go &`, then poll `http://localhost:8080/` every 5s up to 120s, treating **any** HTTP response as up. There is no health endpoint (see Notes) |

## Quality gates

> ⚠️ **These commands are derived from `.circleci/config.yml`, not executed.** No Go toolchain
> was installed on the machine where this profile was written (`go: command not found`), so the
> kit's own "run each gate by hand first" rule could not be satisfied. CI runs them through the
> `liveauctioneers/lambda@1.2` orb (`lambda/go_test`, `lambda/go_lint`), whose underlying
> commands are not visible in this repo. **Verify and correct these three rows on the first run
> with Go installed**, then delete this warning.

| Step | Gate | Command | Working dir | On failure |
|---|---|---|---|---|
| 1 | Build | `go build ./...` | `.` | A missing `go.work` module or a `GOWORK=off` mismatch: the Dockerfile builds with `GOWORK=off`, the integration tests need the workspace |
| 2 | Unit tests | `go test ./...` | `.` | Regenerate mocks with `./generateMocks.sh` when an interface in `internal/interfaces/` changed |
| 3 | Lint | `golangci-lint run --new-from-rev=HEAD~` | `.` | CI passes `new_from_rev: HEAD~`, so it only reports findings your diff introduced. A clean local `golangci-lint run` over the whole repo may surface pre-existing findings CI ignores |

Go 1.27 (`go.mod`, and the CI pipeline parameter). No coverage gate: CI uploads coverage to
Codacy but declares no threshold, so `/atg:verify` does not invent one.

Integration tests are **not** a verify gate. They need a running server and belong to
`/atg:test-run`: `URL=http://localhost:8080 DEPLOYMENT=stage ./internal/testgo/run.sh [TestName]`,
with `./internal/testgo/update.sh` to refresh snapshots and `DEBUG=true` for more output.

## Notes

- **No health endpoint exists.** No `/health`, `/status`, or `/healthz` route is registered in
  `sales-order.go`. Poll the root and accept any HTTP status, including 404 — connection-refused
  versus any response is the only signal that the server is up.
- **The default port is `:80`** when `PORT` is unset (`getPort()` in `sales-order.go`), which
  needs root on macOS. Always set `PORT` explicitly. CI's integration job uses 8080; the README's
  local example uses 3000 alongside atgpay on 2000.
- **`AtgPayFeatureGatewayer` is not a feature-flag system.** It fetches per-seller entitlements
  (`GetSellerFeatures`) from the atgpay feature service — a domain concept, not a rollout
  mechanism. Do not wire a gradual rollout through it.
- **Commit messages are linted.** Commitlint requires a Jira key: `UPS-1234 do the thing`, or
  `[WIP]UPS-1234 ...`. Set it up once with `npm install && npm run prepare`. There is no
  committed `package.json`, so that step depends on tooling outside the repo.
- **`bin/` is not gitignored here**, unlike the other services. Scratch story files will show up
  in `git status`; the never-commit rule is behavioural and needs more care in this repo.
- **`.claude/` is gitignored wholesale**, which is why `plans-path` is `none`. If the team wants
  a committed plan artifact, that needs a `.gitignore` carve-out first — do not improvise one.
- **Dynatrace coordinates are unverified.** No deployment manifest in this repo names a cluster,
  namespace, or container; deploys go through the CircleCI lambda orb to `barako`, `stage`, and
  `preprod`. Confirm the real values in Dynatrace before setting them, rather than assuming the
  `a2o-dev` cluster the other two profiles use — this service belongs to the `atgpay` system in
  the LIVEauctioneers org, not to a2o.
- **`current-prs` is a deployment branch, not a feature branch.** CI auto-deploys it to stage and
  treats it specially in nearly every job filter. Never target it with `/atg:ship`.
- The repo has both `internal/constants/` and `internal/consts/`. They are different packages;
  check which one a symbol lives in rather than assuming.
