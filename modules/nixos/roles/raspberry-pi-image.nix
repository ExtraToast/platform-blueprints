{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.raspberryPiImage;
in
{
  options.platformBlueprints.roles.raspberryPiImage = {
    enable = lib.mkEnableOption "generic Raspberry Pi image/profile assumptions";

    enableSerialConsole = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable a serial console suitable for headless board bring-up.";
    };

    kernelPackages = lib.mkOption {
      type = lib.types.nullOr lib.types.raw;
      default = null;
      description = "Optional kernel package set override supplied by the consumer.";
    };

    extraKernelParams = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional kernel parameters for board-specific images.";
    };

    extraFirmwarePackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      description = "Additional firmware packages for the target board.";
    };

    wirelessRegulatoryDatabase = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Install the wireless regulatory database for Wi-Fi capable boards.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      hardware.enableRedistributableFirmware = true;
      hardware.firmware = cfg.extraFirmwarePackages;
      boot.initrd.availableKernelModules = [
        "xhci_pci"
        "usbhid"
        "usb_storage"
      ];
      boot.kernelParams = cfg.extraKernelParams;
      environment.systemPackages =
        lib.optionals cfg.wirelessRegulatoryDatabase [ pkgs.wireless-regdb ];
    }

    (lib.mkIf (cfg.kernelPackages != null) {
      boot.kernelPackages = cfg.kernelPackages;
    })

    (lib.mkIf cfg.enableSerialConsole {
      boot.kernelParams = [ "console=ttyS0,115200n8" ];
    })
  ]);
}
