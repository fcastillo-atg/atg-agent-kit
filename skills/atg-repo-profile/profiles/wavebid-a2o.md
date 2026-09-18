# Profile: wavebid-a2o

| Key | Value |
|---|---|
| `id` | `wavebid-a2o` |
| `detect` | `wavebid-a2o-service/` and `wavebid-a2o-ui/` at the git toplevel |
| `detect-paths` | `wavebid-a2o-service/ wavebid-a2o-ui/` |
| `code-root` | `wavebid-a2o-service/` |
| `branch-pattern` | `fc/{TICKET}-{slug}` |
| `story-root` | `bin/stories/` — under `wavebid-a2o-service/` or the monorepo root; check both |
| `plans-path` | `wavebid-a2o-service/.claude/plans/{TICKET}-{slug}.md` |
| `rules-dir` | `wavebid-a2o-service/.claude/rules/` |
| `pr-template` | `pull_request_template.md` at the monorepo root (`../pull_request_template.md` from the service) |
| `pr-body-anchor` | `#### Requirements` |
| `changeset` | `.changeset/*.md` required when the diff touches `wavebid-a2o-service/` or `wavebid-a2o-ui/`, unless the PR carries `skip-changelog`. Cursor: `/gsd/changeset-wavebid-a2o`. Elsewhere: `.cursor/commands/gsd/changeset-wavebid-a2o.md` at the monorepo root. Never run interactive `pnpm changeset` from an agent session |
| `feature-flag` | Single-file Kotlin pattern (interface + Noop + Enabled + ProxyFactory) in `{Interface}FeatureFlag.kt`; full recipe in `recipes/wavebid-a2o-feature-flag.md` |
| `migrations-path` | `wavebid-a2o-service/src/main/resources/db/changelog/` (Liquibase changesets) |
| `source-ext` | `.kt`, `.groovy` |
| `conventions-skill` | `atg-conventions-guard` |
| `cross-cutting-skill` | `atg-cross-cutting-spotter` |
| `dynatrace-container` | `wavebid-a2o-service` |
| `dynatrace-cluster` | `a2o-dev` |
| `dynatrace-filters` | `\| filter startsWith(class, "com.sellerportal") or startsWith(class, "com.atg")` and `\| filter k8s.namespace.name == "seller-portal"` |
| `ticket-prefixes` | `WBPR-*`, `SP2-*` |
| `service-start` | `cd wavebid-a2o-service && ./gradlew bootRun &`, poll `http://localhost:8080/actuator/health` every 5s up to 120s, then fail with the last Gradle lines |

## Quality gates

| Step | Gate | Command | Working dir | On failure |
|---|---|---|---|---|
| 0 | Liquibase preflight (only when the diff or working tree touches `src/main/resources/db/changelog/`) | `./gradlew liquibaseUpdate` | `wavebid-a2o-service/` | Postgres unreachable: stop, ask the user to start it (e.g. `infra/init-dependencies.sh`) |
| 1 | Tests | `./gradlew test` | `wavebid-a2o-service/` | Schema-like signals (`PSQLException`, `BadSqlGrammarException`, `does not exist`, `relation`, `undefined_column`, `42P01`, `42703`) or mass unrelated failures suggest a stale local DB: run `liquibaseUpdate` once, re-run tests, then continue with normal fixes. Never loop it |
| 2 | Kotlin static analysis | `./gradlew detektMain detektTest` | `wavebid-a2o-service/` | Fix violations per the rule docs (`403-detekt-extra-violations.md` for Detekt extras) |
| 3 | Groovy static analysis | `./gradlew codenarcTest` | `wavebid-a2o-service/` | Fix violations per the rule docs (`101-test-patterns.md`) |
| 4 | Coverage | `./gradlew koverVerify` | `wavebid-a2o-service/` | Add tests for uncovered branches and lines; exclude only genuine infrastructure |

Coverage thresholds: ≥85% branch, ≥95% line.

## Notes

- Never pass `--no-daemon` to Gradle.
- `bin/` is gitignored under the service but not at the monorepo root, so the never-commit rule
  is behavioural, not enforced.
- Default to re-running `koverVerify`; coverage drifts silently.
- `/atg:test-run`, resolving "any existing X": prefer the `seller-portal-local` MCP tool (e.g.
  `SELECT id, name FROM seller_portal.atg_auction_house WHERE enabled = true LIMIT 1`) over the
  guide's shared-setup HTTP steps when it is available.
