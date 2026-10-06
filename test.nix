{ pkgs, modules, hashPaths }:
let
  keys = import "${pkgs.path}/nixos/tests/ssh-keys.nix" pkgs;
in
{
  name = "nixos-kz";
  globalTimeout = 900;

  nodes.server = { nodes, ... }: {
    imports = modules;
    virtualisation.diskImage = null;
    virtualisation.emptyDiskImages = [{ size = 256; driveConfig.deviceExtraOpts.serial = "persist"; }];
    virtualisation.fileSystems."/nix/persist" = {
      device = "/dev/disk/by-id/virtio-persist";
      fsType = "ext4";
      autoFormat = true;
      neededForBoot = true;
    };
    networking.hosts.${nodes.internet.networking.primaryIPAddress} = [ "cache.nixos.org" ];
    nixos-kz.members.tester = keys.snakeOilPublicKey;
    boot.kernel.sysctl."vm.panic_on_oom" = 0; # the test harness panics on OOM, production does not
    users.users.root.openssh.authorizedKeys.keys = [ "restrict ${keys.snakeOilPublicKey}" ];
  };

  nodes.internet = {
    security.acme = { acceptTerms = true; defaults.email = "test@example.org"; };
    services.nginx = {
      enable = true;
      virtualHosts.internet = {
        addSSL = true;
        enableACME = true;
        locations."/".return = "200 'StoreDir: /nix/store\\n'";
      };
    };
    networking.firewall.allowedTCPPorts = [ 443 ];
  };

  testScript = { nodes, ... }: ''
    start_all()
    server.wait_for_unit("nginx.service")
    server.wait_for_unit("sshd.service")
    internet.wait_for_unit("nginx.service")

    ip = "${nodes.server.networking.primaryIPAddress}"
    curl = f"curl -sk --resolve nixos.kz:443:{ip} --resolve cache.nixos.kz:443:{ip} "

    with subtest("nginx"):
        internet.succeed(curl + "-o /dev/null -w '%{redirect_url}' https://nixos.kz | grep -x https://t.me/NixOSkz")
        internet.succeed(curl + "https://cache.nixos.kz/nix-cache-info | grep StoreDir")
        internet.succeed(curl + "https://cache.nixos.kz/00000000000000000000000000000000.narinfo | grep StoreDir")
        internet.succeed(curl + "-o /dev/null -w '%{http_code}' https://cache.nixos.kz/ | grep -x 404")
        internet.succeed(curl + "-o /dev/null -w '%{http_code}' https://cache.nixos.kz/evil | grep -x 404")
        internet.succeed(curl + "-X POST -o /dev/null -w '%{http_code}' https://cache.nixos.kz/nix-cache-info | grep -x 403")
        internet.succeed(curl + "-I https://nixos.kz | grep -i '^strict-transport-security: max-age=31536000'")
        internet.fail(f"curl -s -H 'Host: evil.com' http://{ip}/")
        internet.succeed(f"curl -s -o /dev/null -w '%{{redirect_url}}' -H 'Host: nixos.kz' http://{ip}/ | grep -x https://nixos.kz/")

    internet.succeed("install -m600 ${keys.snakeOilPrivateKey} /root/key")

    with subtest("root has restricted deploy access"):
        internet.succeed("ssh -i /root/key -o StrictHostKeyChecking=no root@server 'touch /root/ok'")
        internet.succeed("ssh -i /root/key -o StrictHostKeyChecking=no root@server 'echo > /dev/tcp/127.0.0.1/22'")
        internet.fail("ssh -i /root/key -tt -o StrictHostKeyChecking=no root@server true")
        internet.fail("timeout 10 ssh -i /root/key -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -N -L 2222:localhost:22 root@server")

    with subtest("sshd is hardened"):
        server.succeed("sshd -T | grep -ix 'logingracetime 30'")
        server.succeed("sshd -T | grep -ix 'maxstartups 10:30:60'")
        server.succeed("sshd -T | grep -i 'persourcepenalties crash:90'")
        internet.fail("ssh -i /root/key -c aes128-ctr -o StrictHostKeyChecking=no tester@server true")
        internet.fail("ssh -i /root/key -o KexAlgorithms=diffie-hellman-group14-sha256 -o StrictHostKeyChecking=no tester@server true")

    with subtest("members are sandboxed"):
        ssh = "ssh -i /root/key -o StrictHostKeyChecking=no tester@server "
        internet.succeed(ssh + "'uptime && echo > /dev/null'")
        internet.succeed(ssh + "'fastfetch --pipe false > /dev/null'")
        internet.succeed(ssh + "pwd | grep -x /var/empty")
        for p in ["/tmp/x", "/var/tmp/x", "/dev/shm/x", "/dev/x", "/run/user/1000/x", "/var/empty/x", "/x", "/sys/class/net/x"]:
            internet.fail(ssh + f"'echo > {p}'")
        internet.fail(ssh + "'unshare -rm true'")
        internet.fail(ssh + "'systemd-run --user touch /tmp/escaped'")
        internet.fail(ssh + "'nix-store --add /etc/hostname'")
        internet.fail("scp -i /root/key -o StrictHostKeyChecking=no /root/key tester@server:/tmp/")
        internet.fail("timeout 10 ssh -i /root/key -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -N -L 2222:localhost:22 tester@server")
        internet.fail(ssh + "'echo > /dev/tcp/127.0.0.1/22'")
        internet.succeed(ssh + "'ls /sys/class/net | wc -l | grep -x 0'")
        internet.succeed(ssh + "'test ! -s /var/log/wtmp'")
        internet.succeed(ssh + "'test ! -s /run/utmp'")
        server.succeed("test -s /var/log/wtmp")
        server.succeed("test -s /run/utmp")

    with subtest("members cannot starve root"):
        internet.succeed(ssh + "'set -o pipefail; head -c 10M /dev/zero | tail | wc -c'")
        internet.fail(ssh + "'set -o pipefail; head -c 300M /dev/zero | tail | wc -c'")
        internet.execute("(" + ssh + "'for i in $(seq 100); do sleep 120 & done; wait') >/dev/null 2>&1 &")
        server.wait_until_succeeds("test $(systemctl show user-1000.slice -p TasksCurrent --value) -ge 60")
        server.succeed("test $(systemctl show user-1000.slice -p TasksCurrent --value) -le 64")
        internet.succeed("ssh -i /root/key -o StrictHostKeyChecking=no root@server true")
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
        hashed = lambda: sorted(internet.succeed("printf '%s\n' " + " ".join(closure) + " | " + ssh + ${builtins.toJSON (pkgs.lib.escapeShellArg hashPaths)}).splitlines())
        assert hashed() == expected
        victim = next(p for p in closure if p.endswith("-nixos-revision") or "etc-nixos-revision" in p)
        server.succeed(f"mount -o remount,bind,rw /nix/store; chmod -R u+w {victim}; echo pwned >> $(find {victim} -type f | head -1)")
        assert hashed() != expected

    with subtest("revision is recorded"):
        server.succeed("grep -E '^commit: [0-9a-f]{40}' /etc/nixos-revision")

    with subtest("daily reboot is scheduled"):
        server.succeed("systemctl list-timers reboot.timer | grep reboot.timer")
  '';
}
