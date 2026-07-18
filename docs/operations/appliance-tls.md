# Appliance TLS

Browser-trusted certificates for the LAN-only UniFi and Synology management
UIs (#1533). No public ingress; nothing routes through Kubernetes; private
keys are generated on each appliance and never transit.

## Shape

- Each UI has one internal DNS name under the cluster domain, maintained as a
  manual router record alongside the stable Kubernetes API name. There are no
  public A records; issuance is DNS-01 against the public zone.
- Each appliance holds its own zone-scoped Cloudflare API token (Zone: Read,
  DNS: Edit, single zone, no expiry), stored in 1Password as `svc-acme-nas`
  and `svc-acme-unifi`. Rotating a token never affects issued certificates,
  only future renewals.

## Synology

acme.sh runs on the NAS as root (`/root/.acme.sh`), issuing via `dns_cf` and
deploying with the `synology_dsm` hook in temp-admin mode, so no DSM admin
credentials are stored. The hook briefly disables and restores 2FA
enforcement on each deploy; if a deploy is interrupted, re-check that
enforcement in Control Panel.

- **Renewal**: DSM Task Scheduler task `acme-renew` runs
  `/root/.acme.sh/acme.sh --cron` daily as root. There is no crontab on DSM —
  this task is the only renewal mechanism.
- **Replacement**: `acme.sh --renew -d <name> --force` re-issues and
  re-deploys end-to-end (verified working).
- **Recovery**: if ACME fails, DSM falls back to its self-signed certificate;
  re-run the issue and deploy steps from the acme.sh install.

## UniFi

The console's native Let's Encrypt support, using the automatic Cloudflare
DNS-01 integration (configured in the console UI with its own token). Avoid
the manual-DNS mode: it requires a fresh manual TXT record at every renewal
and has known validation-stability issues.

- **Renewal**: automatic; the console manages the challenge records itself.
- **Replacement**: delete and recreate the certificate entry in the console
  UI (also the community-reported fix for a validation stuck in "verifying").
- **Recovery**: removing the entry reverts the console to its self-signed
  certificate; management access is unaffected.

## Verification

From any LAN client: the UI loads by name with no warning, and
`openssl s_client` shows a Let's Encrypt issuer with a current validity
window. Browsing by raw IP still warns by design — the name is the front
door. First natural renewals fall due roughly 60 days after issuance;
observe one cycle per appliance before trusting the automation unattended.
