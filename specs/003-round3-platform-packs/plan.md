# Implementation Plan: Round-3 Platform Packs

## Chosen Technology

- **Bash scripts** for render validation and backup tooling, matching existing repository conventions.
- **Flux/Kustomize YAML packs** with substitution placeholders so consumers provide environment-specific values through Flux `postBuild.substitute`, kustomize replacements, or their own renderer.
- **TSV manifests** for backup filesystem scope and snapshot plugin declarations because they are simple to audit and shell-native.
- **Markdown/docs plus YAML fixtures** for design-first items, keeping them explicit but non-production.

## Architecture

The implementation adds four extract-now areas:

- `scripts/validate-flux.sh` is extended with retry and offline controls, and `scripts/validate-platform-render.sh` orchestrates caller-owned render commands plus generated-file drift checks.
- `packs/flux-core` and `packs/edge` contain parameterized Flux bases for CRD-owning core components and edge primitives.
- `packs/observability` contains parameterized Flux bases for telemetry components and a reusable Gatus app base.
- `scripts/backup` contains generic filesystem backup, service-native snapshot plugin capture, verification, and coverage audit tooling with sample fixtures.

Design-first items live under `skeletons/`, `fixtures/`, and `docs/`:

- `skeletons/nixos-host-roles`
- `skeletons/edge-middleware`
- `skeletons/rabbitmq-data-service`
- `skeletons/vault-bootstrap-policy`
- `docs/dns-zone-policy.md`

## Requirement Traceability

| Requirement | Design Element |
| --- | --- |
| FR-001 | `scripts/validate-flux.sh` supports kustomize, flux-local, in-repo charts, retry, offline mode, and strict kubeconform schemas. |
| FR-002 | `scripts/validate-platform-render.sh` accepts render commands and generated paths from caller-owned files. |
| FR-003 | `packs/flux-core/*` component bases. |
| FR-004 | `packs/edge/*` component bases and docs. |
| FR-005 | Flux substitution placeholders in core and edge manifests. |
| FR-006 | `packs/observability/*` component bases. |
| FR-007 | `packs/observability/gatus/*`. |
| FR-008 | `scripts/backup/backup-service-state.sh`. |
| FR-009 | `scripts/backup/backup-service-snapshots.sh` and `examples/backup/snapshot-plugins.tsv`. |
| FR-010 | `scripts/backup/verify-backup-run.sh`. |
| FR-011 | `scripts/backup/audit-backup-scope.sh`. |
| FR-012 | `flake.nix` package/app exports. |
| FR-013 | `scripts/validate-repository.sh`. |
| FR-014 | `skeletons/`, `fixtures/`, and `docs/dns-zone-policy.md`. |

## Validation

- Run `bash scripts/validate-repository.sh`.
- Run `bash tests/scripts/backup-tooling-smoke.sh`.
- Run `nix flake check --print-build-logs` when Nix is available.

Networked tools such as `flux-local --enable-helm`, `helm` chart downloads, `kubeconform` remote schema fetches, Gradle, and npm are intentionally not run in this sandbox.
