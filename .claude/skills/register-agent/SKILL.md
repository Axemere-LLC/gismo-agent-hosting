---
name: register-agent
description: >
  Walk a competitor through registering a deployed agent's endpoint_url
  with the Gismo web console and running its first training match.
  Registration itself happens on the console, not through any API this
  skill can call — this skill explains each field, checks the endpoint
  satisfies the console's validation rules, and tells the user what to
  paste where. It never flips competition_eligible on and never launches
  a match on the user's behalf.
argument-hint: "[endpoint-url]"
disable-model-invocation: false
allowed-tools: Bash Read Grep
---

# /register-agent

Registration happens on the Gismo web console, not through any API the published SDKs currently
expose — see
[`docs/registering-your-agent.md`](../../docs/registering-your-agent.md#why-the-console-not-an-api-call).
This skill's job is to get the user to that console with the right values in hand, checked, and
explained — not to automate a step that has no automatable path today.

## Step 0 — Confirm you have what registration needs

Ask for (or use, if passed as an argument) the `endpoint_url` output from `deploy-agent`'s
`tofu apply`, and confirm the outbound key from that same deploy is still on hand (the raw hex value,
not the Secret Manager secret ID — the console needs the value itself).

## Step 1 — Check the endpoint against the console's validation rules

Before sending the user to register, verify the URL satisfies what the platform checks at
registration time (see
[`docs/registering-your-agent.md`](../../docs/registering-your-agent.md#what-your-endpoint-url-must-satisfy)):

- Starts with `https://`, not `http://`.
- No embedded credentials (no `user:pass@host`).
- Host isn't `localhost`, a loopback/private/link-local/unspecified literal IP, `metadata.google.internal`,
  or a hostname ending in `.localhost`/`.local`.

A `modules/gcp-cloud-run` `endpoint_url` output (`https://<service>-<hash>.<region>.run.app`)
satisfies all of this without any extra work — if that's what you're registering, say so and move on
rather than re-deriving each rule against it. If the user supplied a custom domain instead, actually
check it against each rule above and flag anything that fails before sending them to the console.

Optionally confirm the endpoint is actually reachable (not that it authenticates correctly — the
referee's bearer key does that):

```bash
curl -sS -o /dev/null -w '%{http_code}\n' <endpoint_url>
```

A `401`/`403` here is expected and fine (the MCP endpoint requires the bearer key the referee sends);
a connection failure or `5xx` means the deploy isn't actually healthy yet — send the user back to
`deploy-agent` rather than continuing to register a dead endpoint.

## Step 2 — Walk the console flow

Tell the user, in order (do not perform these clicks yourself — this is a human, console-driven
flow):

1. Sign in to the Gismo web console, select (or create) the **Team** that will own this agent.
2. **Agents → Register agent** — creates the agent's name container.
3. On that agent, **New version** and fill in:
   - **Version label** — their own identifier for this build, matching the path segment being
     registered (e.g. `v1` for `/v1`, `v2` for `/v2`).
   - **MCP endpoint URL** — the `endpoint_url` value checked in Step 1, **with the generation's path
     appended**: every template mounts its first generation at `/v1` from day one, so the bare
     `endpoint_url` alone never serves MCP — e.g. `https://your-service-xyz.run.app/v1`. Registering
     the unsuffixed URL 401s (if an outbound key is set) or 404s (if not) unconditionally; it is not a
     valid registration target under any circumstance.
   - **Outbound key** — the raw hex value from Step 0, *not* the Secret Manager secret ID.
4. Creating the version returns a one-time **API key** — tell the user to save it immediately; it
   authenticates their own calls to the platform's control-plane API and is unrelated to the outbound
   key.
5. Leave **competition-eligible** off. Do not tell the user to turn it on yet — that's Step 4 below,
   and only after a clean training match.

The agent's MCP `initialize` handshake auto-reports the path-derived version label now (it's
path-derived, not something the template's code has to be told separately) — confirm
`serverInfo.version` in the handshake equals the **Version label** entered above, rather than
reminding the user to pass a version argument by hand. See
[`docs/registering-your-agent.md`](../../docs/registering-your-agent.md) and
[`docs/serving-multiple-versions.md`](../../docs/serving-multiple-versions.md).

## Step 3 — Run a training match

Tell the user (again, a console action, not something this skill performs): from the **Training**
tab, launch a match with the new version as Challenger against one of the platform's house reference
agents — no opponent registration needed on their side. Watch it live at
`https://gismo.axemere.ai/watch/<match-id>`.

## Step 4 — What "clean" looks like, and what happens next

Confirm with the user that the match ended with a normal end reason, not a forfeit. One slow response
during the initial `initialize` handshake (a cold start) is expected and absorbed; a pattern of missed
2-second deadlines during play means the deploy isn't healthy — send them back to `deploy-agent`
(check `min_instances`/cold-start behavior — see
[`docs/cost.md`](../../docs/cost.md#why-idle-is-0)) rather than treating it as a registration problem.

Only once a training match completes cleanly should the user consider flipping
`competition_eligible` on — **this skill never does that for them.** State clearly that it puts the
agent into real rated matchmaking against other organizations immediately, and that it's their call
to make on the console, not an action to automate.

## What this skill never does

- Never calls a registration API on the user's behalf — none of the published SDKs expose one; see
  Step 0's linked rationale.
- Never flips `competition_eligible` on.
- Never launches a match itself.
- Never asks for or stores the user's platform login credentials.
