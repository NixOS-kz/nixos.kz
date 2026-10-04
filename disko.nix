{
  disko.devices.disk.main = {
    device = "/dev/vda";
    content = {
      type = "gpt";
      partitions = {
        bios = {
          size = "1M";
          type = "EF02";
        };
        boot = {
          size = "512M";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        swap = {
          size = "1G";
          content.type = "swap";
        };
        nix = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/nix";
          };
        };
      };
    };
  };
}
