{ lib }:
let
  roleModuleNames = {
    base = "base";
    k3s-bootstrap = "roleK3sBootstrap";
    k3s-control-plane = "roleControlPlane";
    k3s-worker = "roleWorker";
    utility = "roleUtilityHost";
    utility-host = "roleUtilityHost";
    gpu-amd = "roleGpuAmd";
    gpu-nvidia = "roleGpuNvidia";
    raspberry-pi-image = "roleRaspberryPiImage";
    tailscale-network = "roleNetworkTailscale";
  };

  moduleNameForRole =
    role:
    roleModuleNames.${role} or (throw "Unknown platform-blueprints fleet role: ${role}");
in
rec {
  inherit moduleNameForRole roleModuleNames;

  modulesForNode =
    platformModules: node:
    map (role: platformModules.${moduleNameForRole role}) (node.roles or [ ]);

  mkHostModule =
    platformModules: node:
    {
      imports = modulesForNode platformModules node;
      networking.hostName = lib.mkDefault node.id;
      nixpkgs.hostPlatform = lib.mkDefault node.system;
    };

  mkNixosConfigurations =
    {
      nixpkgs,
      platformModules,
      fleet,
      extraModules ? [ ],
      specialArgs ? { },
    }:
    lib.genAttrs (map (node: node.id) fleet.nodes) (
      nodeId:
      let
        node = lib.findFirst (candidate: candidate.id == nodeId) null fleet.nodes;
      in
      nixpkgs.lib.nixosSystem {
        system = node.system;
        inherit specialArgs;
        modules = [
          (mkHostModule platformModules node)
        ] ++ extraModules;
      }
    );

  deployNodeMetadata =
    fleet:
    lib.genAttrs (map (node: node.id) fleet.nodes) (
      nodeId:
      let
        node = lib.findFirst (candidate: candidate.id == nodeId) null fleet.nodes;
      in
      {
        hostname = node.sshHost or node.id;
        user = node.sshUser or null;
        profiles = node.roles or [ ];
      }
    );
}
