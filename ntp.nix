let
  cert = "/var/lib/acme/ntp.nixos.kz";
  webroot = "/var/lib/acme/acme-challenge";
in
{
  services.nginx.virtualHosts."ntp.nixos.kz".locations."/.well-known/acme-challenge/".root = webroot;

  security.acme.certs."ntp.nixos.kz" = {
    inherit webroot;
    group = "chrony";
    reloadServices = [ "chronyd" ];
  };

  services.chrony = {
    enable = true;
    servers = [ "kz.pool.ntp.org" ];
    extraConfig = ''
      allow
      ratelimit interval 1 burst 16
      ntsratelimit interval 1 burst 16
      ntsserverkey ${cert}/key.pem
      ntsservercert ${cert}/fullchain.pem
      ntsdumpdir /var/lib/chrony
    '';
  };

  networking.firewall.allowedUDPPorts = [ 123 ];
  networking.firewall.allowedTCPPorts = [ 4460 ];
}
