{ config, ... }:
{
  flake.modules.nixos.server.imports = with config.flake.modules.nixos; [ base access impermanence nginx ntp revision ];
}
