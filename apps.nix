{ pkgs, vm, hashPaths }:
let
  app = name: runtimeInputs: text: {
    type = "app";
    program = "${pkgs.writeShellApplication { inherit name runtimeInputs text; }}/bin/${name}";
  };

  netns = pkgs.writeShellApplication {
    name = "netns";
    runtimeInputs = [ pkgs.iproute2 pkgs.nftables pkgs.util-linux ];
    text = ''
      mount --bind "$HOSTS" /etc/hosts
      mount --bind "$RESOLV" /etc/resolv.conf
      mount -t tmpfs none /run/nscd # nscd lives outside and would answer from the host's hosts
      ip tuntap add tap0 mode tap user "$(id -u)"
      ip addr add 47.47.47.1/24 dev tap0
      ip link set tap0 up
      echo 1 > /proc/sys/net/ipv4/ip_forward
      nft 'add table ip nat; add chain ip nat post { type nat hook postrouting priority 100; }; add rule ip nat post iifname tap0 masquerade'
      exec ${vm}/bin/run-nixos-kz-vm
    '';
  };

  # root-owned files look unowned in the namespace, so skip the system ssh_config
  ssh = pkgs.writeShellScriptBin "ssh" ''exec ${pkgs.openssh}/bin/ssh -F "''${SSH_CONFIG:-/dev/null}" "$@"'';
in
{
  vm = app "vm" [ pkgs.passt pkgs.util-linux ] ''
    run="''${XDG_RUNTIME_DIR:-/tmp}/nixos-kz-vm"
    export AUTHORIZED_KEYS="$run.keys" HOSTS="$run.hosts" RESOLV="$run.resolv"
    echo $$ > "$run.pid"
    cat ~/.ssh/id_*.pub > "$AUTHORIZED_KEYS"
    { cat /etc/hosts; echo "47.47.47.47 nixos.kz www.nixos.kz cache.nixos.kz"; } > "$HOSTS"
    echo "nameserver 169.254.1.1" > "$RESOLV"
    (
      while [ "$(readlink /proc/$$/ns/net)" = "$(readlink /proc/self/ns/net)" ]; do sleep 0.1; done
      pasta --config-net --quiet --dns-forward 169.254.1.1 -t none -u none -T none -U none $$
    ) &
    exec unshare --map-current-user --net --mount --keep-caps -- ${netns}/bin/netns
  '';

  verify = app "verify" [ pkgs.nix pkgs.jq pkgs.openssh ] ''
    remote=$1 expected=$(mktemp)
    trap 'rm -f "$expected"' EXIT
    nix() { command nix --extra-experimental-features "nix-command flakes" "$@"; }
    commit=$(ssh "$remote" cat /etc/nixos-revision | sed -n 's/^commit: //p')
    main=$(nix flake metadata --refresh --json github:NixOS-kz/nixos.kz | jq -r .revision)
    [ "$commit" = "$main" ] || { echo "server runs $commit, main is $main"; exit 1; }
    system=$(ssh "$remote" readlink /run/current-system)
    built=$(nix build --no-link --print-out-paths "github:NixOS-kz/nixos.kz/$commit#nixosConfigurations.nixos-kz.config.system.build.toplevel")
    [ "$built" = "$system" ] || { echo "$system is not $commit"; exit 1; }
    nix path-info -r --json --json-format 1 "$built" | jq -r 'to_entries[] | "\(.key) \(.value.narHash)"' | sort > "$expected"
    cut -d" " -f1 "$expected" | ssh "$remote" ${pkgs.lib.escapeShellArg hashPaths} | sort | diff "$expected" - && echo "$system matches $commit"
  '';

  enter = app "enter" [ ssh pkgs.util-linux ] ''
    exec nsenter --target "$(cat "''${XDG_RUNTIME_DIR:-/tmp}/nixos-kz-vm.pid")" --user --net --mount --preserve-credentials -- "''${SHELL:-bash}"
  '';
}
