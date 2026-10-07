''while read -r p; do echo "$p $(nix --extra-experimental-features nix-command hash path "$p")"; done''
