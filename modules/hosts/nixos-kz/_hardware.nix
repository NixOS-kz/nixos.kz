{ modulesPath, ... }:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  nixpkgs.hostPlatform = "x86_64-linux";

  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";
}
