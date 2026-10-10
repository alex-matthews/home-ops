# Public Surfaces

Verified 2026-10-05 against the repository at `main`; not against live
sign-in, router, edge or response behaviour.

A surface is an internet-consumed path, not necessarily a whole route.
Prefer removing exposure, with controls proportionate to its consumers and
risk. Identity, edge controls and east-west containment remain separate work.
Changing these decisions follows [standing decisions](decisions.md).

- Verify every relevant traffic path passes the proposed control.
- Software clients must not face interactive challenges; decide machine
  authentication per surface.
- Minimise disclosure in every representation, not just selected paths.
- A removal names the consumers that remain.
- Authenticate sensitive/state-changing surfaces unless explicitly excepted.
  Verified webhook signatures count; position and obscurity do not.
- Define representation and freshness before caching.
- Calibrate rate limits and timeouts against observed traffic/problems.
- Keep credentials out of URLs/logs; after exposure, a human must revoke or
  rotate them and verify the result.

## Register

The following boundaries are accepted or declared, not certification of live
behaviour. Check that before relying on them. The pull request that exposes,
changes or removes a surface updates its row and identifies remaining
consumers.

| Surface and consumers            | Risk and accepted boundary                                                                                                                                                                               |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Plex apps/TVs                    | Sensitive, state-changing; own sign-in because clients cannot pass interactive controls. The local-network exception remains an [owner decision](https://github.com/alex-matthews/home-ops/issues/1233). |
| Seerr household/API clients      | Sensitive requests drive downloads. Plex-based sign-in is interim; additional authentication is agreed in principle, with mechanism and account-abuse policy unresolved.                                 |
| konflate people/CI reads         | Anonymous public-repository analysis; CI needs unattended access. MCP remains internal, with external `/mcp` returning 404. Reconsider machine tokens if sensitivity changes.                            |
| konflate and Flux webhooks       | Requests trigger work/reconciliation. Verify each signature; extra edge controls must preserve signed bytes.                                                                                             |
| kritika webhook                  | A valid call queues a review that spends model budget. Signature checked on every request; only POST to the hooks path is routed.                                                                        |
| Gatus status readers             | Service-name/uptime enumeration is accepted; obscurity is not protection. `/metrics` returns 404 externally; Prometheus scrapes internally.                                                              |
| Version/count badge consumers    | Metadata disclosure is intentional, accepting reconnaissance value.                                                                                                                                      |
| Kromgo JSON consumers            | Limited additional labels are accepted; keep queries aggregated and label-minimal instead of disproportionate format filtering. This does not authorise arbitrary metrics disclosure.                    |
| echo probes                      | Pod/node identifiers are accepted for reachability testing; command execution stays disabled.                                                                                                            |
| qBittorrent peers                | Protocol traffic can write downloads without user sign-in. Port forwarding is routing, not authentication; containment is separate.                                                                      |
| External-listener namespace gate | Rejected: the estate's shared namespace would leave exposure one route away.                                                                                                                             |
| Gateway rate limits              | Deferred pending path/edge/traffic assessment. No origin request-rate ceiling is an accepted risk.                                                                                                       |
| Edge caching                     | Deferred: badges already cache; authenticated/stateful traffic and mutable konflate review evidence limit benefit.                                                                                       |
| Further timeouts                 | Deferred; inspect precedence/merge semantics against existing [gateway timeouts](../../kubernetes/apps/network/envoy-gateway/app/envoy.yaml) before adding per-surface policy.                           |

Current route restrictions are in the
[konflate](../../kubernetes/apps/flux-system/konflate/app/helmrelease.yaml),
[kritika](../../kubernetes/apps/kritika/kritika/app/httproute.yaml),
[Gatus](../../kubernetes/apps/observability/gatus-sidecar/app/helmrelease.yaml)
and [Kromgo](../../kubernetes/apps/observability/kromgo/app/helmrelease.yaml)
declarations. Detailed site topology stays private. A proxied DNS flag or
route manifest alone does not prove all client paths are protected.
