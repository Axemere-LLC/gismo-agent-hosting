# Building your image

*How to get a container image into the digest-pinned shape `modules/gcp-cloud-run` requires. Agent
logic itself — the `Strategy` interface, the MCP wire format — belongs to
[`gismo-agent-go`](https://github.com/Axemere-LLC/gismo-agent-go) and friends, not this repo; this page
covers only the packaging and deployment side.*

## Table of Contents

- [Listen on `$PORT`, not a hardcoded address](#listen-on-port-not-a-hardcoded-address)
- [Build for `linux/amd64`](#build-for-linuxamd64)
- [Get the digest, not the tag](#get-the-digest-not-the-tag)
- [Push to a registry the project can pull from](#push-to-a-registry-the-project-can-pull-from)
- [Full example](#full-example)

## Listen on `$PORT`, not a hardcoded address

Cloud Run injects the port your container must listen on as the `PORT` environment variable — it does
not always default to `8080` in every configuration, so relying on a hardcoded address is fragile.
`gismo-agent-go`'s `agent.DefaultAddr(fallback)` reads `PORT` when set and falls back to the given
address otherwise, which is exactly the shape `modules/gcp-cloud-run` expects:

```go
addr := flag.String("addr", agent.DefaultAddr(":8080"), "address to listen on")
```

Every template — `gismo-agent-go`'s root `main.go` and its `examples/*/cmd/main.go`, plus
`gismo-agent-python`'s `main.py` and `gismo-agent-typescript`'s `src/main.ts` — already wires this in
via that language's equivalent helper (`default_addr`/`defaultAddr`). If you're hand-rolling an MCP
server in another language, listen on `$PORT` when it's set.

## Build for `linux/amd64`

Cloud Run runs `linux/amd64` (or `linux/arm64` if you opt in — this module doesn't). Building on an
Apple Silicon or other non-amd64 machine without specifying the target platform produces an image
Cloud Run can't run:

```sh
docker buildx build --platform linux/amd64 -t <local-tag> .
```

`gismo-agent-go`'s own `Dockerfile` (multi-stage, `golang:1.26` builder →
`distroless/static-debian12:nonroot` runtime, `CGO_ENABLED=0`) is a reasonable starting point if you're
building a Go agent — see that repo's `Dockerfile` for the exact stages.

## Get the digest, not the tag

`modules/gcp-cloud-run`'s `image` variable is validated to reject anything that isn't pinned to a
`@sha256:<64 hex>` digest — see [`module-contract.md`](module-contract.md#what-the-core-module-deliberately-does-not-do)
for why. After pushing, resolve the digest of what you actually pushed rather than trusting a tag:

```sh
docker push <registry>/<repo>/agent:<your-tag>
docker inspect --format='{{index .RepoDigests 0}}' <registry>/<repo>/agent:<your-tag>
# -> <registry>/<repo>/agent@sha256:...
```

Or, if your registry supports it, `gcloud artifacts docker images describe <image>:<tag> --format='value(image_summary.digest)'`
against a GCP Artifact Registry image.

## Push to a registry the project can pull from

If you're using [`modules/gcp-artifact-registry`](../modules/gcp-artifact-registry) from this repo,
its `repository_url` output is the push target:

```sh
gcloud auth configure-docker <region>-docker.pkg.dev
docker tag <local-tag> <repository_url>/agent:<your-tag>
docker push <repository_url>/agent:<your-tag>
```

The Cloud Run service's runtime service account (this module's `service_account_email` output) needs
no explicit pull grant for a same-project Artifact Registry repo — Cloud Run's default service agent
handles the pull. A registry in a *different* project needs an explicit `roles/artifactregistry.reader`
grant to that service account, which this module does not create for you.

If you'd rather automate the build-and-push step instead of running it locally, see
[`modules/gcp-cicd`](../modules/gcp-cicd) for a GitHub Actions-driven path using keyless Workload
Identity Federation.

## Full example

```sh
docker buildx build --platform linux/amd64 -t agent:local .
docker tag agent:local us-central1-docker.pkg.dev/my-project/gismo-agents/agent:local
docker push us-central1-docker.pkg.dev/my-project/gismo-agents/agent:local
digest=$(gcloud artifacts docker images describe \
  us-central1-docker.pkg.dev/my-project/gismo-agents/agent:local \
  --format='value(image_summary.digest)')
echo "us-central1-docker.pkg.dev/my-project/gismo-agents/agent@${digest}"
# -> paste this into your `tofu apply -var="image=..."`
```

Once applied, take the module's `endpoint_url` output to
[`registering-your-agent.md`](registering-your-agent.md).
