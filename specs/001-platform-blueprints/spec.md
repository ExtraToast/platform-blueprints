# Feature Specification: Platform Blueprints

## Overview

ExtraToast/platform-blueprints exists to provide reusable NixOS, k3s, and Flux platform building blocks as a versioned Nix flake input. The repository should package generic module subsets and generic bootstrap or validation scripts that can be consumed by repositories such as personal-stack and website without moving consumer-owned infrastructure state into the shared artifact.

The reference material is the current platform code in `/workspace/personal-stack/platform/nix`, especially the base, k3s, and roles modules, plus `/workspace/personal-stack/platform/cluster/flux` and `/workspace/personal-stack/platform/scripts`. Those paths illustrate the behavior to generalize, but they also contain local host data, secrets wiring, app manifests, rendered Flux outputs, and deployment details that must remain in each consumer repository.

The intended outcome is a small, reusable platform artifact with short flake coordinates, concise exported names, no doubled plugin-marker names, and dependency updates managed by Renovate-pinned versions in consumers. personal-stack remains continuously auto-deployed and is not itself treated as a versioned shared artifact.

## User Scenarios

1. **Consumer imports shared NixOS modules**
   - Given a consumer repository with its own Nix flake, host modules, inventory, secrets, and deployment outputs
   - When the consumer pins ExtraToast/platform-blueprints as a flake input and imports the exported module subsets
   - Then the consumer can reuse the shared base, k3s, and role behavior while retaining all concrete host and environment data locally

2. **Consumer validates platform manifests**
   - Given a consumer repository with its own Flux root, cluster overlays, rendered output policy, and optional Helm or CRD validation tools
   - When the consumer invokes the generic validation entrypoint with consumer-owned paths and options
   - Then the validation reports deterministic success or failure without depending on personal-stack paths, generated files, or app manifests embedded in the shared artifact

3. **Consumer bootstraps or deploys a host**
   - Given a consumer repository that owns host names, SSH details, install state, deploy keys, and flake locks
   - When the consumer invokes a generic bootstrap, install, or deploy entrypoint using its own host data source
   - Then the entrypoint validates required local inputs and delegates to the consumer flake without exposing host data through platform-blueprints

4. **Maintainer audits extraction boundaries**
   - Given a proposed platform-blueprints release
   - When the exported modules, scripts, docs, examples, and tests are reviewed
   - Then no host data, secrets, app manifests, Nomad or Consul jobs, consumer inventory, or rendered Flux outputs are present in the shared artifact

5. **Pinned platform update reaches consumers**
   - Given a new platform-blueprints version
   - When Renovate opens a pinned dependency update in a consumer repository
   - Then the consumer can review the shared artifact bump separately from its continuously deployed local infrastructure state

## Functional Requirements (FR-n)

- **FR-1**: The repository shall define platform-blueprints as a reusable, versioned Nix flake input intended for consumer repositories rather than as a deployable environment.
- **FR-2**: The flake interface shall expose generic NixOS module subsets for base host configuration, k3s bootstrap or node behavior, and role composition derived from the reference base, k3s, and roles modules.
- **FR-3**: Exported module and option names shall use consumer-neutral naming and shall not preserve consumer-specific namespaces, host names, domains, IP addresses, or local identity labels from the reference repositories.
- **FR-4**: The base module subset shall express reusable host baseline behavior only, with all deploy keys, user-specific values, DNS choices, time zone, locale, and other environment-specific values supplied or overridden by the consumer.
- **FR-5**: The k3s module subset shall support server and agent roles, API endpoint selection, join-token path selection, node labels, node taints, firewall needs, and network interface assumptions as consumer-supplied or documented values.
- **FR-6**: Role module subsets shall remain generic enough for multiple consumers and shall not reference local app manifests, local RBAC identities, local ingress names, local storage layouts, or local observability dashboards.
- **FR-7**: Generic bootstrap, install, deploy, render, and validation scripts shall accept consumer-owned paths, host identifiers, and configuration inputs instead of assuming the `/workspace/personal-stack` repository layout.
- **FR-8**: Generic scripts shall validate missing commands and required consumer inputs with deterministic exit codes and clear stderr messages.
- **FR-9**: Flux validation support shall operate on consumer-supplied Flux roots and cluster overlays, and it shall not ship personal-stack or website app manifests, cluster manifests, secret references, generated ConfigMaps, or rendered Flux outputs.
- **FR-10**: platform-blueprints shall not contain host data, secrets, private key material, token values, app manifests, Nomad jobs, Consul jobs, `platform/inventory/fleet.yaml`, or rendered Flux output files from any consumer repository.
- **FR-11**: Consumer repositories shall continue to own their NixOS host modules, deploy-rs nodes, disko configurations, inventory, app manifests, secrets, flake locks, and continuous deployment behavior.
- **FR-12**: Distribution naming shall use short coordinates and concise flake outputs; names shall avoid duplicated repository or plugin-marker segments.
- **FR-13**: Consumers shall consume platform-blueprints through pinned flake references and Renovate-managed version updates, allowing each consumer to advance at its own reviewed cadence.
- **FR-14**: personal-stack shall remain a continuously auto-deployed consumer and shall not become a versioned distribution artifact as part of this feature.
- **FR-15**: Documentation for the feature shall explain the consumer boundary, allowed shared surfaces, forbidden local artifacts, and expected flake-input consumption model.

