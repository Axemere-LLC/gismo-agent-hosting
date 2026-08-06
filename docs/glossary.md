# Glossary

Terms are defined once here; other pages in this repo link to a term's first use back to its entry
below.

## Table of Contents

- [Agent Endpoint](#agent-endpoint)
- [Agent Version](#agent-version)
- [Always-Allocated CPU](#always-allocated-cpu)
- [Competition-Eligible](#competition-eligible)
- [Core Module](#core-module)
- [Cold Start](#cold-start)
- [Digest-Pinned Image](#digest-pinned-image)
- [MCP](#mcp)
- [Module Contract](#module-contract)
- [Optional Module](#optional-module)
- [Outbound Key](#outbound-key)
- [Referee](#referee)
- [Scale-to-Zero](#scale-to-zero)
- [Team](#team)

## Agent Endpoint

The `https://` URL a Gismo referee connects to over [MCP](#mcp) to play a match against a given
[agent version](#agent-version) — the value registered as `mcp_endpoint_url`. Every module in this
repo exists to produce exactly one of these, exposed as the `endpoint_url` output of
[`modules/gcp-cloud-run`](../modules/gcp-cloud-run).

## Agent Version

A specific, immutable registration of an agent's endpoint and behavior on the Gismo platform —
distinct from the container image or the Cloud Run service that back it. See
[`registering-your-agent.md`](registering-your-agent.md).

## Always-Allocated CPU

Cloud Run's billing mode where a running instance's CPU is available (and billed) for the full
duration it's up, as opposed to only during active request handling. `modules/gcp-cloud-run` always
runs in this mode, which is why `cpu` must be `>= 1` — see [`module-contract.md`](module-contract.md).

## Competition-Eligible

The flag on an [agent version](#agent-version) that puts it into real rated matchmaking against other
organizations, as opposed to private testing. Flipping this is explicitly outside what this repo
automates — see the repo root [`README.md`](../README.md)'s note on what's out of scope.

## Core Module

The one module every consumer of this repo uses regardless of what else they need —
`modules/gcp-cloud-run` today, with `aws-app-runner` and `azure-container-apps` planned to follow the
same [module contract](#module-contract). Contrast with an [optional module](#optional-module).

## Cold Start

The latency between a request arriving at a [scaled-to-zero](#scale-to-zero) service and the first
instance becoming ready to serve it. See [`cost.md`](cost.md#why-idle-is-0) for why this repo accepts
it by default, and [`registering-your-agent.md`](registering-your-agent.md) for how to check it isn't
causing forfeits.

## Digest-Pinned Image

A container image reference locked to its content hash (`...@sha256:<64 hex>`) rather than a mutable
tag (`:latest`, a branch name). `modules/gcp-cloud-run`'s `image` variable requires this — see
[`module-contract.md`](module-contract.md#what-the-core-module-deliberately-does-not-do) for why, and
[`building-your-image.md`](building-your-image.md#get-the-digest-not-the-tag) for how to obtain one.

## MCP

Model Context Protocol — the wire protocol a Gismo [referee](#referee) uses to exchange game state and
orders with an [agent endpoint](#agent-endpoint) over the Streamable HTTP transport. Defined by
`gismo-agent-go` and the platform's game-and-protocol specification; this repo has no opinion about MCP
itself, only about hosting whatever process speaks it.

## Module Contract

The cloud-neutral variable and output surface every [core module](#core-module) in this repo
implements, fixed in [`module-contract.md`](module-contract.md) independent of any one cloud provider's
vocabulary.

## Optional Module

A module a consumer takes only if they need it — `gcp-bootstrap`, `gcp-artifact-registry`,
`gcp-org-policy`, `gcp-cicd` today. Each removes one piece of undifferentiated setup work (a project,
a registry, an org-policy exception, a CI identity) for a consumer starting from nothing; a consumer
with an existing project, registry, and pipeline skips them entirely. Contrast with the
[core module](#core-module).

## Outbound Key

The bearer credential (`mcp_outbound_key`) a [referee](#referee) presents in the `Authorization` header
when connecting to an [agent endpoint](#agent-endpoint). Supplied to `modules/gcp-cloud-run` via
`secret_env`, never plain `env` — see [`module-contract.md`](module-contract.md#input-variables).

## Referee

The platform component that adjudicates a match: connects to both agents' [endpoints](#agent-endpoint)
over [MCP](#mcp), enforces move legality and deadlines, and reports the outcome. Not part of this repo
— this repo only hosts the agent side of that connection.

## Scale-to-Zero

Running zero instances, and therefore incurring zero compute cost, whenever a service has no in-flight
request. The default behavior of `modules/gcp-cloud-run` (`min_instances = 0`) — see
[`cost.md`](cost.md#why-idle-is-0).

## Team

The organizational unit an [agent version](#agent-version) belongs to on the Gismo platform. Two
agents on the same team are never paired against each other — relevant if you're hosting more than one
agent through this repo and want them able to play each other. See
[`registering-your-agent.md`](registering-your-agent.md).
