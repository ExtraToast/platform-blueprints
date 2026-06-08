{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.gpuNvidia;
in
{
  options.platformBlueprints.roles.gpuNvidia = {
    enable = lib.mkEnableOption "generic NVIDIA GPU host role";

    driverPackage = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "Optional NVIDIA driver package override.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics.enable = true;
      hardware.nvidia = {
        open = false;
        modesetting.enable = true;
        package = lib.mkDefault (
          if cfg.driverPackage != null then
            cfg.driverPackage
          else
            config.boot.kernelPackages.nvidiaPackages.stable
        );
      };
      hardware.nvidia-container-toolkit.enable = true;

      systemd.services.nvidia-container-toolkit-cdi-generator.unitConfig.ConditionPathExists =
        "/proc/driver/nvidia/version";

      environment.systemPackages = with pkgs; [
        libva
        pciutils
      ];
    }

    (lib.mkIf config.services.k3s.enable {
      systemd.services.k3s.path = [
        pkgs.nvidia-container-toolkit.tools
        pkgs.runc
      ];
    })
  ]);
}
