{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.base;
  deployUser = cfg.deployUser;
  resolverText =
    ''
      ${lib.concatMapStringsSep "\n" (server: "nameserver ${server}") cfg.resolver.nameservers}
    ''
    + lib.optionalString (cfg.resolver.options != [ ]) ''
      options ${lib.concatStringsSep " " cfg.resolver.options}
    '';
in
{
  options.platformBlueprints.base = {
    enable = lib.mkEnableOption "generic platform host baseline";

    enableSystemdBoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the systemd-boot EFI loader for hosts that use it.";
    };

    useDhcp = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable DHCP for hosts whose networking is not defined elsewhere.";
    };

    packages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = with pkgs; [
        curl
        git
        jq
        vim
      ];
      description = "Baseline packages installed on hosts using the base blueprint.";
    };

    firewall = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the NixOS firewall.";
      };

      allowedTCPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "Consumer-supplied baseline TCP firewall ports.";
      };

      allowedUDPPorts = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ ];
        description = "Consumer-supplied baseline UDP firewall ports.";
      };
    };

    ssh = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable OpenSSH for baseline hosts.";
      };

      ports = lib.mkOption {
        type = lib.types.listOf lib.types.port;
        default = [ 22 ];
        description = "Consumer-supplied OpenSSH ports.";
      };

      allowUsers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Optional OpenSSH AllowUsers list.";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = { };
        description = "Additional OpenSSH settings supplied by the consumer.";
      };
    };

    deployUser = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Create a deploy user when the consumer supplies key material.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        default = "deploy";
        description = "Deploy user name.";
      };

      uid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Optional deploy user uid.";
      };

      gid = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Optional deploy group gid.";
      };

      extraGroups = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ "wheel" ];
        description = "Extra groups for the deploy user.";
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Consumer-supplied SSH public keys for the deploy user.";
      };

      passwordlessSudo = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Allow wheel users to use sudo without a password.";
      };
    };

    resolver = {
      nameservers = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Static resolver nameservers. Empty leaves resolver ownership to the consumer.";
      };

      options = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Static resolver options written when nameservers are supplied.";
      };
    };

    timeZone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Consumer-supplied time zone. Null leaves it unset.";
    };

    defaultLocale = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Consumer-supplied default locale. Null leaves it unset.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      networking.useDHCP = lib.mkDefault cfg.useDhcp;
      networking.firewall.enable = cfg.firewall.enable;
      networking.firewall.allowedTCPPorts = cfg.firewall.allowedTCPPorts;
      networking.firewall.allowedUDPPorts = cfg.firewall.allowedUDPPorts;

      services.openssh = {
        enable = cfg.ssh.enable;
        ports = cfg.ssh.ports;
        settings =
          {
            KbdInteractiveAuthentication = lib.mkDefault false;
            PasswordAuthentication = lib.mkDefault false;
            PermitRootLogin = lib.mkDefault "no";
            PubkeyAuthentication = lib.mkDefault true;
            X11Forwarding = lib.mkDefault false;
          }
          // lib.optionalAttrs (cfg.ssh.allowUsers != [ ]) {
            AllowUsers = cfg.ssh.allowUsers;
          }
          // cfg.ssh.settings;
      };

      environment.systemPackages = cfg.packages;

      warnings = lib.optional (deployUser.enable && deployUser.authorizedKeys == [ ]) ''
        platformBlueprints.base.deployUser.enable is true, but no deploy SSH public keys were supplied.
      '';
    }

    (lib.mkIf cfg.enableSystemdBoot {
      boot.loader.systemd-boot.enable = true;
      boot.loader.efi.canTouchEfiVariables = true;
    })

    (lib.mkIf (cfg.resolver.nameservers != [ ]) {
      networking.resolvconf.enable = false;
      environment.etc."resolv.conf" = {
        mode = "0644";
        text = resolverText;
      };
    })

    (lib.mkIf deployUser.enable {
      users.groups.${deployUser.name} =
        { }
        // lib.optionalAttrs (deployUser.gid != null) {
          gid = deployUser.gid;
        };

      users.users.${deployUser.name} =
        {
          isNormalUser = true;
          group = deployUser.name;
          extraGroups = deployUser.extraGroups;
          openssh.authorizedKeys.keys = deployUser.authorizedKeys;
        }
        // lib.optionalAttrs (deployUser.uid != null) {
          uid = deployUser.uid;
        };

      security.sudo.wheelNeedsPassword = !deployUser.passwordlessSudo;
    })

    (lib.mkIf (cfg.timeZone != null) {
      time.timeZone = cfg.timeZone;
    })

    (lib.mkIf (cfg.defaultLocale != null) {
      i18n.defaultLocale = cfg.defaultLocale;
    })
  ]);
}
