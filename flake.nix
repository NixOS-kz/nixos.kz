{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
  inputs.impermanence.url = "github:nix-community/impermanence";
  inputs.impermanence.inputs.nixpkgs.follows = "";
  inputs.impermanence.inputs.home-manager.follows = "";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";

  outputs = inputs: import ./lib/mkFlake.nix inputs ./modules;
}
