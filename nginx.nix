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
    virtualHosts."_" = {
      default = true;
      rejectSSL = true;
      locations."/".return = "444";
    };
    virtualHosts."nixos.kz" = {
      forceSSL = true;
      enableACME = true;
      serverAliases = [ "www.nixos.kz" ];
      locations."/".return = "301 https://t.me/NixOSkz";
    };
    virtualHosts."cache.nixos.kz" = {
      forceSSL = true;
      enableACME = true;
      locations."/".return = "404";
      locations."~ ^/(nix-cache-info$|[a-z0-9]+\\.narinfo$|nar/)" = {
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
}
