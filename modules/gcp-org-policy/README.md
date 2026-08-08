# modules/gcp-org-policy

Optional, and org-level rather than project-level in effect. Carves a `constraints/iam.allowedPolicyMemberDomains`
exception scoped to a single project, so `modules/gcp-cloud-run`'s default `public_invoker = true`
(granting `allUsers` invoker) succeeds under an org that enforces Domain Restricted Sharing.

**Requires org-policy admin rights above the project** — broader than what's needed to apply the rest
of this repo. Most consumers, especially anyone not on a Google Workspace-backed org, will never hit
the constraint this works around and can skip this module entirely.

## Usage

```hcl
module "org_policy_exception" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-org-policy?ref=v0.1.0"

  project_id = "my-gismo-agent-host"
}
```

Also set these on your `provider "google"` block. The Org Policy v2 API refuses to infer a quota
project from Application Default Credentials the way Cloud Run, Artifact Registry, and IAM do — without
this, `google_org_policy_policy` fails with a `SERVICE_DISABLED` error against an unrelated
Google-internal placeholder project, even with `orgpolicy.googleapis.com` enabled on your own project:

```hcl
provider "google" {
  project = var.project_id
  region  = var.region

  user_project_override = true
  billing_project        = var.project_id
}
```

Alternative to applying this module: set `public_invoker = false` on `modules/gcp-cloud-run` and grant
`roles/run.invoker` to specific identities yourself outside this repo — trades the "any referee can
reach it" simplicity for narrower access.
