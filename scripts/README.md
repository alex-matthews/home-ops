# home-ops/scripts

Cluster-only helper commands (anything that needs `kubectl`, cluster secrets, port-forwards, or in-cluster debugging).

**Boundary rule:** if it touches Kubernetes, it lives here. If it touches app source code or local `.env`, it lives in the app repo.

Recipes are exposed via `just` modules from the repo root.

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

### Overrides

All Costanza helpers have sensible defaults, but you can override them via environment variables:

- `COSTANZA_NS` (default: `default`) — Namespace containing the Service/Secret
- `COSTANZA_SVC` (default: `costanza`) — Kubernetes Service name
- `COSTANZA_SECRET` (default: `costanza-secret`) — Secret containing `JELLYSEERR_WEBHOOK_TOKEN`
- `COSTANZA_LOCAL_PORT` (default: `8001`) — Local port used for `kubectl port-forward`
- `COSTANZA_TARGET_PORT` (default: `80`) — Target Service port

Example (non-default namespace and local port):

```bash
COSTANZA_NS=media COSTANZA_LOCAL_PORT=18001 just scripts costanza-webhook-test
```

### Notes

- **Port-forward uses 8001** to avoid clashing with local dev (which commonly uses 8000).
- Local development (uv/just, `.env`, running the bot locally) lives in the `costanza` repo.

## Conventions

- Prefer `curlimages/curl` for in-cluster HTTP checks.
- Avoid copying secrets to disk. When required, fetch them at runtime and keep them in-memory.
- Keep recipes small and composable; prefer adding a new recipe over making one recipe do everything.
