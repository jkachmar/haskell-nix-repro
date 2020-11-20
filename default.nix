{ nixpkgsSrc ?
    builtins.fetchTarball {
      # Recent version of nixpkgs master as of 2020-11-20.
      url = "https://github.com/NixOS/nixpkgs/archive/4f3475b113c93d204992838aecafa89b1b3ccfde.tar.gz";
      sha256 = "158iik656ds6i6pc672w54cnph4d44d0a218dkq6npzrbhd3vvbg";
    }
, pkgs ? import nixpkgsSrc { }
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
        "repro.cabal"
        "README.md"
      ])
      { };
  };

  ############################################################################
  # Construct a 'base' Haskell package, disabling the test
  # and benchmark suites for all dependencies by default.
  baseHaskellPkgs =
    pkgs.haskell.packages.ghc8102.override (hpArgs: {
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
  inherit pkgs haskellPkgs;
}
