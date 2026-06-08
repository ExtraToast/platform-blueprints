# Feature Specification: Round-2 Operations Blueprints

## Overview

This feature extends platform-blueprints with the Round-2 extraction candidates assigned to this repository: a Vault bootstrap framework, reusable backup/restore tooling, and completion notes for the NixOS flake/base/k3s scaffolding already present in `specs/001-platform-blueprints`. The shared artifact must provide reusable operator mechanics only; consumer repositories continue to own concrete policies, roles, host paths, service names, inventories, secrets, domains, and generated cluster state.

## Functional Requirements

- **FR-001**: The repository shall document that NixOS flake scaffolding plus base and k3s host modules are implemented by the existing 001 feature and remain part of the Round-2 platform-blueprints surface.
- **FR-002**: The repository shall add a reusable Vault bootstrap script that idempotently enables Kubernetes auth, writes Kubernetes auth config without persisting a reviewer JWT, enables caller-declared secret engines, writes caller-supplied policies, writes caller-supplied Kubernetes auth roles, and creates caller-supplied transit keys.
- **FR-003**: Vault bootstrap inputs shall be supplied through environment variables, directories, and TSV manifests owned by the consumer; the shared script shall not embed consumer policy names, namespaces, secret paths, service accounts, or transit key names.
- **FR-004**: The repository shall provide a Kubernetes Job template for running the shared Vault bootstrap script from a consumer-owned ConfigMap or image.
- **FR-005**: The repository shall add a manifest-driven backup tool that reads a TSV manifest of host group, service name, source path, required flag, and description, then produces tar.gz archives, metadata, archive tables, and checksums.
- **FR-006**: The backup tool shall support list and dry-run modes, service filtering, host-group filtering, and host connection details via `BACKUP_<GROUP>_*` environment variables.
- **FR-007**: The repository shall add a backup verification tool that validates required manifest entries, required service-native snapshot names supplied by the caller, and checksum files for a run directory.
- **FR-008**: The repository shall add generic restore tools for PVC archives, hostpath archives over SSH, Vault raft snapshots, and RabbitMQ definitions imports.
- **FR-009**: Destructive restore behavior shall require explicit flags or existing user credentials and shall validate required commands and input files before changing remote state.
- **FR-010**: The flake shall export the new scripts as packages and apps with concise names.
- **FR-011**: Repository validation shall check shell syntax and extraction boundaries for the new files.
- **FR-012**: Documentation shall include examples, manifest format, safety boundaries, and the deferred follow-ups: observability pack and Flux core/cert-manager/edge bases.

## Success Criteria

- **SC-001**: A sample backup manifest can be listed in dry-run mode without requiring network access.
- **SC-002**: A generated sample backup run verifies successfully, and a checksum mismatch fails verification.
- **SC-003**: Restore tools fail deterministically when required commands, archives, targets, or credentials are missing.
- **SC-004**: Vault bootstrap passes shell syntax and input validation without embedding consumer-local policy or role names.
- **SC-005**: `scripts/validate-repository.sh` and flake script checks include every new script.
- **SC-006**: README and plan explicitly defer observability pack and Flux core/cert-manager/edge bases.

## Out of Scope

- Moving or modifying personal-stack or website.
- Shipping live Vault policies, service accounts, namespaces, secret paths, domains, hostnames, IPs, backup manifests, or restore runbooks from a consumer repository.
- Implementing the observability pack.
- Implementing Flux core, cert-manager, or edge base manifests.
- Publishing backup archives or service-native snapshots.
