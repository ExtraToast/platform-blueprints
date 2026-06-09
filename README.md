# platform-blueprints

Reusable NixOS, k3s, and Flux building blocks published as a Nix flake.

## Consumer Boundary

This repository is a shared platform artifact, not a deployable environment. It may contain:

- Generic NixOS modules for baseline hosts, k3s behavior, and reusable roles.
- Generic bootstrap and validation scripts that take caller-owned paths and host targets.
- Tests, examples, CI, and release metadata for this artifact.

Consumer repositories continue to own host modules, disko definitions, deploy nodes, inventories, secrets, app manifests, generated manifests, flake locks, and deployment workflows.

Do not add private keys, token values, inventory files, application manifests, rendered Flux output, Nomad jobs, Consul jobs, or consumer host data to this repository.

## Flake Usage

Pin the flake in a consumer repository:

```nix
{
  inputs.platform-blueprints.url = "github:ExtraToast/platform-blueprints/v0.1.0";
}
```

Import modules in consumer-owned host modules:

```nix
{ inputs, ... }:
{
  imports = [
    inputs.platform-blueprints.nixosModules.base
    inputs.platform-blueprints.nixosModules.k3s
    inputs.platform-blueprints.nixosModules.roleControlPlane
  ];

  platformBlueprints.base = {
    enable = true;
    ssh.ports = [ 22 ];
    resolver.nameservers = [ "203.0.113.10" ];
    timeZone = "UTC";
    defaultLocale = "en_US.UTF-8";
  };

  platformBlueprints.roles.controlPlane.enable = true;
}
```

Available module outputs:

- `nixosModules.base`
- `nixosModules.k3s`
- `nixosModules.roleControlPlane`
- `nixosModules.roleWorker`
- `nixosModules.roleGpuAmd`
- `nixosModules.roleGpuNvidia`
- `nixosModules.roleUtilityHost`
- `nixosModules.roles.*`

## Scripts

Copy a k3s agent token between caller-supplied SSH targets:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#bootstrap-k3s-agent-token -- \
  --control-plane user@control-plane.example.invalid \
  --agent user@agent.example.invalid \
  --source-token-path /var/lib/rancher/k3s/server/node-token \
  --target-token-path /var/lib/k3s/agent-token
```

Validate a consumer-owned Flux tree:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#validate-flux -- \
  --flux-root ./platform/cluster/flux \
  --cluster-path ./platform/cluster/flux/clusters/production \
  --enable-helm
```

Both scripts validate required commands and inputs before doing work.

Run consumer-owned render commands and fail if generated files drift:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#validate-platform-render -- \
  --repo-root "$PWD" \
  --render-command-file ./platform/render-commands.txt \
  --generated-path-file ./platform/generated-paths.txt
```

## Flux Packs

Reusable parameterized packs live under:

- `packs/flux-core`: cert-manager, external-dns, Traefik public/LAN, MetalLB, and VSO bases.
- `packs/edge`: Cloudflare ClusterIssuer, default TLSStore, and forward-auth middleware.
- `packs/observability`: metrics, Grafana, Loki, Tempo, Alloy, Gatus, alerts, and optional profiling/GPU telemetry.

The manifests use substitution placeholders. Consumers provide namespaces,
domains, ACME emails, token secret names, storage sizes, node selectors,
forward-auth endpoints, and component choices through their own Flux
`postBuild.substitute`, kustomize replacements, or renderer. Application
IngressRoutes, service-specific dashboards, and Gatus endpoint ConfigMaps stay
in consumer repositories.

## Backup Toolkit

List and dry-run a manifest-driven remote filesystem backup:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#backup-service-state -- \
  --manifest ./backups/manifest.tsv \
  --dry-run
```

Capture service-native snapshot plugins declared by the consumer:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#backup-service-snapshots -- \
  --plugins ./backups/snapshot-plugins.tsv \
  --output-dir ./backups/run-$(date -u +%Y%m%dT%H%M%SZ)
```

Verify a run:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#verify-backup-run -- \
  --run-dir ./backups/run-example \
  --manifest ./backups/manifest.tsv \
  --required-snapshot vault-raft-snapshot
```

Audit backup coverage against caller-owned expected paths:

```bash
nix run github:ExtraToast/platform-blueprints/v0.1.0#audit-backup-scope -- \
  --manifest ./backups/manifest.tsv \
  --expected-paths ./backups/expected-paths.tsv
```

Snapshot plugin commands are caller-owned executables that write payload bytes
to stdout. This repository does not embed Vault, Consul, Nomad, RabbitMQ, host
paths, or credential lookup commands.

## Design-First Skeletons

Round-3 design-first placeholders are under `skeletons/`, `fixtures/`, and
`docs/`:

- `skeletons/nixos-host-roles`
- `skeletons/edge-middleware`
- `skeletons/rabbitmq-data-service`
- `skeletons/vault-bootstrap-policy`
- `docs/dns-zone-policy.md`

These are input models and documentation only, not production renderers.

## Versioning

Releases are managed with release-please. Consumers should pin an exact tag or locked revision and let Renovate propose updates in their own repository. Each consumer can review and advance the shared platform version independently.

## Local Validation

```bash
bash scripts/validate-repository.sh
bash tests/scripts/backup-tooling-smoke.sh
nix flake check --print-build-logs
```

If Nix is unavailable, the repository validation script still checks shell syntax, workflow/config syntax, output naming, and extraction boundaries.
