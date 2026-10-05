# Node Boot and Firmware

Verified 2026-10-05 against the repository at `main`; not against the nodes.

A powered node with link but no traffic may have a boot problem; the pattern
does not identify its stage. Check the [access path](break-glass.md) and
remaining redundancy before choosing a physical intervention. A second lost
control-plane node can remove etcd quorum.

## Diagnosis and recovery

Read the upgrade Job's retained logs for installer completion and boot-loader
probes; [observability](../operations/observability.md) covers their
retrieval. Compare the running/default/selected entry with the image files
actually present where accessible. Completion in a log is evidence, not proof
that the next boot will succeed.

Talos installs sd-boot at a removable-media fallback path, and kexec can
legitimately leave `LoaderEntrySelected` stale because it bypasses firmware.
The [Talos 1.14.2
implementation](https://redirect.github.com/siderolabs/talos/blob/f513c7358cefc69255e29b517ba96c651e0326ad/internal/app/machined/pkg/runtime/v1alpha1/bootloader/sdboot/sdboot.go)
handles that distinction. A stale entry alone proves neither an unbootable
installation nor failing NVRAM.

A cold power operation needs approval for the identified node. Hold power for
about five seconds, then start it; where a verified power switch exists,
power off, wait ten seconds and restore power. Verify the recovery-power
setting before relying on unattended restart. Afterwards, read the running
version, Talos API, etcd and Ceph health, then follow [failed-upgrade
recovery](../../.agents/skills/upgrade-nodes/references/node-upgrades.md#failed-upgrades).

Do not use forced `powercycle` reboot/upgrade mode as a workaround: it has
left these nodes at the boot-loader screen. The manual recipes use the
default mode for that reason.

## Firmware updates

Flash one node at a time: drain, flash, verify boot and health, restore
scheduling, then consider the next. Match the package BIOS ID to the board's
DMI `bios_version`; verify vendor origin and published hash as well. A
matching download hash does not establish the correct hardware family.

Before leaving setup, check recovery power, fast/network boot and
compatibility support. The [declared installer](../../talos/cluster.yaml.j2)
is not a Secure Boot image: enabling Secure Boot without compatible signed
assets and enrolled trust can prevent boot. Adopting that path needs a
separate plan; verify actual settings after loading defaults. A flash is not
an established repair for boot-variable state.
