{ inputs, ... }:
{
  flake.modules.nixos.impermanence =
    {
      imports = [ inputs.impermanence.nixosModules.impermanence ];

      fileSystems."/" = {
        device = "none";
        fsType = "tmpfs";
        options = [ "size=256M" "mode=755" ];
      };

      environment.persistence."/nix/persist" = {
        directories = [ "/var/lib/acme" "/var/lib/chrony" "/var/lib/nixos" "/var/lib/systemd/timers" "/var/log" ];
        files = [ "/etc/machine-id" ];
      };
    };
}
