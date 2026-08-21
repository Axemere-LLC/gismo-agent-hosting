---
name: add-agent-version
description: >
  Add a new agent version/generation to an already-deployed Gismo
  competitor agent — the second (and every subsequent) deploy, as opposed
  to new-agent's first one. Adds a new mount (e.g. /v2) to the entrypoint
  next to the existing ones, never edits an already-registered generation,
  re-records only that new generation's golden fixture and verifies no
  other golden moved, rebuilds and redeploys the one Cloud Run service
  behind both paths, then stops before tofu apply — same literal-"apply"
  gate as deploy-agent. Hands off to register-agent for the new path;
  never registers or flips competition_eligible itself.
argument-hint: "[path-to-agent-directory] [new-path, e.g. /v2]"
disable-model-invocation: false
allowed-tools: Bash Read Grep Write Edit
---

# /add-agent-version

The second-deploy counterpart to `new-agent`. Use this once an agent already has at least one
registered generation and you're adding another — never for a first deploy (`new-agent` +
`deploy-agent` cover that) and never to change what an already-registered generation does.

**The one rule everything else in this skill exists to protect:** the platform rates each agent
version/generation as an immutable entity. Editing a registered generation's behavior after the fact
silently corrupts a rating that real matches already earned. This skill only ever *adds* a mount — it
never edits an existing one.

## Step 0 — Preflight

Run from inside the target agent's own directory:

```bash
git status --short              # confirm nothing unexpected staged/dirty
git rev-parse --abbrev-ref HEAD  # confirm you're on the branch you think you're on
```

Read the entrypoint's mount literal to find every generation currently served — do not ask the user
or trust an earlier conversation turn, read the file fresh:

| Language | File:line | Literal shape |
|---|---|---|
| Go | `main.go:39` | `agent.VersionedHandler(agent.Mount{Path: "/v1", Strategy: agent.HoldStrategy{}})` |
| Python | `main.py:29` | `build_versioned_app([Mount("/v1", HoldStrategy())])` |
| TypeScript | `src/main.ts:23` | `const mounts: Mount[] = [{ path: "/v1", strategy: new HoldStrategy() }];` |

Report the generations found (e.g. "currently serving `/v1`") and confirm the new path with the user
(next unused integer, e.g. `/v2`, unless they specify otherwise) before touching anything.

## Step 1 — Write the new generation as a NEW `Strategy`, never edit an existing one

If the new generation is a behavior change from the last one, write it as a new `Strategy`
implementation (or a copy of an existing one, tweaked) — do not modify the `Strategy` instance any
existing mount already points at. Re-read the note in `new-agent/SKILL.md`'s Step 4 if you need the
reminder of why: a registered generation's rating is earned against its specific behavior, and this
skill has no way to un-corrupt a rating once real matches have used the wrong behavior.

## Step 2 — Add exactly one mount line to the entrypoint

The only edit this step makes to the entrypoint file is adding one more element to the existing mount
list — no other line in that file changes:

| Language | Edit |
|---|---|
| Go | Add another `agent.Mount{Path: "/vN", Strategy: ...}` argument to the existing `agent.VersionedHandler(...)` call |
| Python | Add another `Mount("/vN", ...)` element to the list passed to `build_versioned_app([...])` |
| TypeScript | Add another `{ path: "/vN", strategy: ... }` element to the `mounts: Mount[] = [...]` array |

Leave every existing mount's `Path`/path and `Strategy`/strategy untouched, in the same order.

## Step 3 — Record the golden for the new generation only

Add the new case to the fixture table, in the same style as the existing entries:

| Language | File:line | Add |
|---|---|---|
| Go | `agent/fixtures_test.go:35-37` | `{"vN", <newStrategy>, "../fixtures/expected/vN.json"}` to the `cases` slice |
| Python | `tests/test_fixtures.py:24-28` | `("vN", <NewStrategy>(), REPO_DIR / "fixtures" / "expected" / "vN.json")` to `CASES` |
| TypeScript | `test/fixtures.test.ts:25-29` | `["vN", new <NewStrategy>(), path.join(REPO_DIR, "fixtures", "expected", "vN.json")]` to `CASES` |

Do not add cases for `random-vN`/`heuristic-vN` variants unless the user is actually adding a new
example strategy alongside their own — one golden per new mount is enough.

## Step 4 — Run the full suite BEFORE re-recording anything

```bash
go test ./...                       # Go
python -m pytest                    # Python
npm test                            # TypeScript
```

