# {{Name}} runbook

- **Status:** Draft
- **Last reviewed:** [fill in: YYYY-MM-DD]

How to operate {{Name}} once it's deployed. "Where it runs" is the reference the other sections use; each section after it is one task, written as steps to follow. The kit's rule OPS-004 (`docs/standards/operations.md`) says what this file needs, and `./.kit/tools/Test-Runbook.ps1` checks it in CI.

Before {{Name}}'s first production deployment, replace every `[fill in: ...]` with this app's own steps, and set the status to `In use`. From then on, CI fails on any placeholder left. Review this file whenever how the app is deployed, hosted or stores data changes, and update the review date. Never write a secret here: name where it's kept, never its value.

## Where it runs

| Environment | URL | Hosting | Data store |
|---|---|---|---|
| Staging | [fill in: the staging URL] | [fill in: the service and resource names] | [fill in: the database and its server] |
| Production | [fill in: the production URL] | [fill in: the service and resource names] | [fill in: the database and its server] |

- **Who can deploy, and who has access to production:** [fill in: the people or groups]
- **Where its secrets are kept:** [fill in: the vault or settings that hold them, and their names]
- **Where its telemetry goes:** [fill in: the OpenTelemetry backend, and how to open it]

## How to deploy a release

1. Check that CI passed on the commit you're releasing.
2. Deploy it to staging: [fill in: the workflow or command].
3. Check staging's health (see "How to check its health").
4. Promote the same build to production: [fill in: the production workflow and how to start it, kit ADR-0023].
5. Check production's health, then watch its error rate and latency (see "How to read its telemetry") for [fill in: how long] before you call the release done.

## How to roll back a release

Roll back to the last known good release: the last one that was healthy in production.

1. Find the last known good release: [fill in: where releases and their builds are listed].
2. If the release you're leaving changed the database schema, check that the last known good release still works with the new schema. If it doesn't, restore the data first (see "How to restore its data").
3. Redeploy the last known good build: [fill in: the workflow or command, and how to pass it the version].
4. Check production's health and telemetry.
5. Record the rollback as an incident (see "How to respond to an incident").

## How to check its health

Every kit web app answers on two endpoints (OPS-002) with an HTTP status and the status word alone: `200 Healthy` or `200 Degraded`, `503 Unhealthy`, or `504`, without the word, when a check was too slow and was cut off. A `Healthy` answer is cached for 10 seconds, so wait that long before checking again after a fix.

1. Check that the app is alive, which runs only the checks tagged `live` and never touches the database:

   ```powershell
   $r = Invoke-WebRequest -Uri '[fill in: the production URL]/alive' -SkipHttpErrorCheck; "$($r.StatusCode) $($r.Content)"
   ```

2. Check that it's ready to serve, which runs every check, the database's included:

   ```powershell
   $r = Invoke-WebRequest -Uri '[fill in: the production URL]/health' -SkipHttpErrorCheck; "$($r.StatusCode) $($r.Content)"
   ```

3. If `/alive` fails, the process is stuck or down: [fill in: how to see the hosting's restarts and logs]. If only `/health` fails, a dependency is down or slow: find which check failed in the logs (see "How to read its telemetry").
4. Check that the hosting's probes and alerts use these endpoints: [fill in: where they're set up].

## How to read its telemetry

{{Name}} sends logs, metrics and traces through OpenTelemetry (OPS-001) to the endpoint in `OTEL_EXPORTER_OTLP_ENDPOINT`.

1. Open the telemetry backend: [fill in: its URL, and who can sign in].
2. To follow one failed request, find its trace, then open the logs that carry the same trace ID.
3. To see how the app is doing overall, chart the request rate, error rate and latency from the `http.server.request.duration` metric.
4. If no telemetry arrives, check that `OTEL_EXPORTER_OTLP_ENDPOINT` is set in that environment: without it, the app exports nothing.

## How to restore its data

If {{Name}} keeps no data, replace these steps with "{{Name}} keeps no data" and why.

1. Find the backup to restore from: [fill in: where backups are, how often they're taken, and how long they're kept].
2. Stop writes, so nothing is lost in the switch: [fill in: how, for example by scaling the app to zero].
3. Restore to a new database at the point in time you need: [fill in: the command or portal steps].
4. Point the app at the restored database: [fill in: the setting to change].
5. Check its health, then check that a record you know about is there.
6. Practise this on staging before the first production deployment, and again after each change to the data store.

## How to respond to an incident

1. Confirm the impact: check health and telemetry, and note when it started.
2. Tell [fill in: who must know, and where] that you're on it, and post an update every [fill in: interval] until it's over.
3. If a secret leaked, revoke and rotate it first: [fill in: where each secret is rotated].
4. If it started with a release, roll back (see "How to roll back a release"). Otherwise, [fill in: the first steps for this app's likely failures, such as its database or a service it calls].
5. When it's resolved, watch health and telemetry until they've stayed normal for [fill in: how long], then say so where you posted updates.
6. Within [fill in: how many days], write a blameless postmortem in [fill in: where]: what happened, when, why, and the fixes, each tracked as an issue.
