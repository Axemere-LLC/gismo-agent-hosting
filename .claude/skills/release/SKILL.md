---
name: release
description: >
  MAINTAINER ONLY — cut a code-version release of this repo
  (gismo-agent-hosting) itself: choose a semver level, sync every ?ref=
  pin across README/docs/examples/module READMEs to the new tag, require a
  typed "yes", commit, tag, push (main and the tag as two separate
  pushes — never git push --tags), then verify the new ref actually
  resolves with a scratch tofu init. A competitor who cloned this repo to
  deploy their own agent almost certainly wants deploy-agent instead — this
  skill releases the hosting modules, not an agent. Invoke with no
  arguments to be walked through level selection, or a literal
  major|minor|patch|skip to pre-answer that step.
argument-hint: "[major|minor|patch]"
disable-model-invocation: false
allowed-tools: Bash Read Grep Edit
---

# /release

**MAINTAINER ONLY.** This skill cuts a release of `gismo-agent-hosting` itself — the OpenTofu modules,
not any competitor's agent. If you're here because you want to deploy *your own* agent, stop and use
`deploy-agent` instead; nothing in this skill builds, deploys, or registers an agent.

Modeled on `gismo-platform`'s `/publish` (typed-`yes` gate, one-tag-per-push discipline) and `/deploy`'s
Step 0 (level selection via conventional-commit summary).

## Step 0 — Preflight

```bash
git status --porcelain           # must be empty — refuse on a dirty tree
git rev-parse --abbrev-ref HEAD  # must print "main"
git fetch origin main --quiet
git rev-parse HEAD               # must equal...
git rev-parse origin/main        # ...this
```

Then confirm the target tag doesn't already exist, once the level is chosen in Step 1:

```bash
git rev-parse "v<new>" 2>/dev/null && echo "TAG ALREADY EXISTS LOCALLY — STOP"
git ls-remote --tags origin "v<new>" | grep -q . && echo "TAG ALREADY EXISTS ON REMOTE — STOP"
```

Do not attempt to fix a dirty tree or wrong branch yourself — that's the user's call. Stop and report
exactly which check failed.

## Step 1 — Choose the level

Anchor via the most recent tag:

```bash
git describe --tags --match 'v*' --abbrev=0
```

If this fails (no tags yet — true for the very first release), the anchor is the repo's first commit
and the release is `v0.1.0` regardless of level chosen, since there is no prior version to bump from.

Summarize `git log <anchor>..HEAD --oneline` by conventional-commit type (`feat:`, `fix:`, `chore:`,
etc.) and recommend a level using the usual rule: any `!` after the type or a `BREAKING CHANGE` footer
→ `major`; any `feat:` → `minor`; otherwise → `patch`.

**Repo-specific rule, in addition to the commit-type heuristic:** diff `docs/module-contract.md` and
every `modules/*/variables.tf` + `modules/*/outputs.tf` against the anchor:

```bash
git diff <anchor>..HEAD -- docs/module-contract.md 'modules/*/variables.tf' 'modules/*/outputs.tf'
```

A removed or renamed variable or output is a **major** bump regardless of what the commit-type summary
alone suggests — `README.md`'s own Versioning section states this rule
(`docs/module-contract.md`'s contract is the thing semver is tracking here, not just commit messages).
Call this out explicitly if it changes the recommendation.

Present the recommendation and the commit summary, and require the user to type back a level word —
`major`, `minor`, `patch`, or `skip`. This is separate from Step 4's literal `yes`; a level word here
does not imply consent to push. `skip` exits the skill without doing anything further.

## Step 2 — Sync the `?ref=` pins

Compute `v<new>` from the anchor and chosen level (first release: always `v0.1.0`, independent of
level). Rewrite every occurrence of `?ref=v<old>` (or, on the first release, confirm every occurrence
already reads `?ref=v0.1.0` — a no-op) to `?ref=v<new>`, and flip the badge:

| File | What changes |
|---|---|
| `README.md` | badge (`release-unreleased-lightgrey` / `release-v<old>-blue` → `release-v<new>-blue`), quickstart HCL `source =` line, Versioning section example |
| `docs/quickstart.md` | `source =` line |
| `docs/serving-multiple-versions.md` | `source =` line |
| `examples/minimal/main.tf` | the commented alternative `source =` line (the live, uncommented `source` stays a relative path — do not touch it) |
| `modules/gcp-cloud-run/README.md` | `source =` line |
| `modules/gcp-artifact-registry/README.md` | `source =` line |
| `modules/gcp-bootstrap/README.md` | `source =` line |
| `modules/gcp-cicd/README.md` | `source =` line |
| `modules/gcp-org-policy/README.md` | `source =` line |

`README.md` is the de-facto source of truth for what pin every skill in this repo tells a user to
write — `deploy-agent/SKILL.md` instructs Claude to pin "the same `?ref=` this repo's own README
uses," so a sync that misses the root README leaves that skill emitting a stale pin on every future
`deploy-agent` run. Use `grep -rn '?ref=v' README.md docs/ examples/ modules/*/README.md` before and
after to confirm every occurrence was caught and nothing else changed.

Show the full `git diff` to the user.

## Step 3 — Typed literal `yes`

Require a literal **`yes`** typed back — not "looks good," not an earlier approval of the level choice
in Step 1. Approving the diff shown in Step 2 is a separate decision from approving the push in Step
4; anything short of the literal word means stop.

## Step 4 — Commit, tag, push

```bash
git add -A
git commit -m "chore(release): v<new>"
git tag -a "v<new>" -m "$(cat <<'EOF'
v<new>

<conventional-commit summary from Step 1>
EOF
)"
git push origin main
git push origin "v<new>"
```

**Push `main` and the tag as two separate invocations. Never `git push --tags`, and never combine
multiple tags into one push** — GitHub silently drops the `on: push: tags` trigger when a push carries
more than one tag, and the failure mode is a release that never fires with nothing to notice until
someone checks.

## Step 5 — Verify the new ref actually resolves

A green CI run is not proof the tag is consumable — verify against the real thing:

```bash
tmpdir="$(mktemp -d)"
cat > "$tmpdir/main.tf" <<EOF
module "agent" {
  source     = "github.com/Axemere-LLC/gismo-agent-hosting//modules/gcp-cloud-run?ref=v<new>"
  project_id = "placeholder"
  agent_name = "placeholder"
  image      = "placeholder@sha256:0000000000000000000000000000000000000000000000000000000000000000"
}
EOF
(cd "$tmpdir" && tofu init -backend=false)
rm -rf "$tmpdir"
```

`tofu init` succeeding (module fetched, no "reference not found" error) is the actual proof — report
the result plainly, including if it fails, rather than declaring the release done because the push
succeeded.

## What this skill never does

- Never runs against any repo but `gismo-agent-hosting` itself.
- Never builds, deploys, or registers a competitor agent — see `deploy-agent`/`register-agent` for that.
- Never pushes more than one tag in a single `git push` invocation.
- Never infers a level or a `yes` — both require a literal typed response.
- Never fixes a dirty tree or wrong branch on its own initiative.
