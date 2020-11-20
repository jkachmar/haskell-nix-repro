{ nixpkgsSrc ?
    builtins.fetchTarball {
      # The test-fix-shellFor-doCheck-minimal branch of cdepillabout/nixpkgs.
      # This is built on a recent version of nixpkgs master as of 2020-11-20.
      # This has a single commit that adds some functionality to shellFor.
      url = "https://github.com/cdepillabout/nixpkgs/archive/47d19bef864.tar.gz";
      sha256 = "0hqldnki43rqshm9ni19nyfdgp5jz2cnd826ls3n8y1325mqb174";
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
          # This is the original mkDerivation override written by jkachmar.
          # The args passed to this mkDerivation call always get overridden by
          # `doCheck = false`, which causes it not to work.
          # mkDerivation = args: hprev.mkDerivation (args // {
          #   doCheck = false;
          #   doBenchmark = false;
          #   doHoogle = false;
          #   doHaddock = false;
          #   enableLibraryProfiling = false;
          #   enableExecutableProfiling = false;
          # });

          # This is a mkDerivation call suggested by expipiplus1.  It lets args
          # override the `doCheck = false` setting, which we take advantage of by
          # setting `doCheck = true` in `shell.nix`.
          mkDerivation = args: hprev.mkDerivation ({
            doCheck = false;
            doBenchmark = false;
            doHoogle = false;
            doHaddock = false;
            enableLibraryProfiling = false;
            enableExecutableProfiling = false;
          } // args);

          # This is how mkDerivation is overridden in the definition of overrideCabal.
          # This has the same problem as the first mkDerivation override above.
          # mkDerivation = drv: (hprev.mkDerivation drv).override (_: {
          #   doCheck = false;
          #   doBenchmark = false;
          #   doHoogle = false;
          #   doHaddock = false;
          #   enableLibraryProfiling = false;
          #   enableExecutableProfiling = false;
          # });
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
