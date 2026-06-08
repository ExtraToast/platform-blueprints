{ config, lib, ... }:
let
  cfg = config.platformBlueprints.roles.utilityHost;
in
{
  options.platformBlueprints.roles.utilityHost = {
    enable = lib.mkEnableOption "generic utility host firewall role";

    allowedTCPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        53
        80
        139
        443
        445
      ];
      description = "Utility host TCP ports.";
    };

    allowedUDPPorts = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        53
        137
        138
      ];
      description = "Utility host UDP ports.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = cfg.allowedTCPPorts;
    networking.firewall.allowedUDPPorts = cfg.allowedUDPPorts;
  };
}
