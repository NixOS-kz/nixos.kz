{
  flake.modules.nixos.vm =
    { lib, pkgs, ... }:
    let
      keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
    in
    {
      virtualisation = {
        diskImage = null;
        graphics = false;
        memorySize = 1024;
        qemu.networkingOptions = lib.mkForce [
          "-netdev tap,id=wan,ifname=tap0,script=no,downscript=no"
          "-device virtio-net-pci,netdev=wan,mac=52:54:00:47:47:47"
        ];
        qemu.options = [ "-fw_cfg name=opt/authorized_keys,file=$AUTHORIZED_KEYS" ];
      };

      systemd.network.links."10-wan" = {
        matchConfig.MACAddress = "52:54:00:47:47:47";
        linkConfig.Name = "ens3";
      };

      networking.interfaces.ens3.ipv4.addresses = lib.mkForce [{ address = "47.47.47.47"; prefixLength = 24; }];
      networking.defaultGateway = lib.mkForce "47.47.47.1";

      security.acme.defaults.server = "https://127.0.0.1/";

      boot.kernelModules = [ "qemu_fw_cfg" ];
      services.openssh.authorizedKeysFiles = [ "/run/authorized_keys" ];
      systemd.services.vm-ssh = {
        wantedBy = [ "sshd.service" ];
        before = [ "sshd.service" "sshd-keygen.service" ];
        serviceConfig.Type = "oneshot";
        script = ''
          install -m 644 /sys/firmware/qemu_fw_cfg/by_name/opt/authorized_keys/raw /run/authorized_keys
          install -m 600 ${keys.snakeOilEd25519PrivateKey} /nix/persist/ssh_host_ed25519_key
          ${pkgs.openssh}/bin/ssh-keygen -y -f /nix/persist/ssh_host_ed25519_key > /nix/persist/ssh_host_ed25519_key.pub
        '';
      };
    };
}
