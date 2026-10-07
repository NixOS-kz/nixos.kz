{
  flake.modules.nixos.members =
    {
      nixos-kz.members = {
        merura = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMYcdiZTkmjVhqK+IEDv6Q9bSSyc7LkWK3vyfsPkVMen github.com/merura.keys";
      };
    };
}
