# Public Surfaces

The classification register for internet-reachable services: each surface's
consumers, sensitivity, state-changing behaviour, and the control in front of
it today. The policy governing these surfaces is
[ADR-0004](../adr/0004-public-surface-controls.md); the detailed inventory —
hostnames, addresses, ports, routing topology — is in private operational
notes.

This register is maintained by the pull request that exposes, changes or
removes a surface: a new public surface gets its row as part of the change
that exposes it.

| Surface                     | Consumers                                                          | Sensitive                                                                    | Changes state                                                              | Control today                                                           |
| --------------------------- | ------------------------------------------------------------------ | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Plex                        | People, through apps and TVs that cannot pass interactive controls | Yes                                                                          | Yes                                                                        | Its own account sign-in                                                 |
| Seerr                       | Household members, plus probe and API clients                      | Yes                                                                          | Yes — approvals drive the download stack                                   | Its own sign-in, which is delegated to Plex accounts                    |
| Konflate — read APIs and UI | People and CI                                                      | Analysis of an already-public repository; its value is as CI review evidence | No                                                                         | None                                                                    |
| Konflate — webhook          | GitHub's webhook delivery                                          | Nothing in its responses                                                     | Yes — a valid call triggers work                                           | Cryptographic signature check on every request                          |
| Flux webhook receiver       | GitHub's webhook delivery                                          | Nothing in its responses                                                     | Yes — a valid call makes the cluster pull and apply the repo's main branch | Cryptographic signature check, limited to specific events and resources |
| Gatus status page           | People, plus the page's own scripts                                | The list of monitored services and their uptime history                      | No                                                                         | None; the metrics path answers 404 externally                           |
| Kromgo badges               | GitHub's image proxy and other fetchers                            | Cluster version and count metadata                                           | No                                                                         | Only pre-defined queries run, and only the badge path is routed         |
| echo                        | An automated reachability monitor                                  | Pod and node identifiers                                                     | No                                                                         | Command execution disabled                                              |
| qBittorrent peer port       | BitTorrent peers                                                   | None served; the pod can write to download storage                           | Yes                                                                        | The protocol implementation itself                                      |

Konflate is listed twice deliberately: its paths have different consumers
and different tolerable controls, and treating the hostname as one surface
is what produces controls that break CI. "Surface" and "route" are different
units — Konflate is one route and two public surfaces — so this register
counts neither. Its MCP endpoint is no longer a public surface: the external
route answers 404 on that path, and its one client consumes the in-cluster
service directly.
