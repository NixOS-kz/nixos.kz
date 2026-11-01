{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  systemd.network.links."10-wan" = {
    matchConfig.MACAddress = "52:54:00:6e:6b:7a";
    linkConfig.Name = "ens3";
  };
}
