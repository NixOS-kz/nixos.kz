{
  services.nginx.virtualHosts."ntp.nixos.kz" = {
    forceSSL = true;
    enableACME = true;
    locations."= /".extraConfig = ''
      default_type text/plain;
      return 200 "NTP and NTS server\n\nserver ntp.nixos.kz iburst nts\n";
    '';
    locations."/".return = "404";
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
}
