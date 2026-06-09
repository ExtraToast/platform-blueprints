# Implementation Plan: Round-4 Working Platform Packs

## Chosen Technology

- **NixOS modules** for opt-in host roles, matching the existing
  `platformBlueprints.*` option namespace.
- **Nix functions** for the fleet-to-flake pattern so callers can evaluate
  their own fleet data without this repository owning inventory.
- **Flux/Kustomize YAML** with Flux substitution placeholders for reusable
  Kubernetes packs.
- **Python standard library** for the Vault compiler, including a small
  repository-local YAML subset parser so offline validation does not require
  PyYAML or network access.

## Architecture

The implementation adds four working areas:

- `modules/nixos/roles/*` gains opt-in k3s bootstrap, Raspberry Pi, and
  Tailscale/network roles alongside the existing control-plane, worker,
  utility, and GPU roles.
- `lib/nixos/fleet-to-flake.nix` exposes helper functions for converting a
  caller-owned fleet model into host-module imports and deploy metadata.
- `packs/edge-middleware` and `packs/rabbitmq-data-service` provide reusable
  Flux manifests that render under kustomize and rely on Flux
  `postBuild.substitute` for concrete values.
- `scripts/vault/compile-vault-bootstrap-policy.py` compiles a declarative
  policy model into a ConfigMap, Job, VSO auth/static/dynamic-secret manifests,
  and live-only Vault CLI commands held in the bootstrap script.

## Requirement Traceability

| Requirement | Design Element |
| --- | --- |
| FR-001 | New NixOS role modules are disabled by default. |
| FR-002 | `modules/nixos/roles/*` and `flake.nix` exports. |
| FR-003 | `lib/nixos/fleet-to-flake.nix` and fixture fleet model. |
| FR-004 | `packs/edge-middleware/*`. |
| FR-005 | `${...}` placeholders in edge middleware manifests. |
| FR-006 | `packs/rabbitmq-data-service/*`. |
| FR-007 | RabbitMQ pack omits topology resources. |
| FR-008 | `scripts/vault/compile-vault-bootstrap-policy.py`. |
| FR-009 | `skeletons/vault-bootstrap-policy/policy-model.example.yaml` and fixtures. |
| FR-010 | `scripts/validate-repository.sh` smoke checks. |

## Validation

- Run `bash scripts/validate-repository.sh`.
- Run `bash tests/scripts/backup-tooling-smoke.sh`.
- Run `nix flake check --print-build-logs` outside this sandbox when Nix is
  available.
- Run live Vault bootstrap only after applying generated manifests to a target
  cluster with valid Vault address, token secret, CRDs, and VSO installation.
