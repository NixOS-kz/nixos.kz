{
  description = "NixOS module for nixos.kz and cache.nixos.kz";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in
    {
      # Import into the host that serves nixos.kz and set
      # `nixos-kz.website.enable` / `nixos-kz.cache.enable`.
      nixosModules.default = ./modules;

      checks = forAllSystems (pkgs: {
        # Evaluate a minimal system with everything enabled.
        eval = (nixpkgs.lib.nixosSystem {
          modules = [
            self.nixosModules.default
            {
              nixpkgs.hostPlatform = pkgs.stdenv.hostPlatform.system;
              nixos-kz.website.enable = true;
              nixos-kz.cache.enable = true;
              boot.loader.grub.enable = false;
              fileSystems."/" = { device = "none"; fsType = "tmpfs"; };
              system.stateVersion = "25.11";
            }
          ];
        }).config.system.build.etc;
      });

      formatter = forAllSystems (pkgs: pkgs.nixpkgs-fmt);
    };
}
