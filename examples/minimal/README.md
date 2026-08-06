# examples/minimal

For a project that already exists: an existing GCP project (billing linked, `run.googleapis.com`
enabled) and an image already built and pushed somewhere the project can pull from (this repo's own
registry or any other). One module call.

## Try it

```bash
tofu init
tofu plan \
  -var="project_id=my-existing-project" \
  -var="image=us-central1-docker.pkg.dev/my-existing-project/my-repo/agent@sha256:<digest>"
tofu apply # same -var flags
```

Then paste the `endpoint_url` output into your agent version's `mcp_endpoint_url` — see
[`../../docs/registering-your-agent.md`](../../docs/registering-your-agent.md).

See [`../greenfield`](../greenfield) instead if you're starting from nothing — no project, no
registry, no CI.
