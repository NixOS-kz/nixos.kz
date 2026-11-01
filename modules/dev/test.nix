{ inputs, config, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
  hashPaths = import ./_hash-paths.nix;
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
in
{
  flake.checks.x86_64-linux.vm = pkgs.testers.runNixOSTest {
    name = "nixos-kz";
    globalTimeout = 600;

    nodes.server = {
      imports = [ config.flake.modules.nixos.server ];
      virtualisation.diskImage = null;
      virtualisation.emptyDiskImages = [{ size = 256; driveConfig.deviceExtraOpts.serial = "persist"; }];
      virtualisation.fileSystems."/nix/persist" = {
        device = "/dev/disk/by-id/virtio-persist";
        fsType = "ext4";
        autoFormat = true;
        neededForBoot = true;
      };
      networking.hosts."127.0.0.2" = [ "cache.nixos.org" ];
      # ACME needed for the cache.nixos.org stub below
      security.acme = {
        acceptTerms = true;
        defaults.email = "test@nixos.kz";
      };
      services.nginx.virtualHosts."cache.nixos.org" = {
        listen = [{ addr = "127.0.0.2"; port = 443; ssl = true; }];
        addSSL = true;
        enableACME = true;
        locations."/".return = "200 'StoreDir: /nix/store\\n'";
      };
      environment.etc.key = { source = keys.snakeOilPrivateKey; mode = "0600"; };
      programs.ssh.extraConfig = ''
        IdentityFile /etc/key
        StrictHostKeyChecking no
        UserKnownHostsFile /dev/null
        StdinNull yes
      '';
      nixos-kz.members.tester = keys.snakeOilPublicKey;
      boot.kernel.sysctl."vm.panic_on_oom" = 0;
      users.users.root.openssh.authorizedKeys.keys = [ "restrict ${keys.snakeOilPublicKey}" ];
    };

    testScript = ''
      server.wait_for_unit("nginx.service")
      server.wait_for_unit("sshd.service")

      ip = "127.0.0.1"
      curl = f"curl -s --resolve nixos.kz:80:{ip} --resolve cache.nixos.kz:80:{ip} "

      with subtest("nginx"):
          server.succeed(curl + "http://nixos.kz | grep -F https://t.me/NixOSkz")
          server.succeed(curl + "http://cache.nixos.kz/nix-cache-info | grep StoreDir")
          server.succeed(curl + "http://cache.nixos.kz/00000000000000000000000000000000.narinfo | grep StoreDir")
          server.succeed(curl + "http://cache.nixos.kz/ | grep -F 'substituters = https://cache.nixos.kz'")
          server.succeed(curl + "-o /dev/null -w '%{http_code}' http://cache.nixos.kz/evil | grep -x 404")
          server.succeed(curl + "-X POST -o /dev/null -w '%{http_code}' http://cache.nixos.kz/nix-cache-info | grep -x 403")
          server.fail(f"curl -s -H 'Host: evil.com' http://{ip}/")

      with subtest("root has restricted deploy access"):
          server.succeed("ssh root@localhost 'touch /root/ok'")
          server.succeed("ssh root@localhost 'echo > /dev/tcp/127.0.0.1/22'")
          server.fail("ssh -tt root@localhost true")
          server.fail("timeout 10 ssh -o ExitOnForwardFailure=yes -N -L 2222:localhost:22 root@localhost")

      with subtest("sshd is hardened"):
          server.succeed("sshd -T | grep -ix 'logingracetime 30'")
          server.succeed("sshd -T | grep -ix 'maxstartups 10:30:60'")
          server.succeed("sshd -T | grep -i 'persourcepenalties crash:90'")
          server.fail("ssh -c aes128-ctr tester@localhost true")
          server.fail("ssh -o KexAlgorithms=diffie-hellman-group14-sha256 tester@localhost true")

      with subtest("members are sandboxed"):
          ssh = "ssh tester@localhost "
          server.succeed(ssh + "'uptime && echo > /dev/null'")
          server.succeed(ssh + "'fastfetch --pipe false > /dev/null'")
          server.succeed(ssh + "pwd | grep -x /var/empty")
          for p in ["/tmp/x", "/var/tmp/x", "/dev/shm/x", "/dev/x", "/run/user/1000/x", "/var/empty/x", "/x", "/sys/class/net/x"]:
              server.fail(ssh + f"'echo > {p}'")
          server.fail(ssh + "'unshare -rm true'")
          server.fail(ssh + "'systemd-run --user touch /tmp/escaped'")
          server.fail(ssh + "'nix-store --add /etc/hostname'")
          server.fail("scp /etc/key tester@localhost:/tmp/")
          server.fail("timeout 10 ssh -o ExitOnForwardFailure=yes -N -L 2222:localhost:22 tester@localhost")
          server.fail(ssh + "'echo > /dev/tcp/127.0.0.1/22'")
          server.succeed(ssh + "'ls /sys/class/net | wc -l | grep -x 0'")
          server.succeed(ssh + "'test ! -s /var/log/wtmp'")
          server.succeed(ssh + "'test ! -s /run/utmp'")
          server.succeed("test -s /var/log/wtmp")
          server.succeed("test -s /run/utmp")

      with subtest("members cannot starve root"):
          server.succeed(ssh + "'set -o pipefail; head -c 10M /dev/zero | tail | wc -c'")
          server.fail(ssh + "'set -o pipefail; head -c 300M /dev/zero | tail | wc -c'")
          server.execute("(" + ssh + "'for i in $(seq 100); do sleep 120 & done; wait') >/dev/null 2>&1 &")
          server.wait_until_succeeds("test $(systemctl show user-1000.slice -p TasksCurrent --value) -ge 60")
          server.succeed("test $(systemctl show user-1000.slice -p TasksCurrent --value) -le 64")
          server.succeed("ssh root@localhost true")
          server.succeed("systemctl stop user-1000.slice")

      with subtest("only persisted state survives a reboot"):
          server.succeed("touch /root/junk")
          machine_id = server.succeed("cat /etc/machine-id")
          server.shutdown()
          server.start()
          server.wait_for_unit("multi-user.target")
          server.fail("test -e /root/junk")
          assert server.succeed("cat /etc/machine-id") == machine_id
          server.succeed("test $(journalctl --list-boots | wc -l) -ge 2")

      with subtest("members detect a tampered store"):
          import json
          closure = json.loads(server.succeed("nix --extra-experimental-features nix-command path-info -r --json --json-format 1 /run/current-system"))
          expected = sorted(f"{p} {i['narHash']}" for p, i in closure.items())
          hashed = lambda: sorted(server.succeed("printf '%s\n' " + " ".join(closure) + " | ssh -o StdinNull=no tester@localhost " + ${builtins.toJSON (pkgs.lib.escapeShellArg hashPaths)}).splitlines())
          assert hashed() == expected
          victim = next(p for p in closure if p.endswith("-nixos-revision") or "etc-nixos-revision" in p)
          server.succeed(f"mount -o remount,bind,rw /nix/store; chmod -R u+w {victim}; echo pwned >> $(find {victim} -type f | head -1)")
          assert hashed() != expected

      with subtest("revision is recorded"):
          server.succeed("grep -E '^commit: [0-9a-f]{40}' /etc/nixos-revision")

      with subtest("daily reboot is scheduled"):
          server.succeed("systemctl list-timers reboot.timer | grep reboot.timer")
    '';
  };
}
