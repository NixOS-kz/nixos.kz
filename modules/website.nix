{ config, lib, ... }:
let
  cfg = config.nixos-kz.website;
in
{
  options.nixos-kz.website = {
    enable = lib.mkEnableOption "the nixos.kz website";

    redirect = lib.mkOption {
      type = lib.types.str;
      default = "https://t.me/NixOSkz";
      description = "Where nixos.kz redirects to until the website exists.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = true;

    services.nginx.virtualHosts."nixos.kz" = {
      addSSL = true;
      enableACME = true;
      serverAliases = [ "www.nixos.kz" ];
      locations."/".return = "301 ${cfg.redirect}";
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
