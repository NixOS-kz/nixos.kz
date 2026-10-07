{ runCommand, pandoc }:
runCommand "site" { nativeBuildInputs = [ pandoc ]; } ''
  mkdir $out
  pandoc -s -M pagetitle=NixOS.kz -M lang=en ${./index.md} -o $out/index.html
''
