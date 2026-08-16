# CLAUDE.md

This file is for **your own agent's working directory** — the repo you cloned from
`gismo-agent-{go,python,typescript}` and where you're deploying it with `gismo-agent-hosting`'s
OpenTofu modules. It is not part of `gismo-agent-hosting` itself; copy it (or let the `new-agent`
skill below copy it for you) into your agent's repo root so Claude Code picks it up there.

If you invoked a skill from this repo (`new-agent`, `deploy-agent`, `register-agent` — see
`.claude/skills/`), these rules bind that skill's behavior. They also apply to anything else Claude
does in this directory involving infrastructure, even outside those skills.

## Tooling

- **OpenTofu, never Terraform.** This repo's modules are published for `tofu`; the `terraform` binary
  is not assumed to be installed and its state format compatibility isn't tested against. Run `tofu
  init`, `tofu plan`, `tofu apply` — not `terraform` anything.

## Images

- **`image` must be a digest-pinned reference** (`...@sha256:<64 hex>`), never a mutable tag like
  `:latest` or a branch name. `modules/gcp-cloud-run` validates this and rejects a bare tag at plan
  time — see
  [`docs/module-contract.md`](https://github.com/Axemere-LLC/gismo-agent-hosting/blob/main/docs/module-contract.md#what-the-core-module-deliberately-does-not-do)
  for why. Resolve the digest with `gcloud artifacts docker images describe ... --format='value(image_summary.digest)'`
  (or your registry's equivalent) after every push — never hand-write or guess a digest.

## Scaling

- **`max_instances` stays at `1`** unless your `Strategy` is stateless or shares state externally.
  Every template caches `get_state` in-process per match; a second instance can receive
  `submit_orders` for a match its own cache never saw, and silently holds every tank that impulse.
  Raising `max_instances` is a correctness decision, not just a cost knob — never do it without the
  user explicitly confirming their `Strategy` implementation doesn't rely on the per-instance cache.

## Secrets

- **The outbound key (and any other credential your agent needs) goes in `secret_env`, never
  `env`.** `env` values land in `.tf` files and `tofu` state as plaintext; `secret_env` takes a
  Secret Manager (or provider-equivalent) secret *reference*, not the value itself. Never write a raw
  secret value into a `.tf`, `.tfvars`, or any file that gets committed.

## Applying infrastructure

- **Never run `tofu apply` unprompted.** Generating a `.tfvars` file and running `tofu init` +
  `tofu plan` is fine on your own initiative — showing the user what *would* change is safe and
  reversible. `tofu apply` is not: it provisions real, billable cloud resources. Always show the plan
  output and get an explicit, typed confirmation from the user before running `apply` — a prior
  approval of the plan is not itself approval to apply it. This mirrors
  [`docs/module-contract.md`](https://github.com/Axemere-LLC/gismo-agent-hosting/blob/main/docs/module-contract.md#what-the-core-module-deliberately-does-not-do)'s
  "applying is always a human, local `tofu apply`."
- The same applies to any registration step past `tofu apply` — creating the agent, creating an agent
  version, flipping `competition_eligible` on. Each is its own deliberate, individually-confirmed
  action; do not chain them together without checking in between.
