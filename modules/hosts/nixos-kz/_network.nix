{
  networking = {
    hostName = "nixos-kz";
    useDHCP = false;
    interfaces.ens3.ipv4.addresses = [{ address = "92.38.49.128"; prefixLength = 23; }];
    defaultGateway = "92.38.48.1";
    nameservers = [ "1.1.1.1" "8.8.8.8" ];
  };
}
