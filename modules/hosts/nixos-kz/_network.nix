{
  networking = {
    hostName = "nixos-kz";
    useDHCP = false;
    interfaces.ens3.ipv4.addresses = [{ address = "10.7.7.2"; prefixLength = 24; }];
    defaultGateway = "10.7.7.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };
}
