{ config, ... }:
{
  flake.modules.nixos.nginx =
    {
      security.acme = {
        acceptTerms = true;
        defaults.email = "webmaster@nixos.kz";
      };

      services.nginx = {
        enable = true;
        serverTokens = false;
        commonHttpConfig = ''
          access_log syslog:server=unix:/dev/log;
          add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
        '';
        proxyCachePath.narinfo = {
          enable = true;
          keysZoneName = "narinfo";
          keysZoneSize = "32m";
          maxSize = "2g";
          inactive = "30d";
          levels = "1:2";
        };
        virtualHosts."_" = {
          default = true;
          rejectSSL = true;
          locations."/".return = "444";
        };
        virtualHosts."nixos.kz" = {
          forceSSL = true;
          enableACME = true;
          serverAliases = [ "www.nixos.kz" ];
          root = config.flake.packages.x86_64-linux.site;
        };
        virtualHosts."cache.nixos.kz" = {
          forceSSL = true;
          enableACME = true;
          locations."/".return = "404";
          root = config.flake.packages.x86_64-linux.site;
          locations."= /".tryFiles = "/cache.html =404";
          locations."~ ^/(nix-cache-info$|[a-z0-9]+\\.narinfo$)" = {
            proxyPass = "https://cache.nixos.org";
            extraConfig = ''
              limit_except GET HEAD { deny all; }
              proxy_set_header Host cache.nixos.org;
              proxy_ssl_server_name on;
              proxy_pass_request_body off;
              proxy_connect_timeout 5s;
              proxy_read_timeout 60s;
              proxy_send_timeout 60s;
              proxy_cache narinfo;
              proxy_cache_valid 200 30d;
              proxy_cache_valid 404 1m;
              proxy_cache_use_stale error timeout updating http_500 http_502 http_503 http_504;
              proxy_cache_lock on;
            '';
          };
          locations."~ ^/nar/" = {
            proxyPass = "https://cache.nixos.org";
            extraConfig = ''
              limit_except GET HEAD { deny all; }
              proxy_set_header Host cache.nixos.org;
              proxy_ssl_server_name on;
              proxy_max_temp_file_size 0;
              proxy_pass_request_body off;
              proxy_connect_timeout 5s;
              proxy_read_timeout 60s;
              proxy_send_timeout 60s;
            '';
          };
        };
      };

      networking.firewall.allowedTCPPorts = [ 80 443 ];
    };
}
