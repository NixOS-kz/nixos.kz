# cache.nixos.kz

Proxy of cache.nixos.org. Same paths and signatures, no extra trust.

```nix
nix.settings.substituters = [
  "https://cache.nixos.kz"
  "https://cache.nixos.org"
];
```

Without NixOS, in `/etc/nix/nix.conf`:

```
substituters = https://cache.nixos.kz https://cache.nixos.org
```

[NixOS.kz](https://nixos.kz)
