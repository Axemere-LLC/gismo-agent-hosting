---
name: deploy-agent
description: >
  Deploy a Gismo competitor agent (built from one of the gismo-agent-*
  templates) to a cloud provider using this repo's OpenTofu modules.
  Builds and digest-pins the container image, resolves it from the
  registry, generates a .tfvars file against docs/module-contract.md's
  variable surface, runs tofu init and tofu plan, then stops. Applying
  requires a literal typed "apply" from the user — this skill never runs
  tofu apply on its own initiative. GCP only today (modules/gcp-cloud-run);
  stops and says so if asked to target AWS or Azure before those modules
  exist. Never pushes to any git remote and never edits files outside the
  target agent's own working directory.
argument-hint: "[path-to-agent-directory] [--bump]"
disable-model-invocation: false
allowed-tools: Bash Read Grep Write Edit
---

# /deploy-agent

Takes a working `Strategy` (from `new-agent`, or hand-written) to a live, reachable
`https://` endpoint. **Stops before `tofu apply`** — provisioning real, billable cloud resources is
always a deliberate, separately-confirmed action, never something this skill does on its own
initiative. This is the same discipline
[`docs/module-contract.md`](../../docs/module-contract.md#what-the-core-module-deliberately-does-not-do)
states for this repo itself: "applying is always a human, local `tofu apply`."

**This skill only targets GCP (`modules/gcp-cloud-run`) today.** If the user asks for AWS or Azure,
stop and say those modules don't exist yet in this repo — do not improvise a substitute module or
hand-write raw cloud-provider resources instead.

## Step 0 — Preflight

Run from inside the target agent's own directory (the clone produced by `new-agent`, or any existing
agent repo with a working `Strategy`):

```bash
git status --short              # confirm nothing unexpected staged/dirty that this skill shouldn't touch
docker --version >/dev/null 2>&1 && echo "docker ok"
tofu --version    >/dev/null 2>&1 && echo "tofu ok"     # OpenTofu, never terraform — see ./CLAUDE.md
gcloud config get-value project 2>/dev/null             # confirm which GCP project is active
gcloud auth print-access-token >/dev/null 2>&1 && echo "gcloud auth ok"
```

Stop and report if `tofu`/`docker`/`gcloud` are missing, or if `gcloud auth` fails — don't proceed on
a broken toolchain. Confirm the active `gcloud` project with the user before continuing; never assume
it's the right one.

If `./CLAUDE.md` isn't present in the target directory, copy it from this repo before continuing —
its rules (digest-pinning, `secret_env`, the apply gate) govern the rest of this skill.

## Step 0.5 — Optional: bump the code version (`--bump`)

**Skipped entirely unless `--bump` was passed to this skill invocation.** This bumps the target
agent's *code version* — a semver, one per repo, tracking "which build is this." It is a different
axis from the *agent version*/generation served at `/vN`, which this step never touches; see
[`docs/serving-multiple-versions.md`](../../docs/serving-multiple-versions.md) if the distinction
isn't already clear to the user.

Anchor via the most recent tag, same convention as this repo's own `release` skill:

```bash
git describe --tags --match 'v*' --abbrev=0
```

If this fails (no tags yet), the next version is `0.1.0` regardless of level chosen — the template's
`scripts/bump-version.sh` handles this case itself.

Summarize `git log <anchor>..HEAD --oneline` by conventional-commit type and recommend a level using
the usual rule: any `!` after the type or a `BREAKING CHANGE` footer → `major`; any `feat:` → `minor`;
otherwise → `patch`. Present the recommendation and **require the user to type back a level word** —
`major`, `minor`, `patch`, or `skip`. `skip` continues to Step 1 without bumping anything.

```bash
bash scripts/bump-version.sh <level>
```

Then read the entrypoint's mount literal (`main.go:39` for Go, `main.py:29` for Python,
`src/main.ts:23` for TypeScript — see `add-agent-version` for the exact shape) to find every path
currently served. **Derive this list by reading the file, never by guessing or trusting what the user
says is deployed.** If the anchor tag exists, also read the entrypoint as of that tag
(`git show <anchor>:<entrypoint-path>`) and diff its mount list against the current one — any path
present now but not at the anchor is newly added.

```bash
git add -A
git commit -m "chore(release): v<new>"
git tag -a "v<new>" -m "serves <space-separated current path list>"          # no new mount since <anchor>
# or, if the diff above found a newly added path:
git tag -a "v<new>" -m "serves <space-separated current path list> (new: <newly added path(s)>)"
git push --follow-tags
```

The annotated tag message is the one place the code-version and agent-version axes get correlated —
write the real path list every time, not a placeholder. No CI wait is needed here: this skill builds
the image locally in the next step, it doesn't depend on a release pipeline picking up the push.

**The level word above does not authorize `tofu apply`.** That is an entirely separate gate — Step 6
below still requires its own literal typed **`apply`**, unweakened and unimplied by anything decided
in this step. Approving a bump level, or approving the diff this step produces, is not sufficient for
apply and must never be treated as such.

