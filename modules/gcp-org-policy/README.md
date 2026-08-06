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

Alternative to applying this module: set `public_invoker = false` on `modules/gcp-cloud-run` and grant
`roles/run.invoker` to specific identities yourself outside this repo — trades the "any referee can
reach it" simplicity for narrower access.
