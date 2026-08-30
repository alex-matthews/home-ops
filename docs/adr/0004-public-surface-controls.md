# ADR-0004: Per-Surface Controls for Public Services

- **Status:** Accepted
- **Date:** 2026-08-28
- **Related:** [Issue #1233][i1233]

## Context and Problem Statement

Several cluster services are deliberately reachable from the internet, and
nothing recorded which ones, who consumes each, or what protects them. The
cost of that gap surfaced while wiring Konflate into the Renovate Review
workflow: CI's first approach, fetching the interactive diff page, was
refused by something that was never identified, and the plain markdown
endpoint became the evidence path instead.

The public surfaces are now classified by consumer, sensitivity and state
change in
[`docs/operations/public-surfaces.md`](../operations/public-surfaces.md),
while the detailed inventory (hostnames, addresses, ports, routing topology)
lives in private operational notes.

This ADR is one layer: north-south controls per public surface. Three
adjacent layers are deliberate follow-up work: optimal use of the Cloudflare
edge, whose current configuration is unrecorded; identity (OIDC); and
east-west containment. The classification register is an input available to
each.

## Decision Drivers

- Legitimate automation must keep working.
- A control must be effective for every client that matters to a surface,
  not only for clients arriving by one path to it.
- Controls stay proportionate to a single-operator estate.
- This layer adds no new operators or backing services; identity
  infrastructure belongs to the identity follow-up.
- Prefer removing exposure to defending it.
- Exposure that remains is either controlled or accepted in writing with its
  risk owned.

## Considered Options

1. **Blanket edge controls** — bot detection, challenges and WAF rules across
   every public hostname — rejected as the boundary. A challenge breaks
   machine consumers silently, and an edge control covers only traffic that
   traverses the edge, which is not every path to every surface. Deliberate
   edge rules on verified paths are follow-up defence-in-depth work.
2. **One authentication layer in front of everything** — rejected. Shared
   authentication need not be interactive, but no single mechanism fits TV
   apps, webhook senders, CI jobs and image proxies alike; the choice has to
   be made per surface.
3. **Per-surface controls, recorded with deliberate exceptions** — chosen.

## Decision

**Policy.**

1. **A control has to sit where the traffic actually flows.** Not every
   client reaches a service by the same path. Before trusting a control,
   verify the boundary it sits at mediates every path that matters for that
   surface.
2. **No interactive challenge on anything consumed by software.** Webhooks,
   badges, status APIs and metrics are fetched by programs that cannot
   complete a challenge or hold a session, and the failure is often silent —
   a missing PR comment, a stale badge. This forbids browser challenges
   specifically; whether a machine endpoint should require a token instead
   is a separate per-surface question.
3. **Publish as little as each consumer needs.** A restriction on a path is
   not a restriction on a format: the same URL can reveal more in one
   representation than in another.
4. **Treat removal as a change like any other** — every removal names the
   consumers that remain.
5. **Sensitive or state-changing surfaces require authentication unless an
   exception is recorded here.** A cryptographically verified webhook
   signature counts; network position and unguessable hostnames do not.
6. **Cache only where the representation and freshness contract are
   defined.** A stale success used as review evidence is worse than a slow
   response.
7. **Rate limits and timeouts are calibrated against real consumers, not
   assumed harmless.** A limit that trips a CI job's single fetch discards
   the evidence it was protecting; limits are added for observed problems
   and sized against observed traffic.
8. **Credentials never appear in request URLs or logs.** A detected exposure
   is answered with revocation or rotation, verified afterwards.

**Accepted exceptions, deferrals and rejections**, recorded here so they are
not rediscovered. All take effect with this ADR; a deferral is a decision
not to build the control now, with its risk owned, and a rejection is a
decision not to build it at all.

| Item                                                                        | Disposition           | Reasoning                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------------------------------------------------------------------------- | --------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plex's own sign-in as its sole boundary                                     | Accepted              | Its clients are apps and TVs that cannot pass an interactive control. How the sign-in is configured — its local-network exception — is an open decision in issue #1233                                                                                                                                                                                                                                                                                                                                                |
| Seerr's sign-in, delegated to Plex accounts, as its sole boundary           | Accepted as interim   | Seerr is a browser app with the deepest blast radius of the public surfaces — approvals drive the download stack — so an additional authentication layer in front of it is decided in principle. The mechanism and identity provider belong to the identity follow-up, as does Seerr's account and sign-in-abuse policy                                                                                                                                                                                               |
| Anonymous access to Konflate's read APIs                                    | Accepted              | The data is analysis of an already-public repository, and CI needs to fetch it without a login. Machine tokens remain available if that changes                                                                                                                                                                                                                                                                                                                                                                       |
| Signature checks as the required boundary on the Konflate and Flux webhooks | Accepted              | The sender proves itself cryptographically on every request; no edge control substitutes for it. Edge filtering layered in front is compatible defence in depth for the edge follow-up, provided it preserves the request body bytes the signature covers                                                                                                                                                                                                                                                             |
| The status page enumerating internal service names                          | Accepted              | Hostname obscurity is not a boundary, so hiding the names would add no protection. Accepted consequence: the internal service inventory is publicly enumerable                                                                                                                                                                                                                                                                                                                                                        |
| Version and count disclosure through badges                                 | Accepted              | Mild reconnaissance value; publishing them is the point of badges                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| The json format's label disclosure on Kromgo's public route                 | Accepted              | Blocking the format at the route layer would need an inline-Lua extension policy — ordinary Gateway API query matching cannot see percent-encoded keys — which is disproportionate: after the alert-count fix, json reveals nothing beyond the version metadata the badge itself displays                                                                                                                                                                                                                             |
| Pod and node identifiers reflected by echo                                  | Accepted              | Minimal, and the surface exists to be probed                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| qBittorrent's peer port without user authentication                         | Accepted              | The protocol has no user-authentication layer to turn on. The router's port forward directs traffic; it does not authenticate anyone. Containing what the pod could reach if compromised is separate work                                                                                                                                                                                                                                                                                                             |
| A namespace gate on the external gateway's listener                         | Rejected              | Restricting which namespaces may attach public routes protects little in this estate's layout: most workloads share one namespace, so exposure would remain one route line away for nearly everything regardless                                                                                                                                                                                                                                                                                                      |
| Gateway rate limits                                                         | Deferred — edge first | Every public DNS record is Cloudflare-proxied, so the edge's always-on DDoS mitigation covers the internet path by default; verifying and tightening the edge's protections is the edge follow-up's job. A gateway-local ceiling would mostly bound the LAN path, applies per proxy replica, and risks tripping single-shot CI fetches and webhook bursts, so it waits until sized against observed traffic. Accepted risk meanwhile: no gateway request-rate ceiling; excessive requests may consume origin capacity |
| Edge caching                                                                | Deferred              | The only surfaces serving shared, anonymous responses a cache could hold are the Kromgo badges and the Konflate read outputs — everything else is authenticated, personalised or state-changing. The badges already advertise a shared cache lifetime, and a cached summary is mutable review evidence that risks going stale. Gain unmeasured                                                                                                                                                                        |
| Request and idle timeouts                                                   | Deferred              | A more specific traffic policy replaces the gateway-wide one rather than extending it unless merging is configured, so a naive timeout policy would silently discard the compression, retry and keepalive settings it displaces                                                                                                                                                                                                                                                                                       |

**Amendment.** A change to the policy rules amends this ADR — or, if the
shape of the decision changes, a new ADR supersedes it. A new exception, or
any change to an exception, deferral or rejection, lands as a pull request
amending this ADR with the reasoning. The classification register is
maintained in
[`docs/operations/public-surfaces.md`](../operations/public-surfaces.md) by
the pull request that exposes, changes or removes a surface.

## Consequences

Adoption is of the policy, not a certification that every existing surface
already complies; the gap is what issue [#1233][i1233] tracks.

- Three changes follow, each landing as its own pull request referencing
  issue [#1233][i1233] and carrying its own validation: retarget Konflate's
  MCP client to the in-cluster service and remove the endpoint's external
  routing, as one paired change; remove the metrics endpoint from Gatus's
  public route; and aggregate Kromgo's alert-count query so the json
  format carries no labels.
- One further piece of work is not a pull request: snapshot the Cloudflare
  edge configuration and record tunnel ownership, into private notes, as the
  opening step of the edge follow-up.
- The remaining decisions are tracked in issue [#1233][i1233]; outcomes that
  change this policy amend this ADR. The issue closes when they are settled,
  without waiting on every implementation change.

[i1233]: https://github.com/alex-matthews/home-ops/issues/1233
