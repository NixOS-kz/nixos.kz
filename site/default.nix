{ runCommand, pandoc }:
runCommand "site" { nativeBuildInputs = [ pandoc ]; } ''
  mkdir $out
  for f in ${./.}/*.md; do
    pandoc -s --shift-heading-level-by=-1 -M lang=en "$f" -o $out/$(basename "$f" .md).html
  done
''
