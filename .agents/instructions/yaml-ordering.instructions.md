# YAML Ordering Instructions

Use these rules when editing YAML in this repository. They describe the repo's
current conventions, not a request to mass-sort files. Preserve nearby patterns
when they are more specific than these generic rules.

All YAML documents should start with `---`. Add a yaml-language-server schema
comment immediately below `---` when this repo already has a matching schema
pattern for that resource type.

## Kubernetes Resources

Top-level Kubernetes resource keys use this order:

1. `apiVersion`
2. `kind`
3. `metadata`
4. `spec`

Within `metadata`, use:

1. `name`
2. `namespace`
3. `annotations`
4. `labels`

Do not reformat SOPS-encrypted files.

## Flux HelmRelease

Within `spec`, use:

1. `chartRef`
2. `interval`
3. `dependsOn`
4. `install`
5. `upgrade`
6. `postRenderers`
7. `values`

Within `spec.values`, follow the chart's existing or upstream-documented order.
For bjw-s app-template workloads, identify app-template by the sibling
`ocirepository.yaml` URL (`oci://ghcr.io/bjw-s-labs/helm/app-template`) or the
app-template schema comment in `helmrelease.yaml`. Do not rely on
`spec.chartRef.name`, which is usually app-specific in this repo.

For app-template workloads, prefer the repo's current high-level order:

1. `controllers`
2. `defaultPodOptions`
3. `service`
4. `route`
5. `configMaps`
6. `persistence`

Omit absent sections rather than leaving placeholders.

For Home Operations charts such as `gatus-sidecar` and `konflate`, follow the
upstream chart or peer-repo value order rather than forcing app-template
ordering.

## Containers and Resources

Container sections normally put `image` first, then `env`, `envFrom`, `args`,
probes, `securityContext`, and `resources`, matching nearby files when they
differ.

Resource sections use:

1. `requests`
2. `limits`

## Embedded Config

Do not sort YAML embedded inside string values such as `configMaps.*.data`.
