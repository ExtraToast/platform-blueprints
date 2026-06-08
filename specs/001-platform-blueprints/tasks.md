# Tasks: Platform Blueprints

## Dependency Notes

Tasks run in dependency order. Validation scaffolding comes before product files so module, script, and boundary checks have a stable target. Tasks marked `[P]` touch independent files and may be implemented in parallel when the environment allows.

## Tasks

- [x] T001 [FR-1, FR-2, FR-3, FR-12, SC-2, SC-4] Create `flake.nix` with concise `nixosModules`, `packages`, `apps`, and `checks` outputs.
- [x] T002 [FR-2, FR-4, SC-2] Implement `modules/nixos/base.nix` with consumer-owned DNS, locale, time zone, deploy user, SSH, and package options.
- [x] T003 [FR-2, FR-5, SC-2] Implement `modules/nixos/k3s.nix` with server/agent behavior, token path, endpoint, labels, taints, firewall, and interface options.
- [x] T004 [P] [FR-2, FR-6, SC-2] Implement `modules/nixos/roles/control-plane.nix` and `modules/nixos/roles/worker.nix`.
- [x] T005 [P] [FR-2, FR-6, SC-2] Implement `modules/nixos/roles/gpu-amd.nix`, `modules/nixos/roles/gpu-nvidia.nix`, and `modules/nixos/roles/utility-host.nix`.
- [x] T006 [FR-7, FR-8, SC-3] Implement `scripts/bootstrap-k3s-agent-token.sh` with caller-supplied SSH targets and token paths.
- [x] T007 [FR-7, FR-8, FR-9, SC-3] Implement `scripts/validate-flux.sh` with caller-supplied Flux root and cluster overlay paths.
- [x] T008 [FR-3, FR-10, FR-12, SC-1, SC-4] Implement `scripts/validate-repository.sh` with syntax, output-name, and boundary checks.
- [x] T009 [FR-2, SC-2] Add `tests/module-fixture.nix` and wire flake checks to evaluate exported modules without host data.
- [x] T010 [FR-1, FR-11, FR-13, FR-14, FR-15, SC-5, SC-6] Update `README.md` with consumer boundary, usage, scripts, forbidden artifacts, and versioning model.
- [x] T011 [FR-1, SC-5] Add `.github/workflows/release.yml`, `release-please-config.json`, and `.release-please-manifest.json`.
- [x] T012 [FR-1, FR-8, FR-10, SC-1, SC-2, SC-3, SC-4] Update `.github/workflows/ci.yml` with real gating validation and required `Pipeline Complete`.
- [x] T013 [FR-1, FR-8, FR-10, SC-1, SC-2, SC-3, SC-4] Run local validation: prerequisite check, repository validation, and `nix flake check` when available.
- [x] T014 [FR-1, FR-2, FR-10, FR-15] Review spec, plan, tasks, README, and implementation for traceability and boundary consistency.
- [ ] T015 [FR-1] Commit, push `impl/initial`, open PR, poll `Pipeline Complete`, and squash-merge when green.
