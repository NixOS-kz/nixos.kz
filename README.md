# nixos.kz

NixOS config of nixos.kz and cache.nixos.kz, deployed by GitHub Actions on push to `main`.

Members log in as their GitHub handle: read-only sandbox, lowest CPU and IO priority, no root.

```sh
nix flake check   # VM test
nix run .#vm      # the server in a rootless netns, Ctrl-a x quits
nix run .#enter   # shell in that netns: ssh root@nixos.kz, curl -k https://nixos.kz
nix run .#verify -- you@nixos.kz   # the server runs main, closure untampered
```

The VM accepts your `~/.ssh/id_*.pub` for every user.

`verify` catches corruption and offline tampering, not a server whose root lies.
