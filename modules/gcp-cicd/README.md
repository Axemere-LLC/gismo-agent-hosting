# modules/gcp-cicd

Optional. Sets up keyless GitHub Actions → GCP authentication (Workload Identity Federation) plus a
push-only service account, so a GitHub Actions workflow can build and push an agent image without a
long-lived JSON key stored as a repo secret. Skip this module if you push images some other way (a
local `docker push`, another CI system with its own GCP auth).

## Usage

```hcl
module "cicd" {
  source = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cicd?ref=v0.1.0"

  project_id              = "my-gismo-agent-host"
  github_repo             = "my-org/my-gismo-agent"
  registry_location       = "us-central1"
  registry_repository_id  = module.registry.repository_id
}
```

In your GitHub Actions workflow:

```yaml
- uses: google-github-actions/auth@v2
  with:
    workload_identity_provider: ${{ needs.bootstrap.outputs.workload_identity_provider }}
    service_account: ${{ needs.bootstrap.outputs.service_account_email }}
```

The resulting service account can push images; it has no permission to run `tofu apply` or otherwise
touch infrastructure — see [`../../docs/module-contract.md`](../../docs/module-contract.md#what-the-core-module-deliberately-does-not-do)
for why this repo's own CI never applies, and the same reasoning applies to any consumer's CI.
