{
  # Uses stable defaults from default.nix
  stable   = import ./. { packageOnly = false; };

  # Uses whichever <nixpkgs> is in scope
  unstable =
    with import <nixpkgs> {};
    with rec {
      emacsWithPG = emacsWithPackages [ emacsPackages.proofgeneral ];
      pkgWithJunk = callPackage ./. {
                      inherit emacsWithPG;
                      packageOnly = false;
                    };
    };
    # callPackage gives us 'override' attributes which annoys Hydra
    builtins.removeAttrs pkgWithJunk [ "override" "overrideDerivation" ];
}
