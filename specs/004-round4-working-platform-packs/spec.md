# Feature Specification: Round-4 Working Platform Packs

## Overview

Round 4 promotes the round-3 design-first skeletons into working,
parameterized packs while preserving the shared artifact boundary. The new
surface covers opt-in NixOS host roles, Traefik edge middleware, a RabbitMQ
data-service Flux pack, and an offline Vault bootstrap policy compiler.

All implementation artifacts must remain consumer-neutral. Consumers supply
domains, namespaces, hostnames, storage classes, OAuth issuers, queue/exchange
names, Vault addresses, secret names, image references, node selectors, and
network assumptions through Nix options, Flux `postBuild.substitute`, or input
models.

## Functional Requirements

- **FR-001**: NixOS host role modules shall remain opt-in and shall not alter
  the existing round-2 `base` and `k3s` defaults unless explicitly enabled.
- **FR-002**: NixOS roles shall cover k3s bootstrap defaults, control-plane,
  worker, utility host, GPU, Raspberry Pi image/profile assumptions, and
  Tailscale/network integration.
- **FR-003**: The repository shall expose a fleet-to-flake helper pattern that
  maps caller-owned fleet data to caller-owned host modules without committing
  inventory, SSH targets, secrets, or flake locks.
- **FR-004**: The edge middleware pack shall provide Traefik forward-auth,
  response/security headers, named CSP profiles, local certificate file-provider
  config, and optional dashboard exposure manifests.
- **FR-005**: The edge middleware pack shall use substitution placeholders for
  every environment-specific value.
- **FR-006**: The RabbitMQ pack shall provide Flux manifests for a RabbitMQ
  Helm release with OAuth2 management configuration, internal broker
  credentials synced via Vault Secrets Operator, plugin configuration,
  ServiceMonitor support, storage, resources, and placement.
- **FR-007**: The RabbitMQ pack shall not define application-specific queues,
  exchanges, users, vhosts, bindings, or domains.
- **FR-008**: The Vault bootstrap policy compiler shall compile a YAML input
  model into deterministic multi-document Kubernetes YAML containing bootstrap
  policy/script resources plus VSO static and dynamic secret manifests.
- **FR-009**: The compiler model shall cover Kubernetes auth roles, VSO auth
  roles, KV paths, transit keys, database dynamic credentials, and RabbitMQ
  dynamic credentials.
- **FR-010**: Repository validation shall parse or smoke-check all new scripts
  and manifests without requiring a live cluster, network access, Docker, Nix,
  Gradle, npm, kubeconform, or kustomize.

## Success Criteria

- **SC-001**: `bash scripts/validate-repository.sh` succeeds offline.
- **SC-002**: New YAML manifests are syntactically valid before substitution
  and do not contain reference repository domains, hostnames, namespaces, IPs,
  or absolute personal paths.
- **SC-003**: The Vault compiler emits stable multi-document YAML for both the
  minimal fixture and the fuller example model.
- **SC-004**: New flake outputs expose NixOS role modules and the Vault
  compiler package/app.
- **SC-005**: Live-only operations are limited to generated Vault CLI commands
  and cluster application of the rendered manifests.

## Out of Scope

- Modifying `/workspace/personal-stack` or `/workspace/website`.
- Running live Vault, Flux, kubeconform, kustomize, Docker, Gradle, npm, or Nix
  validation in this sandbox.
- Shipping consumer inventory, rendered Flux output, application routing,
  queue/exchange topology, Vault secret values, or private network details.
