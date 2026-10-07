{ inputs, config, ... }:
{
  flake.nixosConfigurations.nixos-kz = inputs.nixpkgs.lib.nixosSystem {
    modules = [ config.flake.modules.nixos.nixos-kz ];
  };

  flake.modules.nixos.nixos-kz = {
    imports = with config.flake.modules.nixos; [
      inputs.disko.nixosModules.disko
      ./_disko.nix
      ./_hardware.nix
      ./_network.nix
      server
      members
    ];
    virtualisation.vmVariant.imports = [ config.flake.modules.nixos.vm ];
  };
}
