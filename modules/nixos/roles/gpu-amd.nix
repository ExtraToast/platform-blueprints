{ config, lib, pkgs, ... }:
let
  cfg = config.platformBlueprints.roles.gpuAmd;
  rocmSmiWrapped = pkgs.symlinkJoin {
    name = "rocm-smi-wrapped";
    paths = [ pkgs.rocmPackages.rocm-smi ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/rocm-smi \
        --prefix LD_LIBRARY_PATH : ${pkgs.libdrm}/lib
    '';
  };
in
{
  options.platformBlueprints.roles.gpuAmd = {
    enable = lib.mkEnableOption "generic AMD GPU host role";

    enable32BitGraphics = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable 32-bit graphics packages for workloads that need them.";
    };

    rocmStateDir = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional ROCm state directory created by tmpfiles.";
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      boot.initrd.kernelModules = [ "amdgpu" ];
      boot.kernelModules = [
        "amdgpu"
        "kvm-amd"
      ];

      hardware.enableRedistributableFirmware = true;
      hardware.firmware = [ pkgs.linux-firmware ];

      hardware.graphics = {
        enable = true;
        enable32Bit = cfg.enable32BitGraphics;
        extraPackages = with pkgs; [
          libva
          libvdpau-va-gl
          mesa
          rocmPackages.clr.icd
        ];
        extraPackages32 = with pkgs.pkgsi686Linux; [
          mesa
        ];
      };

      environment.systemPackages = with pkgs; [
        clinfo
        libdrm
        libva-utils
        pciutils
        radeontop
        rocmSmiWrapped
        rocmPackages.rocminfo
        vulkan-tools
      ];

      services.udev.extraRules = ''
        KERNEL=="kfd", GROUP="render", MODE="0660"
      '';
    }

    (lib.mkIf (cfg.rocmStateDir != null) {
      systemd.tmpfiles.rules = [
        "d ${cfg.rocmStateDir} 0755 root render - -"
      ];
    })
  ]);
}
