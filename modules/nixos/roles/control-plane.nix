{ config, lib, ... }:
let
  cfg = config.platformBlueprints.roles.controlPlane;
  oidc = cfg.oidc;
  oidcEnabled = oidc.issuerUrl != null || oidc.clientId != null;
  oidcIssuerUrl = if oidc.issuerUrl == null then "" else oidc.issuerUrl;
  oidcClientId = if oidc.clientId == null then "" else oidc.clientId;
  oidcFlags =
    [
      "--kube-apiserver-arg=oidc-issuer-url=${oidcIssuerUrl}"
      "--kube-apiserver-arg=oidc-client-id=${oidcClientId}"
      "--kube-apiserver-arg=oidc-username-claim=${oidc.usernameClaim}"
      "--kube-apiserver-arg=oidc-username-prefix=${oidc.usernamePrefix}"
    ]
    ++ lib.optionals (oidc.groupsClaim != null) [
      "--kube-apiserver-arg=oidc-groups-claim=${oidc.groupsClaim}"
      "--kube-apiserver-arg=oidc-groups-prefix=${oidc.groupsPrefix}"
    ];
in
{
  imports = [ ../k3s.nix ];

  options.platformBlueprints.roles.controlPlane = {
    enable = lib.mkEnableOption "generic k3s control-plane role";

    disableTraefik = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable bundled Traefik on k3s server nodes.";
    };

    disableServiceLb = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Disable bundled ServiceLB on k3s server nodes.";
    };

    writeKubeconfigMode = lib.mkOption {
      type = lib.types.str;
      default = "0644";
      description = "Mode passed to k3s --write-kubeconfig-mode.";
    };

    oidc = {
      issuerUrl = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional OIDC issuer URL for the Kubernetes API server.";
      };

      clientId = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional OIDC client id for the Kubernetes API server.";
      };

      usernameClaim = lib.mkOption {
        type = lib.types.str;
        default = "preferred_username";
        description = "OIDC username claim.";
      };

      usernamePrefix = lib.mkOption {
        type = lib.types.str;
        default = "oidc:";
        description = "OIDC username prefix.";
      };

      groupsClaim = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional OIDC groups claim.";
      };

      groupsPrefix = lib.mkOption {
        type = lib.types.str;
        default = "oidc:";
        description = "OIDC groups prefix.";
      };
    };

    extraFlags = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional k3s server flags for this role.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = lib.optionals oidcEnabled [
      {
        assertion = oidc.issuerUrl != null && oidc.issuerUrl != "";
        message = "control-plane OIDC requires platformBlueprints.roles.controlPlane.oidc.issuerUrl";
      }
      {
        assertion = oidc.clientId != null && oidc.clientId != "";
        message = "control-plane OIDC requires platformBlueprints.roles.controlPlane.oidc.clientId";
      }
    ];

    platformBlueprints.k3s = {
      enable = true;
      role = lib.mkDefault "server";
      serverExtraFlags =
        lib.optionals cfg.disableTraefik [ "--disable=traefik" ]
        ++ lib.optionals cfg.disableServiceLb [ "--disable=servicelb" ]
        ++ [ "--write-kubeconfig-mode=${cfg.writeKubeconfigMode}" ]
        ++ lib.optionals oidcEnabled oidcFlags
        ++ cfg.extraFlags;
    };
  };
}
