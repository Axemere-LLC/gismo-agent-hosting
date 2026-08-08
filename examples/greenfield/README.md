# examples/greenfield

For starting from nothing: no GCP project, no registry, no CI pipeline. Chains
`gcp-bootstrap` → `gcp-artifact-registry` → `gcp-cicd` → (optionally) `gcp-org-policy` →
`gcp-cloud-run`.

## Two-stage apply — read this before running `apply`

There's no image to deploy on your very first apply, since the registry that would hold it doesn't
exist yet. This example models that honestly instead of hiding it:

**Stage 1 — create the project, registry, and CI identity:**

```bash
tofu init
tofu apply \
  -var="project_id=my-new-gismo-agent-host" \
  -var="billing_account_id=012345-6789AB-CDEF01" \
  -var="org_id=123456789012" \
  -var="github_repo=my-org/my-gismo-agent"
```

**Between stages:** build your agent image and push it — either via the GitHub Actions workflow
authenticated through the `ci_workload_identity_provider` / `ci_service_account_email` outputs above
(see [`../../docs/building-your-image.md`](../../docs/building-your-image.md)), or with a local
`docker push` to `registry_url`. Note the resulting digest.

**Stage 2 — deploy the agent, now that an image exists:**

```bash
tofu apply \
  -var="project_id=my-new-gismo-agent-host" \
  -var="billing_account_id=012345-6789AB-CDEF01" \
  -var="org_id=123456789012" \
  -var="github_repo=my-org/my-gismo-agent" \
  -var="deploy_agent=true" \
  -var="image=us-central1-docker.pkg.dev/my-new-gismo-agent-host/gismo-agents/agent@sha256:<digest>" \
  -var="outbound_key_secret_id=my-outbound-key-secret"
```

`outbound_key_secret_id` is optional — omit it to deploy unauthenticated. To use it, create the secret
yourself first (this repo's modules deliberately don't manage secret *values*, only the reference —
see [`../../docs/module-contract.md`](../../docs/module-contract.md#what-the-core-module-deliberately-does-not-do)):

```bash
openssl rand -hex 32 | tr -d '\n' | gcloud secrets create my-outbound-key-secret \
  --project=my-new-gismo-agent-host --replication-policy=automatic --data-file=-
gcloud secrets add-iam-policy-binding my-outbound-key-secret \
  --project=my-new-gismo-agent-host \
  --member="serviceAccount:$(tofu output -raw agent_service_account_email)" \
  --role=roles/secretmanager.secretAccessor
```

The IAM grant must happen after the module creates the agent's runtime service account, so run it
once after this stage's `tofu apply`, using the same secret value you also paste into the **Outbound
key** field when registering the agent version. Then paste the `endpoint_url` output into your agent
version's `mcp_endpoint_url` — see
[`../../docs/registering-your-agent.md`](../../docs/registering-your-agent.md).

Set `needs_public_iam_exception = true` only if stage 2 fails with a policy-violation error on the
`allUsers` grant — that means your org enforces Domain Restricted Sharing; see
[`../../modules/gcp-org-policy`](../../modules/gcp-org-policy).

See [`../minimal`](../minimal) instead if you already have a project and an image.
