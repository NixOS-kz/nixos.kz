# nixos.kz

NixOS config of nixos.kz and cache.nixos.kz, deployed by GitHub Actions on push to `main`.

The server runs as a KVM VM (`10.7.7.2`) on the NixOS-kz bare metal host. TLS and HSTS are handled by nginx on the host; the VM serves plain HTTP on port 80. SSH is reachable via port 2026 on the host.

Members log in as their GitHub handle: read-only sandbox, lowest CPU and IO priority, no root.

```sh
nix flake check   # VM test
nix build .#site  # pages from modules/site/*.md
nix run .#vm      # the server in a rootless netns, Ctrl-a x quits
nix run .#enter   # shell in that netns: ssh root@nixos.kz, curl -k https://nixos.kz
nix run .#verify -- you@nixos.kz   # the server runs main, closure untampered
```

The VM accepts your `~/.ssh/id_*.pub` for every user.

`verify` catches corruption and offline tampering, not a server whose root lies.
