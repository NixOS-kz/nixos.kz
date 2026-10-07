{
  flake.modules.nixos.access =
    { config, lib, pkgs, ... }:
    let
      sandbox = pkgs.writeShellScript "sandbox" ''
        [ -n "$SSH_ORIGINAL_COMMAND" ] && set -- -c "$SSH_ORIGINAL_COMMAND"
        exec ${pkgs.bubblewrap}/bin/bwrap --ro-bind / / --ro-bind /var/empty /run/user --ro-bind /var/empty /sys/class/net \
          --ro-bind /dev/null /var/log/wtmp --ro-bind /dev/null /run/utmp \
          --dev /dev --remount-ro /dev --proc /proc \
          --unshare-user --disable-userns --unshare-ipc --unshare-net --unshare-uts --unshare-cgroup \
          --die-with-parent --chdir "$HOME" \
          -- ${pkgs.bashInteractive}/bin/bash -l "$@"
      '';
    in
    {
      options.nixos-kz.members = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "GitHub handle to SSH public key.";
      };

      config = {
        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            KbdInteractiveAuthentication = false;
            DisableForwarding = true;
            LoginGraceTime = 30;
            MaxStartups = "10:30:60";
            PerSourcePenalties = "crash:90s authfail:5s invaliduser:10s min:15s max:10m";
            KexAlgorithms = [
              "mlkem768x25519-sha256"
              "sntrup761x25519-sha512@openssh.com"
              "curve25519-sha256"
              "curve25519-sha256@libssh.org"
            ];
            Ciphers = [
              "chacha20-poly1305@openssh.com"
              "aes256-gcm@openssh.com"
              "aes128-gcm@openssh.com"
            ];
            Macs = [
              "umac-128-etm@openssh.com"
              "hmac-sha2-512-etm@openssh.com"
              "hmac-sha2-256-etm@openssh.com"
            ];
          };
          hostKeys = [{ type = "ed25519"; path = "/nix/persist/ssh_host_ed25519_key"; }];
          extraConfig = ''
            Match Group users
              ForceCommand ${sandbox}
          '';
        };

        nix.settings.allowed-users = [ "root" ];

        users.mutableUsers = false;
        users.users = lib.mapAttrs
          (_: key: {
            isNormalUser = true;
            home = "/var/empty";
            createHome = false;
            openssh.authorizedKeys.keys = [ key ];
          })
          config.nixos-kz.members // {
          root.openssh.authorizedKeys.keys = [ "restrict ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILDoFqcU/RXQMh7NOKLOTDtFb/RS20U733X1H+uCU47x github-actions@NixOS-kz/nixos.kz" ];
        };

        systemd.slices.user.sliceConfig = {
          CPUWeight = 1;
          IOWeight = 1;
        };
        systemd.slices."user-" = {
          overrideStrategy = "asDropin";
          sliceConfig = {
            MemoryMax = "10%";
            MemorySwapMax = 0;
            TasksMax = 64;
          };
        };
        # root is the CI deploy: members must never starve it
        systemd.slices."user-0" = {
          overrideStrategy = "asDropin";
          sliceConfig = {
            MemoryMax = "infinity";
            TasksMax = "infinity";
          };
        };
      };
    };
}
