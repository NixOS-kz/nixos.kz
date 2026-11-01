{ config, lib, ... }:
{
  flake.modules.nixos.ntp =
    {
      services.nginx.virtualHosts."ntp.nixos.kz" = {
        root = config.flake.packages.x86_64-linux.site;
        locations."= /".tryFiles = "/ntp.html =404";
        locations."/".return = "404";
        # Serve ACME webroot challenges so the NTS cert can be issued via baremetal proxy
        locations."/.well-known/acme-challenge/" = {
          root = "/var/lib/acme/acme-challenge";
          tryFiles = "$uri =404";
        };
      };

      security.acme = {
        acceptTerms = lib.mkDefault true;
        defaults.email = lib.mkDefault "webmaster@nixos.kz";
      };

      security.acme.certs.nts = {
        domain = "ntp.nixos.kz";
        webroot = "/var/lib/acme/acme-challenge";
        group = "chrony";
        reloadServices = [ "chronyd" ];
      };

      systemd.services.chronyd = {
        wants = [ "acme-nts.service" ];
        after = [ "acme-nts.service" ];
      };

      services.chrony = {
        enable = true;
        servers = [ "kz.pool.ntp.org" ];
        extraConfig = ''
          server time.cloudflare.com iburst nts
          server nts.netnod.se iburst nts
          server ptbtime1.ptb.de iburst nts
          server nts.time.nl iburst nts
          minsources 2
          allow
          ratelimit interval 1 burst 16
          ntsratelimit interval 1 burst 16
          ntsserverkey /var/lib/acme/nts/key.pem
          ntsservercert /var/lib/acme/nts/fullchain.pem
          ntsdumpdir /var/lib/chrony
        '';
      };

      networking.firewall.allowedUDPPorts = [ 123 ];
      networking.firewall.allowedTCPPorts = [ 4460 ];
    };
}
