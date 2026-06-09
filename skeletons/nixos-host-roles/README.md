# NixOS Host Roles and Fleet-to-Flake Pattern

Round 4 promotes the host-role surface into opt-in NixOS modules under
`modules/nixos/roles` and a fleet helper at `lib/nixos/fleet-to-flake.nix`.

Implemented role outputs include:

- `nixosModules.roleK3sBootstrap`
- `nixosModules.roleControlPlane`
- `nixosModules.roleWorker`
- `nixosModules.roleUtilityHost`
- `nixosModules.roleGpuAmd`
- `nixosModules.roleGpuNvidia`
- `nixosModules.roleNetworkTailscale`
- `nixosModules.roleRaspberryPiImage`

The fleet helper is intentionally a pattern, not an inventory renderer owned by
this repository. Consumers pass their own fleet data, host-specific modules,
disko layouts, deploy keys, SSH targets, secrets, and flake locks.
