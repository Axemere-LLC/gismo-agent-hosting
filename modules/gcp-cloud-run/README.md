# modules/gcp-cloud-run

The core module: turns one digest-pinned container image into one reachable, scale-to-zero Gismo
agent endpoint on Cloud Run v2. See [`../../docs/module-contract.md`](../../docs/module-contract.md)
for the full variable reference and design rationale — this file is a quickstart only.

## Usage

```hcl
module "agent" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cloud-run?ref=v0.1.0"

  project_id = "my-gcp-project"
  agent_name = "my-gismo-agent"
  image      = "us-central1-docker.pkg.dev/my-gcp-project/my-repo/agent@sha256:abcd...1234"

  secret_env = {
    MCP_OUTBOUND_KEY = "my-gismo-agent-outbound-key" # Secret Manager secret ID
  }
}

output "endpoint_url" {
  value = module.agent.endpoint_url
}
```

Prerequisites this module assumes are already in place (not created by it):

- The GCP project exists, billing is linked, and `run.googleapis.com` / `iam.googleapis.com` are
  enabled — see [`../gcp-bootstrap`](../gcp-bootstrap) if you need to create these.
- The image already exists at the given digest in some registry the project can pull from — see
  [`../gcp-artifact-registry`](../gcp-artifact-registry) if you need a registry, and
  [`../../docs/building-your-image.md`](../../docs/building-your-image.md) for building and pushing
  it.
- If your org enforces `constraints/iam.allowedPolicyMemberDomains`, granting `allUsers` invoker
  (this module's default) will fail until that's relaxed for this project — see
  [`../gcp-org-policy`](../gcp-org-policy).

## What this module creates

- One dedicated `google_service_account` for the agent's runtime identity.
- One `google_cloud_run_v2_service`, scale-to-zero by default, always-allocated CPU.
- One `google_cloud_run_v2_service_iam_member` granting `allUsers` invoker, unless
  `public_invoker = false`.

Nothing else — no load balancer, no static IP, no DNS, no database. See
[`../../docs/cost.md`](../../docs/cost.md) for what this does and doesn't bill for.
