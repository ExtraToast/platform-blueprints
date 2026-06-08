# Implementation Plan: Round-2 Operations Blueprints

## Chosen Technology

- **Bash**: The reference operations are shell orchestration around `vault`, `ssh`, `kubectl`, `tar`, `curl`, and checksum tools. Keeping the shared surface as Bash preserves the operator model and packages cleanly through the flake.
- **Nix flake packages/apps**: Existing platform-blueprints distribution already exports scripts as executable packages and apps.
- **TSV manifests**: The reference backup engine uses a simple tab-separated manifest. TSV remains sufficient for shell-native filtering and auditability.
- **Kubernetes YAML template**: A static Job template is enough for the shared Vault bootstrap execution shape while leaving image, namespace, service account, and ConfigMap content to consumers.

## Architecture

The existing 001 feature owns the NixOS flake scaffolding plus base/k3s module extraction. This feature adds `scripts/vault`, `scripts/backup`, and `scripts/restore` subtrees. All inputs that could identify a consumer are arguments, environment variables, or consumer-provided files.

Vault bootstrap is split into a shared engine and consumer data:

- Engine: `scripts/vault/bootstrap-vault.sh`
- Consumer policies: `VAULT_BOOTSTRAP_POLICY_DIR/*.hcl`
- Consumer Kubernetes roles: `VAULT_BOOTSTRAP_ROLE_FILE` TSV
- Consumer mounts and transit keys: environment lists
- Job template: `templates/vault/bootstrap-job.yaml`

Backup and restore are similarly split:

- Engine: `scripts/backup/backup-service-state.sh`
- Verification: `scripts/backup/verify-backup-run.sh`
- Consumer manifest: `BACKUP_MANIFEST_FILE`, with `examples/backup/manifest.tsv` as a non-live sample
- Restore tools: `scripts/restore/*.sh`

## Requirement Traceability

| Requirement | Design Element |
| --- | --- |
| FR-001 | README and this plan describe C4/C5 as covered by the 001 feature. |
| FR-002 | `scripts/vault/bootstrap-vault.sh` handles auth, config, mounts, policies, roles, and transit keys. |
| FR-003 | Vault inputs come from env vars, policy dir, and role TSV. |
| FR-004 | `templates/vault/bootstrap-job.yaml` provides the generic job shape. |
| FR-005 | `scripts/backup/backup-service-state.sh` writes run metadata, archive table, checksums, and archives. |
| FR-006 | Backup flags and `BACKUP_<GROUP>_*` env vars support filtering, list, and dry-run modes. |
| FR-007 | `scripts/backup/verify-backup-run.sh` validates required manifest rows, snapshots, and checksums. |
| FR-008 | `scripts/restore/restore-pvc-archive.sh`, `restore-hostpath-archive.sh`, `restore-vault-raft-snapshot.sh`, and `restore-rabbitmq-definitions.sh`. |
| FR-009 | Restore scripts validate commands/files and require explicit destructive flags. |
| FR-010 | `flake.nix` exports packages and apps for each script. |
| FR-011 | `scripts/validate-repository.sh` includes recursive shell syntax and boundary checks. |
| FR-012 | README documents usage and follow-ups. |

## Deferred Follow-Ups

- Observability pack remains deferred. It should be specified separately before extracting dashboards, alert rules, or telemetry stack manifests.
- Flux core, cert-manager, and edge bases remain deferred. They should be specified separately before extracting any Flux application tree, issuer, middleware, or ingress-controller base.

## Validation

- Run `bash scripts/validate-repository.sh`.
- Run local script smoke tests in `tests/scripts/backup-tooling-smoke.sh`.
- Run `nix flake check --print-build-logs` when Nix is available.
