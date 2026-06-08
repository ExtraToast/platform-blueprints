{
  description = "Reusable NixOS, k3s, and Flux platform blueprints";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;
      mkPkgs = system: import nixpkgs { inherit system; };
      mkScriptPackage =
        pkgs: name: path:
        pkgs.stdenvNoCC.mkDerivation {
          pname = name;
          version = "0.0.0";
          dontUnpack = true;
          installPhase = ''
            mkdir -p "$out/bin"
            cp ${path} "$out/bin/${name}"
            chmod 755 "$out/bin/${name}"
          '';
        };
      moduleFixture =
        system:
        import ./tests/module-fixture.nix {
          inherit self nixpkgs system;
        };
    in
    {
      nixosModules = rec {
        base = import ./modules/nixos/base.nix;
        k3s = import ./modules/nixos/k3s.nix;
        roleControlPlane = import ./modules/nixos/roles/control-plane.nix;
        roleWorker = import ./modules/nixos/roles/worker.nix;
        roleGpuAmd = import ./modules/nixos/roles/gpu-amd.nix;
        roleGpuNvidia = import ./modules/nixos/roles/gpu-nvidia.nix;
        roleUtilityHost = import ./modules/nixos/roles/utility-host.nix;

        roles = {
          controlPlane = roleControlPlane;
          worker = roleWorker;
          gpuAmd = roleGpuAmd;
          gpuNvidia = roleGpuNvidia;
          utilityHost = roleUtilityHost;
        };

        default = {
          imports = [
            base
            k3s
          ];
        };
      };

      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        rec {
          bootstrap-k3s-agent-token = mkScriptPackage pkgs "bootstrap-k3s-agent-token" ./scripts/bootstrap-k3s-agent-token.sh;
          validate-flux = mkScriptPackage pkgs "validate-flux" ./scripts/validate-flux.sh;
          default = validate-flux;
        }
      );

      apps = forAllSystems (
        system:
        let
          packages = self.packages.${system};
        in
        {
          bootstrap-k3s-agent-token = {
            type = "app";
            program = "${packages.bootstrap-k3s-agent-token}/bin/bootstrap-k3s-agent-token";
          };
          validate-flux = {
            type = "app";
            program = "${packages.validate-flux}/bin/validate-flux";
          };
          default = self.apps.${system}.validate-flux;
        }
      );

      checks.x86_64-linux =
        let
          system = "x86_64-linux";
          pkgs = mkPkgs system;
          fixture = moduleFixture system;
          fixtureDrvPath = builtins.unsafeDiscardStringContext fixture.config.system.build.toplevel.drvPath;
        in
        {
          module-fixture = pkgs.runCommand "platform-blueprints-module-fixture" { } ''
            printf '%s\n' '${fixtureDrvPath}' > "$out"
          '';

          script-syntax = pkgs.runCommand "platform-blueprints-script-syntax" { } ''
            ${pkgs.bash}/bin/bash -n ${./scripts/bootstrap-k3s-agent-token.sh}
            ${pkgs.bash}/bin/bash -n ${./scripts/validate-flux.sh}
            ${pkgs.bash}/bin/bash -n ${./scripts/validate-repository.sh}
            touch "$out"
          '';
        };
    };
}
