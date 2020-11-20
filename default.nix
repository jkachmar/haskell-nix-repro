{ pkgs ? import <nixpkgs> { }
, ghc ? "ghc8102"
}:
let
  inherit (pkgs) lib;
  hlib = pkgs.haskell.lib;

  ############################################################################
  reproOverlay = hfinal: _hprev: {
    repro = hfinal.callCabal2nix "repro"
      (lib.sourceByRegex ./. [
        "^library.*$"
        "^test.*$"
        "package.yaml"
        "README.md"
      ])
      { };
  };

  ############################################################################
  # Construct a 'base' Haskell package, disabling the test
  # and benchmark suites for all dependencies by default.
  baseHaskellPkgs =
    pkgs.haskell.packages.${ghc}.override (hpArgs: {
      overrides = pkgs.lib.composeExtensions (hpArgs.overrides or (_: _: { })) (
        _hfinal: hprev: {
          mkDerivation = args: hprev.mkDerivation (args // {
            doCheck = false;
            doBenchmark = false;
            doHoogle = false;
            doHaddock = false;
            enableLibraryProfiling = false;
            enableExecutableProfiling = false;
          });
        }
      );
    }
    );

  # Construct the final Haskell package set
  haskellPkgs = baseHaskellPkgs.override (
    old: {
      overrides = builtins.foldl' pkgs.lib.composeExtensions (old.overrides or (_: _: { })) [
        reproOverlay
        (_hfinal: hprev: {
          repro = hlib.doCheck hprev.repro;
        })
      ];
    }
  );

in
{
  inherit haskellPkgs;
}
