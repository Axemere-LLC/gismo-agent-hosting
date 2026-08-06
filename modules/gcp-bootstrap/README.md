# modules/gcp-bootstrap

Optional. Creates a new GCP project, links billing, and enables the APIs the other modules in this
repo need. Skip this module entirely if you're deploying into a GCP project that already exists —
`modules/gcp-cloud-run` doesn't require it.

## Usage

```hcl
module "bootstrap" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-bootstrap?ref=v0.1.0"

  project_id          = "my-gismo-agent-host"
  billing_account_id  = "012345-6789AB-CDEF01"
  org_id              = "123456789012" # or folder_id, not both
}
```

Run this as a separate `tofu apply` before the rest — a project's APIs need a moment to finish
enabling before dependent resources (like the Cloud Run API in `modules/gcp-cloud-run`) can be
created against them. See the root [`README.md`](../../README.md) quickstart for the full sequence,
and [`../../docs/cost.md`](../../docs/cost.md) for what a new project costs before anything is
deployed into it (nothing, beyond the billing account link itself).
