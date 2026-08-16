# Quickstart: zero to a deployed, registered agent

*One linear path from "I picked a language" to "my agent is playing a training match." Covers GCP
only — this repo's cloud-neutral [module contract](module-contract.md) means the AWS and Azure
versions of step 4 will read the same everywhere else once those modules land; see
[`module-contract.md`'s provider mapping notes](module-contract.md#provider-mapping-notes) for
status. If you already know the individual pieces (`building-your-image.md`, `module-contract.md`,
`registering-your-agent.md`), this page just orders them.*

## Table of Contents

- [What you need before starting](#what-you-need-before-starting)
- [1. Pick a template, clone it, run it locally](#1-pick-a-template-clone-it-run-it-locally)
- [2. Implement your `Strategy`](#2-implement-your-strategy)
- [3. Build and digest-pin the image](#3-build-and-digest-pin-the-image)
- [4. Deploy with `modules/gcp-cloud-run`](#4-deploy-with-modulesgcp-cloud-run)
- [5. Register the endpoint](#5-register-the-endpoint)
- [6. Run a training match and watch it](#6-run-a-training-match-and-watch-it)
- [What's next](#whats-next)

## What you need before starting

- A GCP project with billing enabled, plus somewhere to push a container image. If you don't have
  either yet, use [`examples/greenfield`](../examples/greenfield) instead of this page's step 4 — it
  chains [`gcp-bootstrap`](../modules/gcp-bootstrap) and
  [`gcp-artifact-registry`](../modules/gcp-artifact-registry) in front of the same deploy step.
- `docker`, `tofu` (this repo uses [OpenTofu](https://opentofu.org/), not Terraform), and `gcloud`
  installed locally.
- A [Team](glossary.md#team) on the Gismo platform to register the agent under.

## 1. Pick a template, clone it, run it locally

Three templates, one behavior each — pick the language you're most comfortable with:

| Template | Local run |
|---|---|
| [`gismo-agent-go`](https://github.com/Axemere-LLC/gismo-agent-go) | `go run . -addr :8080` |
| [`gismo-agent-python`](https://github.com/Axemere-LLC/gismo-agent-python) | `python main.py -addr :8080` |
| [`gismo-agent-typescript`](https://github.com/Axemere-LLC/gismo-agent-typescript) | `npm run build && node dist/src/main.js -addr :8080` |

Clone (or use as a template repo on GitHub) whichever one you picked, then run its local command.
Each template ships with a working `HoldStrategy` out of the box, so this step should give you a
listening [MCP](glossary.md#mcp) server with no changes at all — confirm that before moving on.

## 2. Implement your `Strategy`

Every template exposes exactly one extension point: a `Strategy` that turns a state view into orders.
Everything else — the MCP server, state caching, wire encoding — is handled by the template's own
package and doesn't need to change.

| Template | Interface | Method |
|---|---|---|
| Go | [`agent/strategy.go:12`](https://github.com/Axemere-LLC/gismo-agent-go/blob/main/agent/strategy.go#L12) | `Decide(view mcpsdk.StateView) []mcpsdk.TankOrder` |
| Python | [`gismo_agent/strategy.py:8`](https://github.com/Axemere-LLC/gismo-agent-python/blob/main/gismo_agent/strategy.py#L8) | `decide(self, view: StateView) -> list[TankOrder]` |
| TypeScript | [`src/agent/strategy.ts:9`](https://github.com/Axemere-LLC/gismo-agent-typescript/blob/main/src/agent/strategy.ts#L9) | `decide(view: mcp.StateView): mcp.TankOrder[]` |

Write your own implementation, then wire it in place of the template's `HoldStrategy` (each README's
"Deploy it" section links to the exact call site). Run the template's own test suite
(`go test ./...`, `pytest`, or `npm test`) before moving on — this quickstart doesn't add test
coverage beyond what each template already ships.

## 3. Build and digest-pin the image

Full details, including the `linux/amd64` requirement and why a mutable tag isn't accepted, live in
[`building-your-image.md`](building-your-image.md). Short version:

```bash
docker buildx build --platform linux/amd64 -t <region>-docker.pkg.dev/<project-id>/<repo>/agent:latest .
docker push <region>-docker.pkg.dev/<project-id>/<repo>/agent:latest
gcloud artifacts docker images describe <region>-docker.pkg.dev/<project-id>/<repo>/agent:latest \
  --format='value(image_summary.digest)'
```

Combine the repository path with the digest the last command prints — you'll pass
`...@sha256:<digest>` as the `image` variable in the next step, never the mutable `:latest` tag.

## 4. Deploy with `modules/gcp-cloud-run`

The full variable and output surface is documented in [`module-contract.md`](module-contract.md); this
step covers the two things a newcomer trips on that aren't obvious from the variable table alone.

**The referee authenticates to your agent, not the other way around.** Set an outbound key via
`secret_env`, never `env` — `secret_env` takes a Secret Manager secret ID, so the key value itself
never appears in your `.tf` files or `tofu` state as plaintext:

```bash
openssl rand -hex 32 | tr -d '\n' | gcloud secrets create my-agent-outbound-key \
  --project=<project-id> --replication-policy=automatic --data-file=-
```

Then deploy:

```hcl
module "agent" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cloud-run?ref=v0.1.0"

  project_id = "<project-id>"
  region     = "us-central1"
  agent_name = "my-agent"
  image      = "<region>-docker.pkg.dev/<project-id>/<repo>/agent@sha256:<digest>"

  secret_env = {
    MCP_OUTBOUND_KEY = "my-agent-outbound-key"
  }
}
```

```bash
tofu init
tofu plan
tofu apply
```

**The module creates the runtime service account, but not the IAM grant on your secret** — it only
takes a `secret_env` *reference*, and deliberately doesn't manage secret values or their access
policy (see [`module-contract.md`'s "What the core module deliberately does not
do"](module-contract.md#what-the-core-module-deliberately-does-not-do)). Grant access once the apply
above has produced the `service_account_email` output:

```bash
gcloud secrets add-iam-policy-binding my-agent-outbound-key \
  --project=<project-id> \
  --member="serviceAccount:$(tofu output -raw service_account_email)" \
  --role=roles/secretmanager.secretAccessor
```

Skipping this grant doesn't fail `tofu apply` — Cloud Run will fail to start the revision when it
tries to resolve the secret at runtime, so if the deploy "succeeds" but the endpoint won't come up,
this is the first thing to check.

If your org enforces Domain Restricted Sharing, `tofu apply` may reject the module's default
`public_invoker = true` — see [`modules/gcp-org-policy`](../modules/gcp-org-policy) for the carve-out,
same as [`examples/greenfield`](../examples/greenfield) covers.

Note `tofu output -raw endpoint_url` — you'll need it in the next step.

## 5. Register the endpoint

Full flow, including the endpoint URL's validation rules and how to test before going
[competition-eligible](glossary.md#competition-eligible), lives in
[`registering-your-agent.md`](registering-your-agent.md). Short version: sign in to the Gismo web
console, under your Team go to Agents → Register agent → New version, and paste in:

- **MCP endpoint URL** — the `endpoint_url` output from step 4. A `*.run.app` URL already satisfies
  every constraint the console checks (HTTPS, no embedded credentials, no private/loopback address).
- **Outbound key** — the same value you generated in step 4, not the secret *ID* — paste the actual
  hex string you piped into `gcloud secrets create`.

Save the one-time API key the console shows you. Leave `competition_eligible` off for now.

## 6. Run a training match and watch it

From the Training tab, start a match against a house reference agent. Watch it live at
`https://gismo.axemere.ai/watch/<match-id>`.

Confirm the match ends with a normal end reason, not a forfeit — one slow response during the initial
MCP `initialize` handshake (a Cloud Run cold start) is expected and absorbed, but repeated missed
2-second deadlines during play means the deploy isn't healthy yet. Once you've seen a clean match,
flip `competition_eligible` on.

## What's next

- Deploying a second version of the same agent, or a second agent entirely, without breaking this
  one: [`registering-your-agent.md`](registering-your-agent.md#hosting-more-than-one-version-of-the-same-agent)
  and [`docs/serving-multiple-versions.md`](serving-multiple-versions.md).
- Cost expectations for an idle-most-of-the-time agent: [`cost.md`](cost.md).
- AWS and Azure versions of step 4, once those modules land — see
  [`module-contract.md`'s provider mapping notes](module-contract.md#provider-mapping-notes).
