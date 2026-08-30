# Node Firmware and Boot

When a node hangs at reboot, how to read the sd-boot/NVRAM health signals,
the power-cycle recovery procedure, BIOS hardening, and known node-level log
noise. Observations are from the 2026-08-21 m3 firmware hang and the
2026-08-27 recovery; the rollout-level view is
[`node-upgrades.md`](node-upgrades.md) ("When a node stays down").

All three nodes are the same NUC model on the same BIOS build, so differences
in boot behaviour are per-unit NVRAM state, not firmware version. Talos boots
via sd-boot with UKI files on the EFI system partition; each upgrade writes
the new UKI, keeps the previous one as fallback, and updates EFI variables.

## The firmware hang signature

A node that is powered (switch port has link) but generates zero traffic and
answers on no address after an upgrade reboot is hung in firmware, before any
OS code runs. The install itself is not the suspect: the installer completes
and logs `installation of vX complete` before the reboot is issued, so the
node boots the target version once power-cycled.

The predictive marker is the `LoaderEntrySelected` EFI variable, which the
upgrade job logs in its sd-boot probe before every reboot:

- Healthy: the variable names the currently running version, or one version
  behind it. Warm upgrade reboots leave it one behind (observed on every
  node so far), and a cold boot refreshes it to current (observed on m3).
- Investigate: more than one cycle stale. m3 entered its hang with the
  variable frozen at a v1.13.5-era entry that no longer existed on the boot
  partition — firmware NVRAM writes had been silently failing for months
  before the hang.

Read it live (UTF-16LE content behind a 4-byte attribute header):

```sh
talosctl -n <node> read \
  /sys/firmware/efi/efivars/LoaderEntrySelected-4a67b082-0a4c-41cf-b6c7-440b29bb8c4f | xxd
```

## Recovery

Hold the power button ~5 seconds, then start the machine. This is the whole
procedure and needs no technical skill on site: the node boots the already
installed target version, rejoins, and (observed on m3) the cold boot also
refreshes the stale variable. Afterwards follow the failed-rollout recovery
order in [`node-upgrades.md`](node-upgrades.md) — uncordon, Ceph
`HEALTH_OK`, tuppr reset.

There is no remote fix: the hang precedes the OS, so watchdogs never arm,
and Wake-on-LAN does nothing to a machine that is on but hung.

## BIOS hardening

On every node: set After Power Failure to Power On. Combined with a smart
plug per node, that converts a firmware hang from an on-site visit into a
30-second remote power cycle — the only insurance that works at this failure
stage.

On a unit that has shown the stale-variable marker or hung: check the vendor
for a newer BIOS build (a flash typically rebuilds the NVRAM store), load
setup defaults to clear accumulated variable state, delete stale boot
entries, and disable Fast Boot, UEFI PXE, and CSM. Secure Boot stays off —
the UKIs are unsigned. If the variable re-freezes after this treatment, the
NVRAM flash itself is failing and the board is on borrowed time.

The BIOS update and this hardening are tracked in #872.

## Node-level log noise: kernel audit spam

`audit: rate limit exceeded` lines and large `audit_lost` counters in the
dashboard and dmesg are SELinux AVC denial records, generated at thousands
per second by Ceph daemons writing to data directories that predate the
Talos SELinux policy (`unlabeled_t`). SELinux runs permissive: everything is
logged, nothing is blocked, and the workloads are unaffected. The cost is
that the kernel audit trail is effectively unusable while the flood lasts.

This is an upstream policy-maturity issue (the same class as
[talos#13807](https://www.github.com/siderolabs/talos/issues/13807)), not a
local fault. Wait for shipped-policy fixes rather than disabling SELinux or
kernel audit, which would trade security posture for silence.
