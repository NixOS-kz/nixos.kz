{ lib, ... }:
{
  imports = [
    ./website.nix
    ./cache.nix
  ];

  security.acme = {
    acceptTerms = true;
    defaults.email = lib.mkDefault "webmaster@nixos.kz";
  };
}