## Step 1 — Build and digest-pin the image

Full detail in [`docs/building-your-image.md`](../../docs/building-your-image.md). The short form:

```bash
docker buildx build --platform linux/amd64 -t <region>-docker.pkg.dev/<project-id>/<repo>/agent:local .
docker push <region>-docker.pkg.dev/<project-id>/<repo>/agent:local
```

If the target project has no Artifact Registry repo yet, use
[`modules/gcp-artifact-registry`](../../modules/gcp-artifact-registry) (or point at
[`examples/greenfield`](../../examples/greenfield) for the full bootstrap-first flow) rather than
improvising a `gcloud artifacts repositories create` call outside tofu — infrastructure this repo can
create belongs in tofu, not a one-off command.

## Step 2 — Resolve the digest

```bash
gcloud artifacts docker images describe <region>-docker.pkg.dev/<project-id>/<repo>/agent:local \
  --format='value(image_summary.digest)'
```

Combine the repository path with the printed digest to get the full `...@sha256:<64 hex>` reference.
**Never hand-write a digest or reuse one from a previous deploy** — always resolve it fresh against
what was just pushed, since `modules/gcp-cloud-run` validates the `image` variable is digest-pinned
and a stale digest silently deploys old code.

## Step 3 — Secrets

If the agent needs an outbound key (it does, unless the user has already created one for this agent):

```bash
openssl rand -hex 32 | tr -d '\n' | gcloud secrets create <agent-name>-outbound-key \
  --project=<project-id> --replication-policy=automatic --data-file=-
```

Never print this value back into chat or write it into any `.tf`/`.tfvars` file — it goes into
`secret_env` as a secret *reference* (the secret ID above), never `env`. See
[`docs/module-contract.md`'s input variables](../../docs/module-contract.md#input-variables).

## Step 4 — Generate `.tfvars`

Against the variable surface in
[`docs/module-contract.md`](../../docs/module-contract.md#input-variables), write (or update) a
`terraform.tfvars` (or a differently-named `.tfvars` if the target directory already has a convention)
in the target directory:

```hcl
project_id = "<project-id>"
region     = "<region, default us-central1>"
agent_name = "<agent-name>"
image      = "<region>-docker.pkg.dev/<project-id>/<repo>/agent@sha256:<digest-from-step-2>"

secret_env = {
  MCP_OUTBOUND_KEY = "<agent-name>-outbound-key"
}
```

Leave `max_instances` at its default (`1`) unless the user has explicitly confirmed their `Strategy`
is stateless or shares state externally — see `./CLAUDE.md`'s Scaling section. Do not raise it
silently even if the user's earlier `Strategy` description implied concurrency; ask first.

If a `main.tf` referencing `modules/gcp-cloud-run` doesn't already exist in the target directory,
write one modeled on [`examples/minimal/main.tf`](../../examples/minimal/main.tf), pinning
`source` to the same `?ref=` this repo's own README uses.

## Step 5 — `tofu init` and `tofu plan`

```bash
tofu init
tofu plan -out=tfplan
```

Show the full plan output to the user. Confirm it shows only the expected resources (one Cloud Run
service, one runtime service account, and their IAM bindings — nothing else) and no unexpected
destroys. If anything looks like it would delete or replace an existing production resource, stop and
ask before continuing, even before the apply gate below.

## Step 6 — Stop. Apply requires a typed confirmation.

**Do not run `tofu apply` as part of this skill invocation.** Present the plan summary and ask the
user to explicitly confirm they want to apply it — require a literal **`apply`** typed back (not a
general "yes," "looks good," or an earlier approval of an unrelated step). Anything else — silence,
"looks fine," approving the `.tfvars` content, or approving the plan output itself — is not
sufficient; only the literal word authorizes the next command.

Once (and only once) that confirmation is given:

```bash
tofu apply tfplan
```

If apply fails partway, report the exact error and stop — do not retry automatically or attempt to
work around a failed apply with a different command.

## Step 7 — After apply

```bash
tofu output -raw service_account_email
```

Grant the runtime service account access to the secret from Step 3 (skipped if the deploy above
failed):

```bash
gcloud secrets add-iam-policy-binding <agent-name>-outbound-key \
  --project=<project-id> \
  --member="serviceAccount:$(tofu output -raw service_account_email)" \
  --role=roles/secretmanager.secretAccessor
```

Then print `tofu output -raw endpoint_url` for the user and hand off to `register-agent` — this skill
stops here and does not register anything with the platform itself.

## What this skill never does

- Never runs `tofu apply` without a literal typed `apply` confirmation for that specific plan.
- Never targets AWS or Azure (no such modules exist yet in this repo).
- Never writes a secret value (only a secret *reference*) into any file.
- Never pushes to any git remote.
- Never touches the platform's registration API or web console — see `register-agent`.
