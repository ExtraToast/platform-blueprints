# Feature Specification: Round-3 Platform Packs

## Overview

This feature adds the round-3 `platform-blueprints` extraction surface: a Flux render validation pack, reusable Flux core and edge pack manifests, an observability pack with a Gatus app base, and backup manifest/snapshot plugin extensions. It also captures the design-first platform items as specs plus skeleton inputs only: richer NixOS host roles and fleet-to-flake, edge middleware policy, RabbitMQ OIDC/data-service, DNS zone policy, and Vault bootstrap policy/dynamic secrets.

All extract-now packs must be consumer-neutral. Consumers supply namespaces, domains, hostnames, ACME emails, secret names, storage sizes, node selectors, service endpoints, snapshot commands, and backup source paths. The shared repository must not carry reference repository domains, host names, IPs, namespaces, paths, queue/exchange names, image prefixes, or service-specific policy values.

## Functional Requirements

- **FR-001**: The Flux validation scripts shall render a caller-supplied kustomize cluster path, optionally render Flux HelmReleases with `flux-local --enable-helm`, render in-repo Helm charts under caller-supplied app roots, retry only remote chart expansion, and validate the full rendered tree with strict kubeconform and explicit CRD schema locations.
- **FR-002**: The validation pack shall provide an orchestration script for consumer render commands and expected generated-output paths without hardcoding any consumer repository layout.
- **FR-003**: The Flux core pack shall provide parameterized bases for cert-manager, external-dns, public Traefik, optional LAN Traefik/MetalLB, and Vault Secrets Operator.
- **FR-004**: The edge pack shall provide parameterized Cloudflare ClusterIssuer, default TLSStore, forward-auth middleware, and route/middleware extension points without shipping application IngressRoutes.
- **FR-005**: Flux core and edge manifests shall expose ACME email/server, token secret names, domain filters, TXT owner ID, Traefik service mode, host ports, node selectors, forward-auth endpoint, response headers, and VSO Vault connection as consumer substitutions.
- **FR-006**: The observability pack shall provide parameterized bases for metrics, logs, traces, Grafana, Grafana Operator dashboards, Alloy, optional Pyroscope/DCGM, alert rules, and Gatus.
- **FR-007**: The Gatus app base shall mount a consumer-supplied endpoint ConfigMap and a shared UI/config ConfigMap, use a single replica with a PVC-safe strategy, and expose namespace, image, PVC size, and resources as inputs.
- **FR-008**: Backup filesystem tooling shall read a TSV manifest of host group, service name, source path, required flag, and description; it shall support arbitrary host groups with `BACKUP_<GROUP>_*` SSH environment variables, dry-run, list, group filtering, and service filtering.
- **FR-009**: Backup snapshot tooling shall read a TSV plugin manifest whose commands are caller-owned script paths; it shall capture selected service-native snapshots, write metadata, and checksum every artifact.
- **FR-010**: Backup verification shall validate required manifest entries, required snapshot plugins supplied by the caller, and archive/snapshot checksum files.
- **FR-011**: Backup coverage audit shall compare a caller-supplied expected-path file with the backup manifest and optional exclusion file; it shall not parse consumer Nomad/Consul config paths directly.
- **FR-012**: The flake shall export all new scripts as packages and apps with concise names.
- **FR-013**: Repository validation shall cover shell syntax, JSON/YAML syntax, public output naming, and extraction-boundary scans for new implementation files.
- **FR-014**: Design-first items shall ship only spec text, docs, skeleton input models, and fixtures. They shall not include production renderers or copied manifests.

## Success Criteria

- **SC-001**: `bash scripts/validate-repository.sh` succeeds locally without network access.
- **SC-002**: The backup smoke test exercises list, dry-run, snapshot capture from local fixture plugin commands, verification success, and checksum failure.
- **SC-003**: Every pack manifest parses as YAML before consumer substitution and contains no reference repository domains, IPs, hostnames, namespaces, or absolute personal paths.
- **SC-004**: The flake exposes new package/app names for render validation, backup state, backup snapshots, verification, and coverage audit.
- **SC-005**: Design-first deliverables are present as specs, docs, skeletons, and fixtures only.

## Design-First Scope

- NixOS host roles and fleet-to-flake pattern: opt-in role model, Raspberry Pi image placeholder, Tailscale/network assumption inputs, and fleet fixture.
- Edge middleware and local Traefik policy: forward-auth, response headers, security headers, CSP profile names, local cert paths, and dashboard exposure skeleton.
- RabbitMQ OIDC/data-service blueprint: OAuth2 management, internal broker credentials, Vault dynamic backend, plugin list, ServiceMonitor, storage, and placement skeleton.
- DNS zone policy: documentation for Cloudflare imports, mail records, proxy exceptions, external-dns ownership, and direct-origin rules.
- Vault bootstrap policy/dynamic-secret pack: input model for Kubernetes auth roles, VSO roles, KV paths, transit keys, database dynamic credentials, RabbitMQ dynamic credentials, and validation fixtures.

## Out of Scope

- Modifying reference repositories.
- Implementing production renderers for the design-first items.
- Shipping app-specific IngressRoutes, dashboards, Vault policies, DNS zone files, RabbitMQ queues/exchanges, host inventories, rendered Flux output, backup manifests from a consumer, or secrets.
- Running networked validation in this sandbox.
