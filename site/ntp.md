# ntp.nixos.kz

NTP and NTS server synced to kz.pool.ntp.org.

```nix
services.chrony = {
  enable = true;
  enableNTS = true;
  servers = [ "ntp.nixos.kz" ];
};
```

Plain NTP with the default systemd-timesyncd:

```nix
networking.timeServers = [ "ntp.nixos.kz" ];
```

[NixOS.kz](https://nixos.kz)
