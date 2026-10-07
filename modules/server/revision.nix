{ inputs, ... }:
{
  flake.modules.nixos.revision = {
    environment.etc."nixos-revision".text = ''
      commit: ${inputs.self.rev or inputs.self.dirtyRev or "unknown"}
      status: ${if inputs.self ? rev then "clean" else "dirty"}
      store: ${inputs.self.outPath}
    '';
  };
}