**Stop on any failure in an existing (`v1`, or any other already-registered) generation's fixture
case.** That failure means a shared helper drifted under a frozen generation — exactly the hazard the
fixture lock exists to catch. Report it and stop; do not proceed to re-recording, which would silently
erase the evidence that something regressed.

The new `vN` case is *expected* to fail here (its golden doesn't exist yet) — that's fine, proceed to
Step 5 only for that reason.

## Step 5 — Re-record, then verify the diff is scoped to the new golden only

None of the three re-record commands is scoped to a single golden — running any of them touches every
case in the file:

```bash
go test ./agent/... -run TestFixtures -update   # Go
python -m pytest tests/test_fixtures.py --update-fixtures   # Python
UPDATE_FIXTURES=1 npm test                       # TypeScript — reruns the whole suite
```

Immediately after, this check is not optional:

```bash
git diff --stat fixtures/expected/
```

**It must show only `vN.json` as new/changed.** If any other file under `fixtures/expected/` shows a
diff, that is drift in an already-registered generation being papered over by the re-record — stop,
revert with `git checkout -- fixtures/expected/`, and report it rather than continuing. (Note the
goldens are per-language — Go alphabetizes JSON keys, Python/TypeScript use declaration order — so
don't compare golden bytes across repos as a sanity check; compare each repo only against its own
prior `git diff`.)

## Step 6 — Rebuild and resolve the digest fresh

Same as `deploy-agent`'s Steps 1–2 — full detail in
[`docs/building-your-image.md`](../../docs/building-your-image.md):

```bash
docker buildx build --platform linux/amd64 -t <region>-docker.pkg.dev/<project-id>/<repo>/agent:local .
docker push <region>-docker.pkg.dev/<project-id>/<repo>/agent:local
gcloud artifacts docker images describe <region>-docker.pkg.dev/<project-id>/<repo>/agent:local \
  --format='value(image_summary.digest)'
```

**Never hand-write or guess a digest, and never reuse one from a previous deploy** — the new image
contains the new mount, so its digest is necessarily different, per
`gismo-agent-hosting/CLAUDE.md`'s Images section.

## Step 7 — Update `.tfvars` and plan

Update only `image` in the existing `.tfvars` to the freshly-resolved digest from Step 6:

```bash
tofu init
tofu plan -out=tfplan
```

**The plan must show ONLY the container image digest changing on the existing Cloud Run
service/revision — nothing else.** No new resources, no destroys, no other variable changing. If
anything else appears in the plan, that means the mount edit in Step 2 somehow leaked into
infrastructure (it shouldn't have — the new mount is served by the same one Cloud Run service, same
`endpoint_url`, at a new path) — stop and report rather than continuing to apply.

## Step 8 — Stop. Apply requires a typed confirmation.

**Reuses `deploy-agent`'s gate verbatim, unweakened.** Do not run `tofu apply` as part of this skill
invocation. Present the plan summary and require a literal **`apply`** typed back — not "yes," "looks
good," or an approval of an earlier step in this skill. Nothing about having already confirmed the new
mount, the golden re-record, or the digest substitutes for this. Once given:

```bash
tofu apply tfplan
```

If apply fails partway, report the exact error and stop.

## Step 9 — Hand off to `register-agent`

Print `tofu output -raw endpoint_url` and tell the user the new generation is reachable at
`<endpoint_url>/vN`. Hand off to `register-agent` to register that path as a new agent version — this
skill does not call the registration console flow itself, and per
`gismo-agent-hosting/CLAUDE.md`, registration (like every step past `tofu apply`) is its own
deliberate, individually-confirmed action. **Leave `competition_eligible` off** — that's
`register-agent`'s Step 4, only after a clean training match on the new version specifically; a clean
match history on `/v1` says nothing about `/v2`'s behavior.

## What this skill never does

- Never edits a `Strategy` an existing mount already points at, or changes an existing mount's `Path`.
- Never re-records a fixture golden for any generation other than the one it just added — a diff
  touching any other `fixtures/expected/*.json` file is a stop condition, not something to proceed
  past.
- Never runs `tofu apply` without a literal typed `apply` confirmation for that specific plan.
- Never registers the new version with the platform or flips `competition_eligible` — see
  `register-agent`.
- Never touches code-version tooling (`scripts/bump-version.sh`) — that's `deploy-agent --bump`'s
  concern, a separate axis from the mount this skill adds.
