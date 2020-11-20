let
  inherit (import ./default.nix {}) haskellPkgs pkgs;
in

haskellPkgs.shellFor {
  packages = p: [ p.repro ];
  nativeBuildInputs = [ pkgs.cabal-install ];
  shellHook = ''
    ghc-pkg list
  '';
  genericBuilderArgsModifier = args: args // { doCheck = true; };
}
