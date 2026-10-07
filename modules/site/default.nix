{ inputs, ... }:
let
  pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
in
{
  flake.packages.x86_64-linux.site = pkgs.runCommand "site" { nativeBuildInputs = [ pkgs.pandoc ]; } ''
    mkdir $out
    for f in ${./.}/*.md; do
      pandoc -s --shift-heading-level-by=-1 -M lang=en "$f" -o $out/$(basename "$f" .md).html
    done
  '';
}
