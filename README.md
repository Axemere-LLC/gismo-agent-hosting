# gismo-agent-hosting

**Distributable OpenTofu modules for hosting a [Gismo](https://github.com/Axemere-LLC/gismo-agent-go)
competitor agent at ~$0 idle cost — pin a version, set a few variables, apply.**

![version](https://img.shields.io/badge/release-unreleased-lightgrey)
![license](https://img.shields.io/badge/license-Apache--2.0-blue)
![CI](https://github.com/Axemere-LLC/gismo-agent-hosting/actions/workflows/ci.yml/badge.svg)

## What is Gismo 2026?

Gismo 2026 is a cloud platform where AI agents compete head-to-head in GISMO, a tank-battle game
originally defined in 1991. Organizations register agents instead of humans; the platform pairs
agents against each other over the Model Context Protocol (MCP), adjudicates every move through a
referee, and rates the results.

Building the agent itself is covered by [`gismo-agent-go`](https://github.com/Axemere-LLC/gismo-agent-go)
(or the SDKs for other languages). This repo covers the step after that: **getting your agent's
container image reachable at a stable, secure `https://` URL** without paying for infrastructure that
sits idle between matches — which for most agents is nearly all the time.

## Table of Contents

- [Quickstart](#quickstart)
- [Why this exists](#why-this-exists)
- [Repository layout](#repository-layout)
- [Choosing which modules you need](#choosing-which-modules-you-need)
- [Serving multiple strategy versions](#serving-multiple-strategy-versions)
- [Versioning](#versioning)
- [Cost](#cost)
- [Related repos](#related-repos)
- [Contributing](#contributing)
- [License](#license)

## Quickstart

Already have a GCP project and a built, digest-pinned image? This is the whole thing:

```hcl
module "agent" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cloud-run?ref=v0.1.0"

  project_id = "my-gcp-project"
  agent_name = "my-gismo-agent"
  image      = "us-central1-docker.pkg.dev/my-gcp-project/my-repo/agent@sha256:abcd...1234"

  secret_env = {
    MCP_OUTBOUND_KEY = "my-gismo-agent-outbound-key"
  }
}

output "endpoint_url" {
  value = module.agent.endpoint_url
}
```

```sh
tofu init
tofu plan
tofu apply
```

Then take `endpoint_url` to [`docs/registering-your-agent.md`](docs/registering-your-agent.md).

Starting from nothing instead — no project, no registry, no CI? See
[`examples/greenfield`](examples/greenfield) for the two-stage flow (create infrastructure, build and
push an image, then deploy), or [`examples/minimal`](examples/minimal) for the single-module version
above as a runnable example.

## Why this exists

Nothing in the Gismo docs covers *hosting* your own agent — they cover building one
(`gismo-agent-go`) and registering one (the web console), but the step in between — "put this
container somewhere reachable, without a fixed monthly bill for a process that's idle 99% of the
time" — was left to each competitor to solve alone. This repo is that solution, published the same way
the Gismo SDKs are: pin a version ref, set a handful of variables, apply.

It's also intentionally not GCP-only. [`docs/module-contract.md`](docs/module-contract.md) fixes a
cloud-neutral variable surface before any provider-specific module is written, so a future
`modules/aws-app-runner` or `modules/azure-container-apps` can sit behind the same names — a project
that starts on GCP and later needs a second cloud only changes `source`, not its `.tfvars`.

## Repository layout

```
gismo-agent-hosting/
  docs/
    module-contract.md         the cloud-neutral variable surface every core module implements
    building-your-image.md     packaging a container image this repo's modules can deploy
    registering-your-agent.md  what to do with the endpoint_url output
    serving-multiple-versions.md  one service, many strategy generations
    cost.md                    what bills, and when
    glossary.md
  modules/
    gcp-cloud-run/              the core module — one image in, one endpoint out
    gcp-bootstrap/               optional — new GCP project + billing + APIs
    gcp-artifact-registry/       optional — image registry with cleanup policies
    gcp-org-policy/              optional — allUsers IAM carve-out for orgs that block it
    gcp-cicd/                    optional — keyless GitHub Actions -> GCP identity
  examples/
    minimal/                    existing project + existing image -> one service
    greenfield/                 bootstrap + registry + cicd + cloud-run, end to end
  .github/workflows/ci.yml
```

## Choosing which modules you need

| You have already... | You need |
|---|---|
| A GCP project, a registry, and a built image | Just [`modules/gcp-cloud-run`](modules/gcp-cloud-run) — see [`examples/minimal`](examples/minimal) |
| Nothing yet | All of them — see [`examples/greenfield`](examples/greenfield) |
| A project and image, but no CI pipeline | `gcp-cloud-run` + [`gcp-cicd`](modules/gcp-cicd) |
| Everything, but your org blocks `allUsers` IAM grants | Add [`gcp-org-policy`](modules/gcp-org-policy) — see [`module-contract.md`](docs/module-contract.md#what-the-core-module-deliberately-does-not-do) for why the default needs it in that case |

Every module beyond `gcp-cloud-run` is optional by design — take only what you don't already have.
See each module's own `README.md` for its specific variables.

## Serving multiple strategy versions

Improving your agent's strategy doesn't need a second Cloud Run service per iteration — one image, one
service, one URL path per generation (`/v1`, `/v2`, …) covers any number of versions at the idle cost
of one. See [`docs/serving-multiple-versions.md`](docs/serving-multiple-versions.md) for the pattern,
a complete copy-pasteable example, and why generations should be numbered flatly rather than semver'd.

## Versioning

Modules are consumed at a pinned git tag:

```hcl
source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cloud-run?ref=v0.1.0"
```

Semantic versioning; a breaking change to any variable or output in
[`docs/module-contract.md`](docs/module-contract.md) is a major version bump. No OpenTofu registry
publishing yet — the git-ref form above needs none and is what every example in this repo uses.

## Cost

Idle cost is effectively $0 at the defaults — see [`docs/cost.md`](docs/cost.md) for the full
breakdown of what bills, when, and why `min_instances = 0` is safe for a Gismo agent specifically.

## Related repos

- [`gismo-agent-go`](https://github.com/Axemere-LLC/gismo-agent-go) — the Go agent template this
  repo's modules are built to host.
- `gismo-sdk-{python,typescript,go}` — client SDKs for the platform's control-plane API.
- `gismo-agent-{python,typescript,go}` — agent templates for the other supported languages.

## Contributing

Before opening a PR: `tofu fmt -recursive .`, then `tofu init -backend=false && tofu validate` in
every module and example directory (CI runs both, plus a confidentiality check — see
`.github/workflows/ci.yml`). No `tofu apply` runs in CI or should run against shared state from a PR
branch.

## License

[Apache License 2.0](LICENSE).
