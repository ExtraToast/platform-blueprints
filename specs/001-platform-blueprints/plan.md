# Implementation Plan: Platform Blueprints

## Technical Context

- **Repository**: ExtraToast/platform-blueprints
- **Feature Directory**: `specs/001-platform-blueprints`
- **Primary Surface**: Nix flake exposing reusable NixOS modules, package/app wrappers for scripts, checks, documentation, and release automation.
- **Reference Sources**: `/workspace/personal-stack/platform/nix/modules/{base,k3s,roles}` and selected bootstrap/validation behavior from `/workspace/personal-stack/platform/scripts`.
- **Spec Adjustment**: The original Out of Scope list excluded implementation files. That conflicted with this delivery, so the exclusion is narrowed to consumer repository changes and consumer-local artifacts.

## Chosen Technology

- **Nix flake**: Required distribution surface for consumers. The flake pins `nixpkgs`, exports `nixosModules.*`, packages script entrypoints as executable derivations, and provides checks that evaluate a fixture host.
- **NixOS modules**: Native module system is the correct abstraction for base host, k3s, and role behavior because consumers already compose NixOS host modules.
- **Bash scripts**: Existing operational entrypoints are shell scripts and the required behavior is command orchestration with deterministic input validation. Scripts remain standalone and are packaged as flake apps.
- **GitHub Actions + release-please**: CI terminates in the required `Pipeline Complete` job; release-please manages version tags without publishing consumer infrastructure state.

## Architecture

The artifact is a small flake repository. It contains no host modules, inventory, secrets, app manifests, Flux rendered outputs, Nomad jobs, or Consul jobs. Consumers import modules from `inputs.platform-blueprints.nixosModules` and pass concrete values through options in their own host modules.

The module namespace is `platformBlueprints.*`. It is consumer-neutral and avoids the reference repository namespace. Defaults are conservative: environment-specific values are unset unless the consumer supplies them, and role modules expose options for values that were hardcoded in the reference.

Script entrypoints accept caller-owned paths and host identifiers. They fail before doing work when required tools or inputs are missing. The Flux validator writes only temporary render output and accepts the Flux root and cluster overlay paths from the caller.

## Module and Script Layout

- `flake.nix`: Defines flake inputs, `nixosModules`, `packages`, `apps`, and `checks`.
- `modules/nixos/base.nix`: Generic baseline host module with firewall, SSH, packages, optional static resolver config, optional deploy user, optional locale, and optional time zone.
- `modules/nixos/k3s.nix`: Generic k3s bootstrap/node behavior with server/agent support, API endpoint, token path, labels, taints, flannel interface, firewall ports, and optional interface readiness wait.
- `modules/nixos/roles/control-plane.nix`: Generic control-plane composition with disabled bundled ingress/load balancer defaults and optional OIDC API server args.
- `modules/nixos/roles/worker.nix`: Generic k3s agent role default.
- `modules/nixos/roles/gpu-amd.nix`: Generic AMD GPU host role without consumer-specific storage or app assumptions.
- `modules/nixos/roles/gpu-nvidia.nix`: Generic NVIDIA GPU host role with k3s container runtime path handling.
- `modules/nixos/roles/utility-host.nix`: Generic utility firewall role with caller-overridable ports.
- `scripts/bootstrap-k3s-agent-token.sh`: Generic token copy from a caller-specified control plane host to a caller-specified agent host.
- `scripts/validate-flux.sh`: Generic Flux/kustomize/Helm/kubeconform validation from caller-supplied paths.
- `scripts/validate-repository.sh`: Local/CI fallback validation for syntax, schema, output naming, and extraction boundary checks.
- `tests/module-fixture.nix`: Consumer-style fixture used by flake checks to evaluate exported modules without host data.
- `.github/workflows/ci.yml`: Real gating validation job plus required terminal `Pipeline Complete`.
- `.github/workflows/release.yml`, `release-please-config.json`, `.release-please-manifest.json`: Version tag automation.
- `README.md`: Consumer boundary, flake usage, scripts, forbidden artifacts, and versioning model.

## Requirement Traceability

| Requirement | Design Element |
| --- | --- |
| FR-1 | `flake.nix` exposes versionable flake outputs and README describes consumer use. |
| FR-2 | `nixosModules.base`, `nixosModules.k3s`, and role outputs expose the reusable module subsets. |
| FR-3 | Options use `platformBlueprints.*`; outputs use concise neutral names; boundary validation scans for reference-local markers. |
| FR-4 | `base.nix` requires deploy keys, DNS, time zone, locale, SSH users, and resolver choices to be supplied or overridden by consumers. |
| FR-5 | `k3s.nix` supports server and agent roles, API endpoint, token path, labels, taints, firewall ports, and configurable flannel/wait interfaces. |
| FR-6 | Role modules remove local app, RBAC, ingress, storage, and dashboard references; OIDC and utility ports are options. |
| FR-7 | Bootstrap and validation scripts accept consumer-supplied hosts and paths instead of assuming a reference layout. |
| FR-8 | Scripts use shared validation helpers and deterministic nonzero exits for missing commands or required inputs. |
| FR-9 | `validate-flux.sh` operates on supplied Flux roots and overlays and writes only temporary output. |
| FR-10 | Repository validation scans for forbidden host data, inventory files, secret material markers, app manifests, jobs, and rendered output directories. |
| FR-11 | README states consumer repositories own host modules, deploy nodes, disko, inventory, manifests, secrets, locks, and deployment workflows. |
| FR-12 | Flake outputs are short names such as `base`, `k3s`, `roleWorker`, and `validate-flux`; validation checks for doubled marker names. |
| FR-13 | README documents pinned flake inputs and Renovate-managed updates. |
| FR-14 | README states consumer repositories remain independently deployed and are not versioned by this artifact. |
| FR-15 | README documents allowed shared surfaces, forbidden local artifacts, and expected consumption model. |

## Validation

- Run `.specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks`.
- Run `bash scripts/validate-repository.sh`.
- Run `nix flake check --print-build-logs` when Nix is available.
- CI runs the same repository validation and attempts `nix flake check` when `nix` is available, ending in `Pipeline Complete`.

## Risks and Decisions

- The reference install/deploy scripts depend on inventory parsing and deploy node ownership. They are not copied into this artifact because that state remains consumer-local.
- The reference control-plane module embeds local OIDC values. The extracted role will expose OIDC settings as options and default them off.
- The reference base module embeds deploy keys, resolver choices, locale, and time zone. The extracted base module turns those into consumer-owned options.
- The reference Flux validation uses fixed repository paths. The extracted validator requires explicit `--flux-root` and `--cluster-path` inputs.
