{ config, lib, ... }:
let
  cfg = config.platformBlueprints.roles.worker;
in
{
  imports = [ ../k3s.nix ];

  options.platformBlueprints.roles.worker = {
    enable = lib.mkEnableOption "generic k3s worker role";
  };

  config = lib.mkIf cfg.enable {
    platformBlueprints.k3s = {
      enable = true;
      role = lib.mkDefault "agent";
    };
  };
}
