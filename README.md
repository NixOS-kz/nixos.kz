# nixos.kz

NixOS module behind [nixos.kz](https://nixos.kz) and the
[cache.nixos.kz](https://cache.nixos.kz) binary cache mirror.

| Option | What it does |
| --- | --- |
| `nixos-kz.website.enable` | `nixos.kz` and `www.nixos.kz` vhost (redirects to the Telegram chat for now) |
| `nixos-kz.cache.enable` | `cache.nixos.kz`: passthrough proxy to cache.nixos.org |

Both use nginx with ACME certificates.

## Usage

```nix
{
  inputs.nixos-kz.url = "github:NixOS-kz/nixos.kz";

  outputs = { nixpkgs, nixos-kz, ... }: {
    nixosConfigurations.server = nixpkgs.lib.nixosSystem {
      modules = [
        nixos-kz.nixosModules.default
        {
          nixos-kz.website.enable = true;
          nixos-kz.cache.enable = true;
        }
      ];
    };
  };
}
```

## Deployment

The server is reached only by DNS name, as `root@nixos.kz`, never by IP.
For now it is deployed with deploy-rs from a maintainer's host flake that
imports this module.

## Development

```sh
nix flake check   # evaluates a test system with every option enabled
nix fmt           # nixpkgs-fmt
```

## License

[MIT](LICENSE)
