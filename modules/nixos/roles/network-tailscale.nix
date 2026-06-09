{ config, lib, ... }:
let
  cfg = config.platformBlueprints.roles.networkTailscale;
in
{
  options.platformBlueprints.roles.networkTailscale = {
    enable = lib.mkEnableOption "generic Tailscale-backed platform network role";

    authKeyFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional runtime path containing a Tailscale auth key.";
    };

    extraUpFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional flags passed to tailscale up.";
    };

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "tailscale0";
      description = "Tailnet interface name used by dependent roles.";
    };

    trustInterface = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Mark the tailnet interface as trusted in the firewall.";
    };

    useForK3sFlannel = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Set platformBlueprints.k3s.flannelInterface to the tailnet interface.";
    };

    waitForK3s = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Wait for the tailnet interface before k3s starts.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.tailscale = {
        enable = true;
        extraUpFlags = cfg.extraUpFlags;
      }
      // lib.optionalAttrs (cfg.authKeyFile != null) {
        authKeyFile = cfg.authKeyFile;
      };

      networking.firewall.checkReversePath = lib.mkDefault "loose";
    }

    (lib.mkIf cfg.trustInterface {
      networking.firewall.trustedInterfaces = [ cfg.interfaceName ];
    })

    (lib.mkIf cfg.useForK3sFlannel {
      platformBlueprints.k3s.flannelInterface = lib.mkDefault cfg.interfaceName;
    })

    (lib.mkIf cfg.waitForK3s {
      platformBlueprints.k3s.waitForInterface.name = lib.mkDefault cfg.interfaceName;
    })
  ]);
}
