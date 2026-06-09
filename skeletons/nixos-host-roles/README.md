# NixOS Host Roles and Fleet-to-Flake Skeleton

Design-first only. This directory sketches the next optional host role surface
without adding production modules or fleet renderers in this round.

The existing `modules/nixos` base, k3s, and role modules remain the current
implemented surface. Future role work should add opt-in modules for:

- Raspberry Pi image/profile support
- Tailscale and flannel interface assumptions
- utility host firewall profiles
- GPU runtime profiles
- fleet inventory to flake/deploy-rs node generation

Consumers must continue to own hostnames, SSH targets, deploy keys, disko
layouts, secrets, and flake locks.
