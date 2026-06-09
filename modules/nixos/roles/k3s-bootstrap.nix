{ config, lib, ... }:
let
  cfg = config.platformBlueprints.roles.k3sBootstrap;
in
{
  imports = [ ../k3s.nix ];

  options.platformBlueprints.roles.k3sBootstrap = {
    enable = lib.mkEnableOption "generic k3s bootstrap host role";

    flannelInterface = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional interface passed to k3s as --flannel-iface.";
    };

    waitForInterface = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Wait for flannelInterface to receive an IPv4 address before k3s starts.";
    };

    tokenFile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Runtime path for an agent join token supplied by the consumer.";
    };

    serverEndpoint = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "k3s server endpoint for bootstrap worker nodes.";
    };

    nodeLabels = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Default bootstrap node labels.";
    };

    nodeTaints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Default bootstrap node taints.";
    };

    requiredServices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "network-online.target" ];
      description = "Systemd services that must be ready before k3s starts.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.optionals (cfg.tokenFile != null) [
      {
        assertion = cfg.serverEndpoint != null && cfg.serverEndpoint != "";
        message = "k3s bootstrap tokenFile requires platformBlueprints.roles.k3sBootstrap.serverEndpoint";
      }
    ];

    platformBlueprints.k3s = lib.mkMerge [
      {
        enable = true;
        requiredServices = cfg.requiredServices;
        nodeLabels = cfg.nodeLabels;
        nodeTaints = cfg.nodeTaints;
      }

      (lib.mkIf (cfg.serverEndpoint != null) {
        apiServerEndpoint = cfg.serverEndpoint;
      })

      (lib.mkIf (cfg.tokenFile != null) {
        joinTokenFile = cfg.tokenFile;
      })

      (lib.mkIf (cfg.flannelInterface != null) {
        flannelInterface = cfg.flannelInterface;
      })

      (lib.mkIf (cfg.waitForInterface && cfg.flannelInterface != null) {
        waitForInterface.name = cfg.flannelInterface;
      })
    ];
  };
}
