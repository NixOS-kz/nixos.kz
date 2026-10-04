{
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "size=256M" "mode=755" ];
  };

  environment.persistence."/nix/persist" = {
    directories = [ "/var/lib/acme" "/var/lib/nixos" "/var/lib/systemd/timers" "/var/log" ];
    files = [ "/etc/machine-id" ];
  };
}
