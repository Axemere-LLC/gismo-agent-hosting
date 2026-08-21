---
name: new-agent
description: >
  Scaffold a new Gismo competitor agent from one of the three official
  templates (gismo-agent-go, gismo-agent-python, gismo-agent-typescript).
  Asks which language, clones the matching template, drops in this repo's
  CLAUDE.md, writes a Strategy stub reflecting the tactics the user
  describes, and runs the template's own test suite. Never builds a
  container image and never touches any cloud provider — that's
  deploy-agent's job, invoked separately once the Strategy is real.
argument-hint: "[target-directory]"
disable-model-invocation: false
allowed-tools: Bash Read Grep Write Edit
---

# /new-agent

Turns "I want to build a Gismo agent" into a cloned template with a first-draft `Strategy` in it and
a passing test suite — nothing more. It does not build a container image, does not touch a cloud
provider, and does not deploy anything; see `deploy-agent` for the next step once you're happy with
your `Strategy`.

## Step 0 — Preflight

Confirm before doing anything else:

```bash
git --version   >/dev/null && echo "git ok"
docker --version >/dev/null 2>&1 && echo "docker ok"   # not required yet, but needed for deploy-agent later
```

If the target directory (see Step 2) already exists and is non-empty, stop and ask the user how they
want to proceed — never overwrite an existing directory.

## Step 1 — Ask which language

If not already stated in the invocation, ask the user which of the three templates to start from:

| Language | Template repo | Local run command |
|---|---|---|
| Go | `github.com/Axemere-LLC/gismo-agent-go` | `go run . -addr :8080` |
| Python | `github.com/Axemere-LLC/gismo-agent-python` | `python main.py -addr :8080` |
| TypeScript | `github.com/Axemere-LLC/gismo-agent-typescript` | `npm run build && node dist/src/main.js -addr :8080` |

Also ask (if not already described): **what tactics should this agent play?** — e.g. "always retreat
to the nearest forest and only fire when an enemy is within 3 cells," or "prioritize the enemy
blockhouse over enemy tanks." This drives Step 4; don't skip straight to a `HoldStrategy` clone
without asking.

## Step 2 — Clone the template

```bash
git clone https://github.com/Axemere-LLC/gismo-agent-<lang>.git <target-directory>
cd <target-directory>
git remote rename origin template
```

Renaming `origin` to `template` (rather than leaving it pointed at the read-only template repo)
signals that this clone is the user's own agent now, not a fork tracking upstream. Do not push
anywhere — this is a local scaffold only.

## Step 3 — Install dependencies and confirm the stub runs

| Language | Install | Local run |
|---|---|---|
| Go | (none — `go run` resolves modules itself) | `go run . -addr :8080` |
| Python | `python -m venv .venv && source .venv/bin/activate && pip install -e ".[dev]"` | `python main.py -addr :8080` |
| TypeScript | `npm ci` | `npm run build && node dist/src/main.js -addr :8080` |

Start the stub, confirm it listens without error, then stop it (`Ctrl-C` — do not leave a background
process running past this check). Every template ships a working `HoldStrategy` by default, so this
should succeed with zero code changes. If it doesn't, stop and report the exact error rather than
proceeding to Step 4 on a broken base.

## Step 4 — Write the `Strategy` stub

Locate the one extension point for the chosen language:

| Language | File | Interface/protocol |
|---|---|---|
| Go | `agent/strategy.go` | `Strategy` interface, `Decide(view mcpsdk.StateView) []mcpsdk.TankOrder` |
| Python | `gismo_agent/strategy.py` | `Strategy` protocol, `decide(self, view: StateView) -> list[TankOrder]` |
| TypeScript | `src/agent/strategy.ts` | `Strategy` interface, `decide(view: mcp.StateView): mcp.TankOrder[]` |

Write a new implementation next to the existing `HoldStrategy`/`RandomStrategy`/`HeuristicStrategy`
examples under `examples/`, translating the tactics the user described in Step 1 into concrete logic
against the wire fields documented in the template's own README (`heading`/`speed`/`turretHeading`
encodings, turn-rate legality helpers already exported by the template — reuse those rather than
reimplementing turn-distance math). Wire it into the entrypoint (`main.go` / `main.py` / `src/main.ts`)
in place of the default `HoldStrategy`, matching the exact call site each template's own README shows
under "Deploy it" / "The `Strategy` interface".

Keep the stub honest: if a tactic the user described can't be expressed from the `StateView` alone
(e.g. it needs information the observability model doesn't expose — see the template README's
Observability model section), say so rather than silently approximating it.

**The entrypoint already mounts this `Strategy` at `/v1`** — the template's own `agent.Mount`/`Mount`
literal (`main.go:39`, `main.py:29`, or `src/main.ts:23`) — so nothing about first-generation wiring
needs to change here. The one rule to state up front, since it governs every future change to this
agent: **once a generation is registered with the platform, never edit its mounted `Strategy` again**
— the platform rates each generation as an immutable entity, and a behavior change under a frozen path
corrupts a rating already earned. A second generation is a new mount at a new path (`/v2`, `/v3`, ...),
never an edit to `/v1`'s — see the `add-agent-version` skill once that day comes.

## Step 5 — Copy this repo's `CLAUDE.md`

```bash
cp <path-to-gismo-agent-hosting>/CLAUDE.md ./CLAUDE.md
```

This is what governs `deploy-agent` and `register-agent` once the user runs those skills from inside
the new agent's own directory — those skills are invoked from `gismo-agent-hosting`, but their rules
(digest-pinning, `secret_env`, the apply gate) need to travel with the target repo they're acting on.

## Step 6 — Run the template's own test suite

```bash
go test ./...                       # Go
python -m pytest                    # Python
npm test                            # TypeScript
```

Do not add new test coverage in this skill beyond what the template already ships — that's out of
scope here. Report the result (pass/fail, and the failure output verbatim if it fails) to the user.
A failing suite is not blocking in the sense of refusing to continue, but do not claim the scaffold is
"done" if tests fail — say clearly that the `Strategy` needs more work before deploying.

## What this skill never does

- Never builds a Docker image.
- Never runs `docker push`, `tofu`, `gcloud`, or any other cloud-provider command.
- Never commits or pushes to any remote.
- Never registers anything with the Gismo platform.

Once the `Strategy` is real and its tests pass, hand off to `deploy-agent`.
