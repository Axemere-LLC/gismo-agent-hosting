# Module contract

*The cloud-neutral variable surface every provider module in this repo implements. Pinned before any
provider-specific module is written, so `modules/gcp-cloud-run`, and later `modules/aws-app-runner` and
`modules/azure-container-apps`, all present the same shape to the caller.*

---

## Table of Contents

- [Why this exists](#why-this-exists)
- [Scope: the core module only](#scope-the-core-module-only)
- [Input variables](#input-variables)
- [Outputs](#outputs)
- [Naming rules](#naming-rules)
- [What the core module deliberately does not do](#what-the-core-module-deliberately-does-not-do)
- [Provider mapping notes](#provider-mapping-notes)

## Why this exists

This repo ships one *core* module per cloud (`gcp-cloud-run` today; `aws-app-runner` and
`azure-container-apps` follow the same contract later) plus a handful of *optional* modules
(bootstrap, registry, org policy, CI/CD) that a consumer can take or leave. The core module is the
only piece every consumer touches, so its variable names, types, and defaults are fixed here first —
independent of GCP, AWS, or Azure vocabulary — so a project that starts on one cloud and later adds a
second only has to change the module `source`, not its `.tfvars`.

A [`Strategy`](https://github.com/Axemere-LLC/gismo-agent-go#the-strategy-interface) implementation
built against `gismo-agent-go` or a hand-rolled MCP server in any language is equally welcome here —
this module hosts a container image and an HTTP endpoint, and has no opinion about what's inside it.

## Scope: the core module only

This contract covers `modules/gcp-cloud-run` and its future AWS/Azure siblings — the module that
turns one already-built container image into one reachable [agent endpoint](glossary.md#agent-endpoint).
It does not cover the optional modules (`gcp-bootstrap`, `gcp-artifact-registry`, `gcp-org-policy`,
`gcp-cicd`): those exist to remove undifferentiated setup work for a consumer with no existing GCP
project, registry, or CI pipeline, but their variables are provider-specific by nature (a project
bootstrap has no cloud-neutral equivalent) and are documented in each module's own `README.md`
instead.

## Input variables

| Variable | Type | Default | Required | Notes |
|---|---|---|---|---|
| `project_id` | `string` | — | yes | Cloud project/account identifier. GCP: project ID. |
| `region` | `string` | `"us-central1"` | no | Cloud region to deploy into. |
| `agent_name` | `string` | — | yes | Names the service and its runtime identity. See [Naming rules](#naming-rules). |
| `image` | `string` | — | yes | Container image reference. **Must be digest-pinned** (`...@sha256:<64 hex>`), not a mutable tag — validated by the module; see [Why digest-pinning](#what-the-core-module-deliberately-does-not-do). |
| `cpu` | `string` | `"1"` | no | vCPU allocation. Providers that require CPU ≥ 1 under always-allocated billing reject fractional values here — see [`building-your-image.md`](building-your-image.md). |
| `memory` | `string` | `"512Mi"` | no | Memory allocation, `<N>Mi` or `<N>Gi`. |
| `min_instances` | `number` | `0` | no | Idle floor. `0` is true scale-to-zero — see [`cost.md`](cost.md). Raising this trades cost for eliminating cold-start latency. |
| `max_instances` | `number` | `1` | no | Concurrency ceiling. **Do not raise this** unless your agent's state is safe to shard across instances — see the warning below. |
| `request_timeout_seconds` | `number` | `300` | no | Per-request timeout at the platform edge. |
| `concurrency` | `number` | `80` | no | Max in-flight requests per instance. |
| `env` | `map(string)` | `{}` | no | Plain (non-secret) environment variables passed to the container. |
| `secret_env` | `map(string)` | `{}` | no | Environment variables sourced from the provider's secret store instead of literal values. Key is the env var name; value is the provider-specific secret reference (e.g. a GCP Secret Manager secret ID). Use this for an outbound bearer key, never `env`. |
| `public_invoker` | `bool` | `true` | no | Whether the endpoint accepts unauthenticated requests. See [Why `true` is the default](#what-the-core-module-deliberately-does-not-do). |
| `labels` | `map(string)` | `{}` | no | Provider resource labels/tags. |

> **`max_instances` is a correctness setting, not just a cost control.** An agent built on
> `gismo-agent-go` caches the state it receives from `get_state` in-process, keyed by match, so it can
> answer `submit_orders` for the same impulse without an extra round trip. If a second instance is
> running, a `submit_orders` call can land on an instance that never saw the matching `get_state` —
> its cache misses, and the agent silently holds every tank that impulse. Raise `max_instances` only
> if your own `Strategy` implementation is stateless or shares state externally.

## Outputs

| Output | Notes |
|---|---|
| `endpoint_url` | The base `https://` URL for your service. Paste it *plus* the generation's [version path](glossary.md#version-path) (`endpoint_url` + `/v1`, `/v2`, …) into `mcp_endpoint_url` when [registering your agent](registering-your-agent.md) — the bare `endpoint_url` alone never serves MCP. |
| `service_name` | Provider-native resource name, for lookups outside this module (logs, dashboards). |
| `service_account_email` | The runtime identity the container runs as. Grant it further provider permissions only if your agent needs them — the module grants none beyond what running the container requires. |

## Naming rules

`agent_name` derives every resource name the module creates (service, runtime service account,
default labels). Keep it:

- lowercase, alphanumeric plus `-`
- starting with a letter
- short enough that provider-specific suffixes (e.g. a service-account ID's 30-character ceiling on
  GCP) still fit

The module validates this once, in the core module, rather than relying on each provider's own error
message.

## What the core module deliberately does not do

- **No mutable image tags.** `image` must resolve to an immutable digest. A `:latest` or branch-name
  tag means a cold start after the tag moves silently serves different code than the last deploy
  reviewed — digest-pinning makes `tofu plan` show exactly the change being applied, the same
  discipline the SDKs use for their own version pins.
- **No IAM auth in front of the endpoint by default (`public_invoker = true`).** A Gismo referee
  authenticates to your agent with a bearer key it sets as the `Authorization` header — see
  `gismo-agent-go`'s `agent.NewServer` and the referee's outbound auth round-tripper. A
  provider-native auth layer (Google ID tokens, IAM SigV4, etc.) would try to occupy that same header
  and the two schemes cannot coexist. Authenticate in your own MCP handler instead, using
  `secret_env` to supply the key it checks against. This is safe specifically because the agent holds
  no data of its own to protect — an unauthenticated caller can only make it think about a fake
  battlefield.
- **No load balancer, no static IP, no custom domain, no database, no queue.** An agent is a single
  stateless-between-matches HTTP endpoint; every one of those adds idle cost this module exists to
  avoid. See [`cost.md`](cost.md).
- **No apply from CI.** This repo's own CI (`.github/workflows/ci.yml`) runs `fmt`/`validate` only.
  Applying is always a human, local `tofu apply` against reviewed `tofu plan` output.

## Provider mapping notes

Notes for implementing a new core module against this contract:

| Concept | GCP (`gcp-cloud-run`) | AWS (`aws-app-runner`, planned) | Azure (`azure-container-apps`, planned) |
|---|---|---|---|
| Compute primitive | Cloud Run v2 service | App Runner service | Container App |
| Scale-to-zero | `min_instance_count = 0` | Not natively supported by App Runner — evaluate Lambda-backed alternative before implementing | `min_replicas = 0` |
| Secret ref | Secret Manager secret ID | Secrets Manager ARN | Key Vault reference |
| Public invoke | `roles/run.invoker` → `allUsers` | Public endpoint, IAM-optional | Ingress `external = true` |

The AWS scale-to-zero gap is a known open question — App Runner has no zero-instance floor, so
`aws-app-runner` may need a different underlying primitive to honor `min_instances = 0` at true $0
idle cost. This will be resolved when that module is built (see the repo root `README.md` roadmap),
not guessed at here.
