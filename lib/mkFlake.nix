# In-house flake-parts + import-tree: every .nix under root is a top-level module,
# paths with "/_" are left to the module that imports them.
inputs: root:
let
  inherit (inputs.nixpkgs) lib;
  inherit (lib) types mkOption;

  importTree = dir:
    builtins.filter
      (p: lib.hasSuffix ".nix" p && !lib.hasInfix "/_" (lib.removePrefix (toString dir) (toString p)))
      (lib.filesystem.listFilesRecursive dir);

  flakeModule = {
    options.flake = mkOption {
      type = types.submodule {
        freeformType = types.lazyAttrsOf types.raw;
        options.modules = mkOption {
          type = types.lazyAttrsOf (types.lazyAttrsOf types.deferredModule);
          default = { };
          # the key dedupes an aspect imported through several paths
          apply = lib.mapAttrs (class: lib.mapAttrs (name: module: {
            key = "aspect:${class}:${name}";
            _file = "flake.modules.${class}.${name}";
            imports = [ module ];
          }));
        };
      };
      default = { };
    };
  };
in
(lib.evalModules {
  modules = [ flakeModule ] ++ importTree root;
  specialArgs = { inherit inputs; };
}).config.flake
