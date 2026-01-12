# home-ops/scripts

This directory contains Kubernetes- and cluster-adjacent helper commands.

Design intent:

- **Cluster context stays here**: anything that relies on `kubectl`, cluster secrets, port-forwards, etc.
- **App repo stays app-local**: anything that relies on app source code, local `.env`, local Python tooling, etc.

Most helpers are exposed via `just` modules from the repo root.

## Discoverability

From the repo root:

```bash
just scripts
```

This lists the available recipes in the `scripts` module.

## Costanza

Costanza is deployed in-cluster. Kubernetes interaction for Costanza lives here by design.

### Quick commands

List Costanza-related helpers:

```bash
just scripts
```

Health check from inside the cluster (no tokens required):

```bash
just scripts costanza-health
```

Port-forward the Service (defaults to `localhost:8001` → Service port `80`):

```bash
just scripts costanza-port-forward
```

Trigger a Jellyseerr `TEST_NOTIFICATION` via port-forward using the **cluster** Secret token:

```bash
just scripts costanza-webhook-test
```

### Notes

- **Port-forward uses 8001** to avoid clashing with local dev (which commonly uses 8000).
- Local development (uv/just, `.env`, running the bot locally) lives in the `costanza` repo.

## Conventions

- Prefer `curlimages/curl` for in-cluster HTTP checks.
- Avoid copying secrets to disk. When required, fetch them at runtime and keep them in-memory.
- Keep recipes small and composable; prefer adding a new recipe over making one recipe do everything.
