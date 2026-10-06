{ pkgs, ... }:
{
  imports = [
    ./access.nix
    ./impermanence.nix
    ./nginx.nix
    ./ntp.nix
  ];

  boot.kernel.sysctl = {
    "kernel.dmesg_restrict" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "net.core.bpf_jit_harden" = 2;
  };

  environment.systemPackages = [ pkgs.fastfetch pkgs.htop ];

  services.journald.settings.Journal.SystemMaxUse = "100M";
  nix.gc.automatic = true;

  systemd.timers.reboot = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "04:00 Asia/Almaty";
      Unit = "reboot.target";
    };
  };

  system.stateVersion = "26.05";
}
