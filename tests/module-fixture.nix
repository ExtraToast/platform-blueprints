{ self, nixpkgs, system }:
let
  lib = nixpkgs.lib;
in
lib.nixosSystem {
  inherit system;
  modules = [
    self.nixosModules.base
    self.nixosModules.k3s
    self.nixosModules.roleK3sBootstrap
    self.nixosModules.roleControlPlane
    self.nixosModules.roleWorker
    self.nixosModules.roleGpuAmd
    self.nixosModules.roleGpuNvidia
    self.nixosModules.roleUtilityHost
    self.nixosModules.roleNetworkTailscale
    self.nixosModules.roleRaspberryPiImage
    (
      { pkgs, ... }:
      {
        boot.loader.grub.enable = false;
        fileSystems."/".device = "fixture-root";
        system.stateVersion = "25.05";

        platformBlueprints.base = {
          enable = true;
          ssh.ports = [ 22 ];
          deployUser = {
            enable = true;
            name = "deploy";
            authorizedKeys = [
              "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFixtureKeyMaterialOnly000000000000000000000"
            ];
            passwordlessSudo = true;
          };
          resolver = {
            nameservers = [ "RESOLVER_ADDRESS" ];
            options = [
              "timeout:1"
              "attempts:2"
            ];
          };
          timeZone = "UTC";
          defaultLocale = "en_US.UTF-8";
        };

        platformBlueprints.roles.controlPlane = {
          enable = true;
          oidc = {
            issuerUrl = "OIDC_ISSUER_URL";
            clientId = "dashboard";
            groupsClaim = "groups";
          };
        };

        platformBlueprints.k3s = {
          flannelInterface = "mesh0";
          waitForInterface.name = "mesh0";
          requiredServices = [ "network-online.target" ];
          nodeLabels.role = "fixture";
          nodeTaints = [ "fixture=true:NoSchedule" ];
        };

        platformBlueprints.roles.utilityHost.enable = true;

        platformBlueprints.roles.k3sBootstrap = {
          enable = true;
          flannelInterface = "mesh0";
          waitForInterface = true;
          nodeLabels.bootstrap = "fixture";
        };

        environment.systemPackages = [ pkgs.hello ];
      }
    )
  ];
}
