# ntp.nixos.kz

NTP and NTS server synced over NTS to Cloudflare, Netnod, PTB and time.nl, and to kz.pool.ntp.org.

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
