# Appliances

Verified 2026-10-05 against the repository at `main`; appliance state is
external and was not checked.

[Policy](../policy/decisions.md#appliance-certificates) records why
management-interface certificates stay independent of the cluster.
Credential and certificate work is human-only.

## Certificates

As last recorded (retired `docs/operations/appliance-tls.md`), the NAS uses
acme.sh, its DSM deploy hook and Task Scheduler; the router uses automatic
DNS-01. Verify each appliance's installed version, configuration and renewal
results. Manual TXT entry does not meet the unattended-renewal requirement.

Secure an independent management path before changing TLS. Do not assume
removing a certificate preserves access. From a LAN client, verify named
browser access and the served certificate's name, issuer and validity.
Observe a natural renewal on each appliance before trusting automation;
use its current renewal information rather than a fixed day count.

## Management recovery

After an interrupted DSM deployment, verify two-factor enforcement is
restored and temporary administrative access removed. The [upstream
hook](https://redirect.github.com/acmesh-official/acme.sh/wiki/Synology-NAS-Guide)
uses those temporarily; this is not permission to relax safeguards.

Preserve an independent management path before attempting certificate
repair; do not assume deleting a certificate restores access.
