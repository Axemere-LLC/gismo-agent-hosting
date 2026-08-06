# Cost

*What this repo's default configuration bills for, and when. Figures are GCP list pricing as of this
writing — always confirm current pricing and your own free-tier eligibility before relying on any
number here.*

## Table of Contents

- [The short version](#the-short-version)
- [What actually costs money](#what-actually-costs-money)
- [Why idle is ~$0](#why-idle-is-0)
- [What would break that](#what-would-break-that)
- [Recommended: a billing budget alert](#recommended-a-billing-budget-alert)

## The short version

At the defaults (`modules/gcp-cloud-run` with `min_instances = 0`, one `gcp-artifact-registry` repo
under its cleanup policy), a Gismo agent that plays a handful of matches a day costs **cents to low
single-digit dollars a month**, and **effectively $0** while it plays no matches at all. There is no
fixed monthly charge from this module set — every resource it creates is either free at this scale or
billed strictly per use.

## What actually costs money

| Resource | Billed for | Typical cost at Gismo's scale |
|---|---|---|
| Cloud Run v2 (`gcp-cloud-run`) | CPU + memory while an instance is running, plus request count | A match lasts seconds to low minutes of wall time; a few hundred matches a month is comfortably inside the [Cloud Run always-free tier](https://cloud.google.com/run/pricing) |
| Artifact Registry (`gcp-artifact-registry`) | Storage of stored image layers, beyond the free 0.5 GiB | One agent image is typically tens of MB; the module's default `keep_count = 5` cleanup policy keeps storage bounded as you push new builds |
| Secret Manager (via `secret_env`) | Per-secret-version storage + access | A single `mcp_outbound_key` secret is far below the free tier's per-month allowance |
| Cloud Build / GitHub Actions (via `gcp-cicd`) | Compute minutes to build and push your image | Zero if you build locally with `docker push`; GitHub Actions' own free minutes typically cover a small project if you use the provided workflow |

Nothing else in this repo creates a billable resource. `gcp-bootstrap` and `gcp-org-policy` touch only
project-level configuration (API enablement, IAM policy), not metered infrastructure.

## Why idle is ~$0

Cloud Run v2 with `min_instance_count = 0` allocates **zero** instances — and therefore zero CPU or
memory billing — whenever no request is in flight. A Gismo agent's endpoint sees traffic only during
an active match: the matchmaker's `initialize` probe wakes it (a cold start, typically low single-digit
seconds), it plays the match, and then it goes back to zero after Cloud Run's idle-eviction window.
Between matches — which for most agents is the overwhelming majority of the time — there is no running
instance to bill for.

This is why `min_instances` defaults to `0` rather than `1` in `modules/gcp-cloud-run`, even though
`min_instances = 1` would eliminate cold-start latency: see
[`module-contract.md`](module-contract.md#input-variables). Raise it only if cold starts are causing
forfeits your agent can't otherwise tolerate — see
[`registering-your-agent.md`](registering-your-agent.md) for how to check.

## What would break that

None of these are created by anything in this repo, but they're worth naming so you don't
accidentally add one while customizing your own deployment:

- A load balancer or static IP — Cloud Run's own `*.run.app` URL already has a free Google-managed
  TLS cert and needs neither.
- `min_instances > 0` — trades the idle-$0 property for eliminated cold starts. A deliberate choice,
  not a default.
- A database, cache, or message queue sitting behind the agent — an agent's `get_state`/`submit_orders`
  cache is in-process (see [`module-contract.md`](module-contract.md)'s `max_instances` warning); it
  needs none of these.
- Raising `max_instances` above `1` — see the same warning; it's a correctness hazard before it's a
  cost one, since Cloud Run bills idle replicas at $0 regardless of the ceiling.

## Recommended: a billing budget alert

This repo doesn't create one for you — a budget is account-level configuration, not a Cloud Run
concern — but it's the cheapest insurance available: a GCP [budget alert](https://cloud.google.com/billing/docs/how-to/budgets)
on the project this module deploys into, set to notify at a low threshold (e.g. $5), catches a runaway
loop or misbehaving cleanup policy before it becomes a surprise.
