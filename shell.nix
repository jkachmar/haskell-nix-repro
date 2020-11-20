let
  inherit (import ./default.nix {}) haskellPkgs;
in

haskellPkgs.shellFor {
  packages = p: [ p.repro ];
  nativeBuildInputs = [ haskellPkgs.cabal-install ];
  shellHook = ''
    ghc-pkg list
  '';
}
