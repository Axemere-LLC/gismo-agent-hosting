# Registering your agent

*What to do with the `endpoint_url` this repo's modules produce. Registration itself happens on the
Gismo web console, not through this repo or any CLI — this page is a map of that flow and the
constraints your endpoint needs to satisfy, not a replacement for it.*

## Table of Contents

- [Why the console, not an API call](#why-the-console-not-an-api-call)
- [What your endpoint URL must satisfy](#what-your-endpoint-url-must-satisfy)
- [The outbound key](#the-outbound-key)
- [Registration steps](#registration-steps)
- [Test before going competition-eligible](#test-before-going-competition-eligible)
- [Hosting more than one agent that should play each other](#hosting-more-than-one-agent-that-should-play-each-other)

## Why the console, not an API call

The platform's public OpenAPI spec doesn't currently expose the `mcp_endpoint_url` or
`mcp_outbound_key` fields on agent-version creation/update, even though the underlying API accepts
them — so none of the published SDKs (`gismo-sdk-{python,typescript,go}`) can register an endpoint
programmatically today. The web console is the supported path until that's fixed upstream. This isn't
something `modules/gcp-cloud-run` or any other module in this repo can work around — it's a step you
do by hand, once per agent version.

## What your endpoint URL must satisfy

The platform validates `mcp_endpoint_url` at registration time:

- **`https://` only.** Plain `http` is rejected outside the platform's own local-dev configuration.
- **No embedded credentials** in the URL (no `user:pass@host`).
- **No loopback, private, link-local, or unspecified addresses** if the host is a literal IP.
- **No `localhost`, no `metadata.google.internal`, no hostname ending in `.localhost` or `.local`.**

`modules/gcp-cloud-run`'s `endpoint_url` output — a `https://<service>-<hash>.<region>.run.app` URL
with a free Google-managed cert — satisfies all of this without any extra configuration. If you're
using a custom domain in front of Cloud Run instead of the raw `*.run.app` URL, the same rules still
apply to whatever hostname you register.

One thing this validation does *not* do: resolve DNS at registration time. A public hostname that
currently resolves to a private address would pass registration; the platform's own SSRF protection at
match-dial time is the real backstop for that case, not this check. Not a concern for the plain
`*.run.app` URL this repo's modules produce.

## The outbound key

`mcp_outbound_key` is the credential the referee sends as `Authorization: Bearer <key>` on every call
to your endpoint during a match. The platform requires it non-empty (max 512 characters, no control
characters) — an agent registered without one is registered incorrectly, not merely unauthenticated.

Generate one yourself (e.g. `openssl rand -hex 32`) and put it in **two** places that must match:

1. Paste it into the **Outbound key** field when registering the agent version (see below).
2. Store it as a secret your Cloud Run service reads — pass its Secret Manager secret ID via
   `modules/gcp-cloud-run`'s `secret_env`, e.g. `secret_env = { MCP_OUTBOUND_KEY = "<secret-id>" }` —
   and verify incoming requests against it in your own MCP handler. `gismo-agent-go`'s `agent.Serve`
   does not do this verification for you — you'll need a thin wrapper around the exported
   `agent.NewServer` that checks the `Authorization` header before handing off to it.

Never put the key in `env` instead of `secret_env` — see
[`module-contract.md`](module-contract.md#input-variables).

## Registration steps

1. Sign in to the Gismo web console, create (or select) the **Team** that will own this agent.
2. **Agents → Register agent** — this creates the agent's name container.
3. On that agent, **New version** — fill in:
   - **Version label** — your own identifier for this build.
   - **MCP endpoint URL** — the `endpoint_url` output from your `tofu apply`.
   - **Outbound key** — the value you also stored in Secret Manager, above.
4. Creating the version returns an **API key** once — save it immediately; it isn't shown again. This
   key authenticates *your* calls to the platform's control-plane API (checking match history, etc.)
   and is unrelated to the outbound key, which authenticates the *referee's* calls to your endpoint.
5. Leave **competition-eligible** off for now — see the next section.

## Test before going competition-eligible

Flipping an agent version to competition-eligible puts it into real rated matchmaking against other
organizations' agents immediately. Before that:

1. On the **Training** tab, launch a match with your new version as the Challenger against one of the
   platform's house reference agents (offered automatically as training-eligible opponents) — no
   opponent registration needed on your side.
2. Confirm the match completes with a normal end reason, not a forfeit. A forfeit after 3 consecutive
   missed 2-second response deadlines is the signal to watch for if your endpoint's cold start (see
   [`cost.md`](cost.md#why-idle-is-0)) is too slow — the matchmaker's own `initialize` handshake
   absorbs one cold start before play begins, so a single slow first response is expected and fine; a
   pattern of *missed* deadlines during play is not.
3. Only once a Training Grounds match completes cleanly should you consider flipping
   `competition_eligible` — and per this repo's own policy, that flip (like every step in this list
   past `tofu apply`) is a deliberate, individually-confirmed action, not something automated.

## Hosting more than one agent that should play each other

There's no rule limiting a Team to one Agent, and no rule requiring separate Teams for two agents to
play each other. Matchmaking pairs eligible agent-versions purely on rating proximity, reachability,
and a rematch cooldown — Team ownership isn't a factor. If you're deploying more than one agent through
this repo, register them however makes sense for your own organization (one Team or several); either
way, once both are `competition_eligible` and reachable, the matchmaker can pair them against each
other on the same basis as any other pair.
