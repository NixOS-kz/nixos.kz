# cache.nixos.kz: plain passthrough proxy to cache.nixos.org. Narinfos stay
# signed by cache.nixos.org, so clients need no extra trusted key.
{ config, lib, ... }:
let
  cfg = config.nixos-kz.cache;
in
{
  options.nixos-kz.cache = {
    enable = lib.mkEnableOption "the cache.nixos.kz binary cache mirror";

    upstream = lib.mkOption {
      type = lib.types.str;
      default = "cache.nixos.org";
      description = "Binary cache host to proxy.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.nginx.enable = true;

    services.nginx.virtualHosts."cache.nixos.kz" = {
      addSSL = true;
      enableACME = true;
      locations."/" = {
        proxyPass = "https://${cfg.upstream}";
        extraConfig = ''
          proxy_set_header Host ${cfg.upstream};
          proxy_ssl_server_name on;
          proxy_redirect off;
        '';
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 443 ];
  };
}
