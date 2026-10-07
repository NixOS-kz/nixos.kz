{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.impermanence.url = "github:nix-community/impermanence";
  inputs.impermanence.inputs.nixpkgs.follows = "";
  inputs.impermanence.inputs.home-manager.follows = "";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, impermanence, disko, ... }:
    let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
      hashPaths = ''while read -r p; do echo "$p $(nix --extra-experimental-features nix-command hash path "$p")"; done'';
      modules = [
        impermanence.nixosModules.impermanence
        ./host/configuration.nix
        {
          environment.etc."nixos-revision".text = ''
            commit: ${self.rev or self.dirtyRev or "unknown"}
            status: ${if self ? rev then "clean" else "dirty"}
            store: ${self.outPath}
          '';
        }
      ];
    in
    {
      nixosConfigurations.nixos-kz = nixpkgs.lib.nixosSystem {
        modules = modules ++ [
          disko.nixosModules.disko
          ./host/disko.nix
          ./host/hardware-configuration.nix
          ./host/network.nix
          ./members.nix
          { virtualisation.vmVariant.imports = [ ./dev/vm.nix ]; }
        ];
      };

      apps.x86_64-linux = import ./dev/apps.nix {
        inherit pkgs hashPaths;
        vm = self.nixosConfigurations.nixos-kz.config.system.build.vm;
      };

      packages.x86_64-linux.site = pkgs.callPackage ./site { };

      checks.x86_64-linux.vm = pkgs.testers.runNixOSTest (import ./dev/test.nix { inherit pkgs modules hashPaths; });

      formatter.x86_64-linux = pkgs.nixpkgs-fmt;
    };
}