## Success Criteria (SC-n, measurable)

- **SC-1**: A boundary audit of exported module, script, example, and documentation files finds zero consumer host names, consumer IP addresses, secret values, app manifests, Nomad jobs, Consul jobs, inventory files, or rendered Flux outputs.
- **SC-2**: At least one consumer fixture or consumer repository can evaluate every exported NixOS module subset through a pinned platform-blueprints flake input without importing host data from platform-blueprints.
- **SC-3**: Generic validation entrypoints can be invoked with consumer-supplied Flux paths and return deterministic nonzero failures for missing tools or missing required inputs.
- **SC-4**: The flake interface exposes concise coordinates and output names, and a name audit finds zero doubled plugin-marker or repository-marker segments.
- **SC-5**: A Renovate-pinned update can represent a platform-blueprints version change in a consumer repository without requiring personal-stack to publish its own versioned release.
- **SC-6**: The documented Out of Scope list is sufficient for a reviewer to classify each referenced personal-stack or website file as either reusable shared behavior or consumer-local state.

## Assumptions

- Consumer repositories keep their own flake locks and choose when to accept platform-blueprints updates.
- personal-stack and website may consume the shared artifact, but either repository may pin a different platform-blueprints version.
- Existing reference modules are examples of behavior to generalize, not files to copy wholesale.
- Some current reference modules are too local to extract unless their local values are removed or turned into consumer-owned inputs.
- A versioned artifact means platform-blueprints itself carries versionable references or release points; it does not require personal-stack to stop continuous deployment or publish releases.

## Edge Cases

- A consumer has NixOS hosts but no k3s cluster.
- A consumer has k3s nodes but no Flux-managed applications.
- A consumer uses a different tailnet, LAN, DNS provider, OIDC provider, SSH port, user model, or storage layout than the reference repositories.
- A validation command needs remote chart or CRD schemas and the consumer wants to run in an offline environment.
- Two consumers pin different platform-blueprints versions and need backward-compatible exported names.
- A reference script currently writes rendered Flux files, but a consumer expects generated output to remain local and reviewable in its own repository.
- A role that appears reusable still embeds local app, auth, storage, or observability assumptions.

## Key Entities

- **Platform Blueprint Artifact**: The versioned ExtraToast/platform-blueprints flake consumed by downstream repositories.
- **Consumer Repository**: A repository such as personal-stack or website that owns concrete hosts, inventory, secrets, app manifests, and deployment state.
- **Module Subset**: A reusable NixOS module group exported by platform-blueprints, such as base host behavior, k3s behavior, or role composition.
- **Generic Script**: A bootstrap, install, deploy, render, or validation entrypoint that works from consumer-supplied paths and inputs.
- **Local Consumer State**: Host data, secrets, inventory, app manifests, deploy nodes, generated manifests, and environment-specific values that remain outside platform-blueprints.
- **Flake Input Coordinates**: The short consumer-facing reference and exported output names used to pin platform-blueprints.
- **Renovate-Pinned Version**: A consumer-owned dependency pin that advances platform-blueprints through reviewed update changes.

## Out of Scope

- Implementing NixOS modules, scripts, tests, or release automation.
- Moving, deleting, or modifying files in personal-stack or website.
- Publishing app manifests, Flux application trees, rendered Flux outputs, generated ConfigMaps, dashboards, or consumer cluster overlays from platform-blueprints.
- Publishing host inventories, `platform/inventory/fleet.yaml`, SSH addresses, deploy keys, tokens, private keys, or other secrets from any consumer.
- Publishing Nomad jobs or Consul jobs from any consumer.
- Replacing consumer flake locks, deploy-rs node definitions, disko host definitions, or continuous deployment workflows.
- Turning personal-stack into a versioned artifact or changing its auto-deployed operating model.
- Defining consumer-specific service catalogs, domains, ingress routes, RBAC identities, dashboards, or storage policies.
